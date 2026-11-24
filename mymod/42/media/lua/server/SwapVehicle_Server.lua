------------------------------------------------------------
-- SwapVehicle Server Logic
-- A vinyl swap replaces the vehicle with a different script of the same model:
-- the old vehicle is removed and a new one spawned in its place, then everything
-- the player cares about (loot, parts, engine, fuel, battery, key) is carried over.
------------------------------------------------------------

require "PaintVehicle_Shared"   -- shared key check (PaintVehicle.hasVehicleKey)

local DEBUG = false
local function dbg(msg) if DEBUG then print("[SwapVehicle:Server] " .. tostring(msg)) end end

if not SwapVehicleRegistry then
    print("[SwapVehicle] ERROR: SwapVehicleRegistry missing!")
    return
end

local SPRAY   = "Base.SpraycanVinylCoat"
local SANDING = "Base.SandingBlock"

------------------------------------------------------------
-- Multi-tick lightbar restore (the lightbar condition can get
-- reset by the new vehicle's own init for a few ticks)
------------------------------------------------------------
local function QueueLightbarRestore(newVehicleId, targetCondition)
    if not targetCondition then return end

    local ticks = 0
    local maxTicks = 120

    local function tickFunc()
        ticks = ticks + 1
        local v = getVehicleById(newVehicleId)
        if not v then Events.OnTick.Remove(tickFunc) return end

        local lb = v:getPartById("lightbar")
        if lb then
            if math.abs(lb:getCondition() - targetCondition) < 0.01 then
                Events.OnTick.Remove(tickFunc)
                return
            end
            lb:setCondition(targetCondition)
            v:transmitPartCondition(lb)
        end

        if ticks >= maxTicks then Events.OnTick.Remove(tickFunc) end
    end

    Events.OnTick.Add(tickFunc)
end

------------------------------------------------------------
-- Loot preservation
------------------------------------------------------------
-- Every part with storage is carried over, whatever its ID (seats, glove box, trunk,
-- truck bed, open truck bed, middle van seats, trailer trunk, animal food/eggs...).
-- Earlier versions only handled a fixed list of 7 IDs, so items anywhere else were
-- deleted with the old vehicle.
local function CaptureLoot(vehicle)
    local loot = {}
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        local cont = part and part:getItemContainer()
        if cont then
            local items = {}
            local list = cont:getItems()
            for j = 0, list:size() - 1 do
                table.insert(items, list:get(j))
            end
            loot[part:getId()] = { container = cont, items = items }
        end
    end
    return loot
end

local function ClearNewVehicleContainers(newVehicle)
    for i = 0, newVehicle:getPartCount() - 1 do
        local part = newVehicle:getPartByIndex(i)
        local cont = part and part:getItemContainer()
        if cont then cont:clear() end
    end
end

-- Items whose storage spot doesn't exist on the new vehicle are dropped on the
-- ground next to it rather than lost.
local function RestoreLoot(newVehicle, loot, dropSquare)
    for id, data in pairs(loot) do
        local newPart = newVehicle:getPartById(id)
        local newCont = newPart and newPart:getItemContainer()
        for _, item in ipairs(data.items) do
            if data.container:contains(item) then
                data.container:Remove(item)
            end
            if newCont then
                newCont:AddItem(item)
            elseif dropSquare then
                dropSquare:AddWorldInventoryItem(item, ZombRandFloat(0.1, 0.9), ZombRandFloat(0.1, 0.9), 0)
                dbg("no '" .. tostring(id) .. "' on new vehicle, dropped " .. tostring(item:getFullType()))
            end
        end
    end
end

------------------------------------------------------------
-- Server-side trust boundary: everything below re-validates
-- what the client already checked, since `args` comes from a
-- ClientCommand and cannot be trusted as-is.
------------------------------------------------------------
local MAX_INTERACT_DISTANCE = 3 -- tiles; generous vs. vanilla vehicle interaction range
local SWAP_COOLDOWN_SECONDS = 3

local function GetDistanceToVehicle(player, vehicle)
    local dx = player:getX() - vehicle:getX()
    local dy = player:getY() - vehicle:getY()
    return math.sqrt(dx * dx + dy * dy)
end

-- Refuse to swap out from under a driver or passenger (own player included)
local function VehicleHasOccupants(vehicle)
    local players = getOnlinePlayers()
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        if p and p:getVehicle() == vehicle then
            return true
        end
    end
    return false
end

-- Animals in a livestock/horse trailer can't be carried over to the new vehicle,
-- so a swap would delete them. Refuse instead.
local function VehicleHasAnimals(vehicle)
    if not vehicle.getAnimals then return false end
    local ok, animals = pcall(function() return vehicle:getAnimals() end)
    return ok and animals ~= nil and animals:size() > 0
end

-- The target script must really be loaded (e.g. a mod vehicle whose mod was removed
-- isn't), otherwise the spawn fails after the old vehicle is already gone.
local function VehicleScriptExists(fullName)
    local scripts = getScriptManager():getAllVehicleScripts()
    for i = 0, scripts:size() - 1 do
        if scripts:get(i):getFullName() == fullName then return true end
    end
    return false
end

------------------------------------------------------------
-- Per-player cooldown to prevent command spam / rapid re-swap
------------------------------------------------------------
local lastSwapTime = {}

local function IsOnCooldown(player)
    local last = lastSwapTime[player:getUsername()]
    return last ~= nil and (getTimestamp() - last) < SWAP_COOLDOWN_SECONDS
end

local function MarkSwapTime(player)
    lastSwapTime[player:getUsername()] = getTimestamp()
end

-- Remove an item from whatever container it's really in (it may be inside a bag)
local function removeItem(item, fallbackInv)
    local container = item:getContainer() or fallbackInv
    container:Remove(item)
    sendRemoveItemFromContainer(container, item)
end

------------------------------------------------------------
-- Main Swap Handler
------------------------------------------------------------
function SwapVehicle_Server_Handle(player, args)
    if not player or not args then return end
    local who = tostring(player:getUsername())

    local newScript = args.newScript
    if type(newScript) ~= "string" or newScript == "" then
        dbg("rejected: invalid newScript from " .. who)
        return
    end

    if IsOnCooldown(player) then
        dbg("rejected: " .. who .. " is on cooldown")
        return
    end

    local vehicle = getVehicleById(args.vehicleId)
    if not vehicle then
        dbg("rejected: vehicle not found for id " .. tostring(args.vehicleId))
        return
    end

    if GetDistanceToVehicle(player, vehicle) > MAX_INTERACT_DISTANCE then
        dbg("rejected: " .. who .. " too far from vehicle " .. tostring(args.vehicleId))
        return
    end

    if VehicleHasOccupants(vehicle) then
        dbg("rejected: vehicle " .. tostring(args.vehicleId) .. " has an occupant")
        return
    end

    if VehicleHasAnimals(vehicle) then
        dbg("rejected: vehicle " .. tostring(args.vehicleId) .. " has animals inside")
        return
    end

    -- Player must hold this vehicle's key -- prevents re-skinning cars they don't own
    if not PaintVehicle.hasVehicleKey(player, vehicle) then
        dbg("rejected: " .. who .. " does not have the key for vehicle " .. tostring(args.vehicleId))
        return
    end

    local oldScript = vehicle:getScript():getFullName()

    local group = SwapVehicleRegistry.Groups[oldScript]
    if not group then
        dbg("rejected: no registry group for script " .. tostring(oldScript))
        return
    end

    -- newScript must be a registered swap variant of the vehicle's own group
    local variants = SwapVehicleRegistry.SwapPairs[group]
    local validVariant = false
    if variants then
        for _, v in ipairs(variants) do
            if v == newScript then
                validVariant = true
                break
            end
        end
    end
    if not validVariant then
        dbg("rejected: " .. tostring(newScript) .. " is not a valid swap variant for group " .. tostring(group))
        return
    end

    if not VehicleScriptExists(newScript) then
        dbg("rejected: vehicle script " .. tostring(newScript) .. " is not loaded")
        return
    end

    -- Materials can be anywhere in the inventory, including bags
    local inv = player:getInventory()
    local sanding = inv:getFirstTypeRecurse(SANDING)
    local spray   = inv:getFirstTypeRecurse(SPRAY)
    if not sanding or not spray then
        dbg("rejected: " .. who .. " missing required items")
        return
    end

    -- Where the new vehicle goes: checked BEFORE anything is removed or used up
    local x, y, z = vehicle:getX(), vehicle:getY(), vehicle:getZ()
    local spawnSquare = getCell():getGridSquare(math.floor(x), math.floor(y), math.floor(z))
    if not spawnSquare then
        dbg("rejected: no grid square at " .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z))
        return
    end

    --------------------------------------------------------
    -- All checks passed: lock in the cooldown and use up the
    -- materials here (server-authoritative).
    --------------------------------------------------------
    MarkSwapTime(player)

    local condition = sanding:getCondition()
    if condition > 1 then
        sanding:setCondition(condition - 1)
        if sanding.syncItemFields then sanding:syncItemFields() end
    else
        removeItem(sanding, inv)
    end
    removeItem(spray, inv)

    local partSet = SwapVehicleRegistry.PartSets[group] or SwapVehicleRegistry.PartSets.Default

    --------------------------------------------------------
    -- Capture everything from the old vehicle
    --------------------------------------------------------
    local oldLightbarCondition = nil
    do
        local lb = vehicle:getPartById("lightbar")
        if lb then oldLightbarCondition = lb:getCondition() end
    end

    local lootData = CaptureLoot(vehicle)

    local saved = {}
    for _, id in ipairs(partSet) do
        local part = vehicle:getPartById(id)
        if part then saved[id] = part:getCondition() end
    end

    -- Engine quality/loudness/power are rolled randomly for every new vehicle,
    -- so they must be carried over or a swap changes the engine
    local engineQuality  = vehicle:getEngineQuality()
    local engineLoudness = vehicle:getEngineLoudness()
    local enginePower    = vehicle:getEnginePower()

    local oldTankPart = vehicle:getPartById("GasTank")
    local oldTankItem = oldTankPart and oldTankPart:getInventoryItem()
    local oldTankType = oldTankItem and oldTankItem:getFullType()
    local oldTankCondition = oldTankItem and oldTankItem:getCondition()
    local oldTankFuel = oldTankPart and oldTankPart:getContainerContentAmount()

    local oldBatteryPart = vehicle:getPartById("Battery")
    local oldBatteryItem = oldBatteryPart and oldBatteryPart:getInventoryItem()
    if oldBatteryItem then oldBatteryPart:setInventoryItem(nil) end

    -- The new vehicle gets the same key ID, so the player's existing car key keeps working
    local oldKeyId = vehicle:getKeyId()

    -- Facing must be captured before the old vehicle is removed.
    -- getAngleX/Y/Z + setAngles are the real B42 methods (vanilla's own debug
    -- "Vehicle Angles" tool uses them); getWorldRotation/setWorldRotation don't
    -- exist, which is why swapped cars used to always end up facing north.
    local angX, angY, angZ = vehicle:getAngleX(), vehicle:getAngleY(), vehicle:getAngleZ()

    --------------------------------------------------------
    -- Replace the vehicle
    --------------------------------------------------------
    vehicle:permanentlyRemove()

    local newVehicle = addVehicleDebug(newScript, IsoDirections.N, nil, spawnSquare)
    if not newVehicle then
        -- Shouldn't happen now the script + square are checked up front, but never lose
        -- the battery or the loot: put them on the ground where the vehicle was.
        print("[SwapVehicle] ERROR: failed to spawn " .. tostring(newScript) .. " for " .. who .. ", dropping contents")
        if oldBatteryItem then spawnSquare:AddWorldInventoryItem(oldBatteryItem, 0.5, 0.5, 0) end
        for _, data in pairs(lootData) do
            for _, item in ipairs(data.items) do
                spawnSquare:AddWorldInventoryItem(item, ZombRandFloat(0.1, 0.9), ZombRandFloat(0.1, 0.9), 0)
            end
        end
        return
    end

    local newVehicleId = newVehicle:getId()

    --------------------------------------------------------
    -- Position + rotation
    --------------------------------------------------------
    newVehicle:setX(x)
    newVehicle:setY(y)
    newVehicle:setZ(z)
    newVehicle:setAngles(angX, angY, angZ)

    if newVehicle.setCurrentSpeed then newVehicle:setCurrentSpeed(0) end
    if newVehicle.setEngineSpeed then newVehicle:setEngineSpeed(0) end
    if newVehicle.setEngineStarted then newVehicle:setEngineStarted(false) end

    --------------------------------------------------------
    -- Key
    --------------------------------------------------------
    if oldKeyId and oldKeyId ~= -1 then
        newVehicle:setKeyId(oldKeyId)
    end

    --------------------------------------------------------
    -- Fresh paint job: no rust or dirt
    --------------------------------------------------------
    if newVehicle.setRust then newVehicle:setRust(0) end
    if newVehicle.setDirt then newVehicle:setDirt(0) end

    --------------------------------------------------------
    -- Engine quality / loudness / power
    --------------------------------------------------------
    newVehicle:setEngineFeature(engineQuality, engineLoudness, enginePower)

    --------------------------------------------------------
    -- Part conditions
    --------------------------------------------------------
    for id, cond in pairs(saved) do
        local part = newVehicle:getPartById(id)
        if part then
            part:setCondition(cond)
            newVehicle:transmitPartCondition(part)
        end
    end

    if oldLightbarCondition then
        local lb = newVehicle:getPartById("lightbar")
        if lb then
            lb:setCondition(oldLightbarCondition)
            newVehicle:transmitPartCondition(lb)
        end
        QueueLightbarRestore(newVehicleId, oldLightbarCondition)
    end

    --------------------------------------------------------
    -- Battery (the old battery item itself, so its charge is kept)
    --------------------------------------------------------
    if oldBatteryItem then
        local newBatteryPart = newVehicle:getPartById("Battery")
        if newBatteryPart then
            newBatteryPart:setInventoryItem(oldBatteryItem)
            newVehicle:transmitPartItem(newBatteryPart)
        else
            spawnSquare:AddWorldInventoryItem(oldBatteryItem, 0.5, 0.5, 0)
        end
    end

    --------------------------------------------------------
    -- Gas tank: same tank type, condition and fuel
    --------------------------------------------------------
    if oldTankType then
        local newTankPart = newVehicle:getPartById("GasTank")
        if newTankPart then
            newTankPart:setInventoryItem(nil)
            local newTankItem = instanceItem(oldTankType)
            if newTankItem then
                newTankItem:setCondition(oldTankCondition or 100)
                newTankPart:setInventoryItem(newTankItem)
                newTankPart:setContainerContentAmount(oldTankFuel or 0)
                newVehicle:transmitPartItem(newTankPart)
                newVehicle:transmitPartModData(newTankPart)
            else
                dbg("failed to create tank item " .. tostring(oldTankType))
            end
        else
            dbg("new vehicle has no GasTank part")
        end
    end

    --------------------------------------------------------
    -- Loot: clear the new vehicle's random loot, then move the old items in
    --------------------------------------------------------
    ClearNewVehicleContainers(newVehicle)
    RestoreLoot(newVehicle, lootData, spawnSquare)

    if newVehicle.transmitEngine then newVehicle:transmitEngine() end

    -- In B42 MP the nearby player's game runs a vehicle's physics and overrides the
    -- server's position/rotation (same cause as the FlipVehicle sync problem), and
    -- there is no transmit call for a vehicle's transform. So tell every client the
    -- intended spot + facing; each applies it if it has this vehicle loaded.
    -- (Lesson from Workshop "FlipVehicleFix" 3843842246.)
    sendServerCommand("SwapVehicle", "Orient", {
        vehicleId = newVehicleId,
        x = x, y = y, z = z,
        ax = angX, ay = angY, az = angZ,
    })

    dbg(who .. " swapped " .. oldScript .. " -> " .. newScript .. " (id " .. tostring(newVehicleId) .. ")")
end

------------------------------------------------------------
-- Event hook
------------------------------------------------------------
Events.OnClientCommand.Add(function(module, command, player, args)
    if module == "SwapVehicle" and command == "Swap" then
        SwapVehicle_Server_Handle(player, args)
    end
end)
