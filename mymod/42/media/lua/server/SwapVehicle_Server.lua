------------------------------------------------------------
-- SwapVehicle Server Logic (FINAL + LUA TABLE REFERENCE)
------------------------------------------------------------

if not SwapVehicleRegistry then
    print("ERROR: SwapVehicleRegistry missing!")
    return
end

------------------------------------------------------------
-- Multi-tick fuel restore
------------------------------------------------------------
local function QueueFuelRestoreStabilized(newVehicleId, targetFuel)
    if not targetFuel then return end

    local ticks = 0
    local maxTicks = 300

    local function tickFunc()
        ticks = ticks + 1
        local v = getVehicleById(newVehicleId)
        if not v then Events.OnTick.Remove(tickFunc) return end

        local tank = v:getPartById("GasTank")
        if tank then
            local current = tank:getContainerContentAmount()
            if math.abs(current - targetFuel) < 0.01 then
                Events.OnTick.Remove(tickFunc)
                return
            end
            tank:setContainerContentAmount(targetFuel)
        end

        if ticks >= maxTicks then Events.OnTick.Remove(tickFunc) end
    end

    Events.OnTick.Add(tickFunc)
end

------------------------------------------------------------
-- Multi-tick lightbar restore
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
        end

        if ticks >= maxTicks then Events.OnTick.Remove(tickFunc) end
    end

    Events.OnTick.Add(tickFunc)
end

------------------------------------------------------------
-- Loot Preservation (Lua Table Reference Method)
------------------------------------------------------------

local VANILLA_CONTAINERS = {
    "SeatFrontLeft",
    "SeatFrontRight",
    "SeatRearLeft",
    "SeatRearRight",
    "GloveBox",
    "Trunk",
    "TruckBed",
}

local function CaptureLootReferences(vehicle)
    local loot = {}

    for _, id in ipairs(VANILLA_CONTAINERS) do
        local part = vehicle:getPartById(id)
        if part then
            local cont = part:getItemContainer()
            if cont then
                local items = {}
                for i = 0, cont:getItems():size() - 1 do
                    table.insert(items, cont:getItems():get(i))
                end

                loot[id] = {
                    container = cont,
                    items = items
                }
            end
        end
    end

    return loot
end

local function ClearNewVehicleContainers(newVehicle)
    for _, id in ipairs(VANILLA_CONTAINERS) do
        local part = newVehicle:getPartById(id)
        if part and part:getItemContainer() then
            part:getItemContainer():clear()
        end
    end
end

local function RestoreLootFromReferences(newVehicle, loot)
    for id, data in pairs(loot) do
        local newPart = newVehicle:getPartById(id)
        if newPart and newPart:getItemContainer() then
            local newCont = newPart:getItemContainer()

            for _, item in ipairs(data.items) do
                if data.container:contains(item) then
                    data.container:Remove(item)
                end
                newCont:AddItem(item)
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

------------------------------------------------------------
-- Occupant check: refuse to swap out from under a driver or
-- passenger (own player included).
------------------------------------------------------------
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

------------------------------------------------------------
-- Per-player cooldown to prevent command spam / rapid re-swap
-- abuse on the same or different vehicles.
------------------------------------------------------------
local lastSwapTime = {}

local function IsOnCooldown(player)
    local id = player:getUsername()
    local now = getTimestamp()
    local last = lastSwapTime[id]
    return last ~= nil and (now - last) < SWAP_COOLDOWN_SECONDS
end

local function MarkSwapTime(player)
    lastSwapTime[player:getUsername()] = getTimestamp()
end

------------------------------------------------------------
-- Main Swap Handler
------------------------------------------------------------
function SwapVehicle_Server_Handle(player, args)
    if not player or not args then return end

    local newScript = args.newScript
    if type(newScript) ~= "string" or newScript == "" then
        print("[SwapVehicle] Rejected: invalid newScript from " .. tostring(player and player:getUsername()))
        return
    end

    if IsOnCooldown(player) then
        print("[SwapVehicle] Rejected: " .. tostring(player:getUsername()) .. " is on cooldown")
        return
    end

    local vehicle = getVehicleById(args.vehicleId)
    if not vehicle then
        print("[SwapVehicle] Rejected: vehicle not found for id " .. tostring(args.vehicleId))
        return
    end

    --------------------------------------------------------
    -- Proximity check: player must actually be near the
    -- vehicle they're claiming to swap.
    --------------------------------------------------------
    if GetDistanceToVehicle(player, vehicle) > MAX_INTERACT_DISTANCE then
        print("[SwapVehicle] Rejected: " .. tostring(player:getUsername()) .. " too far from vehicle " .. tostring(args.vehicleId))
        return
    end

    --------------------------------------------------------
    -- Nobody may be sitting in the vehicle during a swap.
    --------------------------------------------------------
    if VehicleHasOccupants(vehicle) then
        print("[SwapVehicle] Rejected: vehicle " .. tostring(args.vehicleId) .. " has an occupant")
        return
    end

    local oldScript = vehicle:getScript():getFullName()

    --------------------------------------------------------
    -- Determine part set
    --------------------------------------------------------
    local group = SwapVehicleRegistry.Groups[oldScript]
    if not group then
        print("[SwapVehicle] Rejected: no registry group for script " .. tostring(oldScript))
        return
    end

    --------------------------------------------------------
    -- newScript must be a registered swap variant of the
    -- vehicle's own group, not an arbitrary script.
    --------------------------------------------------------
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
        print("[SwapVehicle] Rejected: " .. tostring(newScript) .. " is not a valid swap variant for group " .. tostring(group))
        return
    end

    --------------------------------------------------------
    -- Player must actually have the required materials.
    --------------------------------------------------------
    local invCheck = player:getInventory()
    if not invCheck:contains("SandingBlock") or not invCheck:contains("SpraycanVinylCoat") then
        print("[SwapVehicle] Rejected: " .. tostring(player:getUsername()) .. " missing required items")
        return
    end

    --------------------------------------------------------
    -- All checks passed: lock in the cooldown and consume
    -- materials here (server-authoritative), so a spoofed
    -- client command can't skip the cost the way the client-
    -- side ISSwapVinylAction used to enforce on its own.
    --------------------------------------------------------
    MarkSwapTime(player)

    local sanding = invCheck:getFirstType("SandingBlock")
    if sanding then
        local condition = sanding:getCondition()
        if condition > 1 then
            sanding:setCondition(condition - 1)
            if sanding.syncItemFields then sanding:syncItemFields() end
        else
            invCheck:Remove(sanding)
            sendRemoveItemFromContainer(invCheck, sanding)
        end
    end

    local spray = invCheck:getFirstType("SpraycanVinylCoat")
    if spray then
        invCheck:Remove(spray)
        sendRemoveItemFromContainer(invCheck, spray)
    end

    local partSet = SwapVehicleRegistry.PartSets[group] or SwapVehicleRegistry.PartSets.Default

    --------------------------------------------------------
    -- Capture lightbar condition
    --------------------------------------------------------
    local oldLightbarCondition = nil
    do
        local lb = vehicle:getPartById("lightbar")
        if lb then oldLightbarCondition = lb:getCondition() end
    end

    --------------------------------------------------------
    -- Capture loot references
    --------------------------------------------------------
    local lootData = CaptureLootReferences(vehicle)

    --------------------------------------------------------
    -- Capture part conditions
    --------------------------------------------------------
    local saved = {}
    for _, id in ipairs(partSet) do
        local part = vehicle:getPartById(id)
        if part then saved[id] = part:getCondition() end
    end

    --------------------------------------------------------
    -- CAPTURE TANK DATA
    --------------------------------------------------------
    local oldTankPart = vehicle:getPartById("GasTank")
    local oldTankItem = oldTankPart and oldTankPart:getInventoryItem()

    local oldTankType = oldTankItem and oldTankItem:getFullType()
    local oldTankCondition = oldTankItem and oldTankItem:getCondition()
    local oldTankFuel = oldTankPart and oldTankPart:getContainerContentAmount()

    -- print("[SwapVehicle] Old tank item: " .. tostring(oldTankType))
    -- print("[SwapVehicle] Old tank condition: " .. tostring(oldTankCondition))
    -- print("[SwapVehicle] Old tank fuel: " .. tostring(oldTankFuel))

    --------------------------------------------------------
    -- Capture battery
    --------------------------------------------------------
    local oldBatteryPart = vehicle:getPartById("Battery")
    local oldBatteryItem = oldBatteryPart and oldBatteryPart:getInventoryItem()
    if oldBatteryItem then oldBatteryPart:setInventoryItem(nil) end

    --------------------------------------------------------
    -- Capture key
    --------------------------------------------------------
    local oldKeyId = vehicle:getKeyId()
    local keyItem = nil
    local keyName = nil

    if oldKeyId and oldKeyId ~= -1 then
        local inv = player:getInventory()
        keyItem = inv:getFirstTypeEvalRecurse("Key", function(item)
            return item:getKeyId() == oldKeyId
        end)
        if keyItem then keyName = keyItem:getName() end
    end

    --------------------------------------------------------
    -- Save position + rotation (SAFE) -- must all happen BEFORE removal
    --------------------------------------------------------
    local x, y, z = vehicle:getX(), vehicle:getY(), vehicle:getZ()

    local angle = 0
    if vehicle.getAngle then
        angle = vehicle:getAngle() or 0
    end

    local dir = 0
    if vehicle.getDir then
        dir = vehicle:getDir() or 0
    end

    local forward = nil
    if vehicle.getForwardDirection then
        forward = vehicle:getForwardDirection()
    end

    -- Capture quaternion rotation from OLD vehicle (must happen before permanentlyRemove)
    local rot = nil
    if vehicle.getWorldRotation then
        rot = vehicle:getWorldRotation()
    end

    --------------------------------------------------------
    -- Remove old vehicle
    --------------------------------------------------------
    vehicle:permanentlyRemove()

    --------------------------------------------------------
    -- Spawn new vehicle
    --------------------------------------------------------
    local spawnSquare = getCell():getGridSquare(math.floor(x), math.floor(y), math.floor(z))
    if not spawnSquare then
        -- print("[SwapVehicle] ERROR: No valid grid square at " .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z))
        return
    end

    -- print("[SwapVehicle] Attempting addVehicleDebug with script: '" .. tostring(newScript) .. "'")
    local newVehicle = addVehicleDebug(newScript, IsoDirections.N, nil, spawnSquare)
    -- print("[SwapVehicle] addVehicleDebug returned: " .. tostring(newVehicle))
    if not newVehicle then return end

    local newVehicleId = newVehicle:getId()

    --------------------------------------------------------
    -- Force new vehicle to old transform (Quaternion-Based)
    --------------------------------------------------------

    -- Apply position
    if newVehicle.setX then newVehicle:setX(x) end
    if newVehicle.setY then newVehicle:setY(y) end
    if newVehicle.setZ then newVehicle:setZ(z) end

    if newVehicle.setWorldPos then
        newVehicle:setWorldPos(x, y, z)
    end

    -- Apply rotation using quaternion captured from the old vehicle
    if rot and newVehicle.setWorldRotation then
        newVehicle:setWorldRotation(rot)
    end

    -- Reset movement
    if newVehicle.setCurrentSpeed then newVehicle:setCurrentSpeed(0) end
    if newVehicle.setEngineSpeed then newVehicle:setEngineSpeed(0) end
    if newVehicle.setEngineStarted then newVehicle:setEngineStarted(false) end

    -- Transmit corrected state
    if newVehicle.transmitPosition then newVehicle:transmitPosition() end
    if newVehicle.transmitDirection then newVehicle:transmitDirection() end
    if newVehicle.transmitEngine then newVehicle:transmitEngine() end

    --------------------------------------------------------
    -- Restore key
    --------------------------------------------------------
    if oldKeyId and oldKeyId ~= -1 then
        newVehicle:setKeyId(oldKeyId)

        if keyItem then
            keyItem:setKeyId(oldKeyId)
            keyItem:setVehicle(newVehicle)
            if keyName then keyItem:setName(keyName) end
        else
            local inv = player:getInventory()
            local newKey = inv:AddItem("Base.Key")
            if newKey then
                newKey:setKeyId(oldKeyId)
                newKey:setVehicle(newVehicle)
                if keyName then newKey:setName(keyName) end
            end
        end
    end

    --------------------------------------------------------
    -- Clean new vehicle
    --------------------------------------------------------
    if newVehicle.setRust then newVehicle:setRust(0) end
    if newVehicle.setDirt then newVehicle:setDirt(0) end

    --------------------------------------------------------
    -- Restore part conditions
    --------------------------------------------------------
    for id, cond in pairs(saved) do
        local part = newVehicle:getPartById(id)
        if part then part:setCondition(cond) end
    end

    --------------------------------------------------------
    -- Restore lightbar
    --------------------------------------------------------
    if oldLightbarCondition then
        local lb = newVehicle:getPartById("lightbar")
        if lb then lb:setCondition(oldLightbarCondition) end
        QueueLightbarRestore(newVehicleId, oldLightbarCondition)
    end

    --------------------------------------------------------
    -- Restore battery
    --------------------------------------------------------
    if oldBatteryItem then
        local newBatteryPart = newVehicle:getPartById("Battery")
        if newBatteryPart then newBatteryPart:setInventoryItem(oldBatteryItem) end
    end

    --------------------------------------------------------
    -- RESTORE TANK
    --------------------------------------------------------
    if oldTankType then
        local newTankPart = newVehicle:getPartById("GasTank")

        if newTankPart then
            -- print("[SwapVehicle] Removing new car's default tank item")
            newTankPart:setInventoryItem(nil)

            -- print("[SwapVehicle] Installing tank item: " .. tostring(oldTankType))
            local newTankItem = instanceItem(oldTankType)

            if newTankItem then
                newTankItem:setCondition(oldTankCondition or 100)
                newTankPart:setInventoryItem(newTankItem)
                newTankPart:setContainerContentAmount(oldTankFuel or 0)

                -- print("[SwapVehicle] Tank condition restored: " .. tostring(oldTankCondition))
                -- print("[SwapVehicle] Tank fuel restored: " .. tostring(oldTankFuel))
            else
                -- print("[SwapVehicle] ERROR: Failed to create tank item " .. tostring(oldTankType))
            end
        else
            print("[SwapVehicle] ERROR: New vehicle has no GasTank part")
        end
    end

    --------------------------------------------------------
    -- Clear new vehicle containers, then restore loot
    --------------------------------------------------------
    ClearNewVehicleContainers(newVehicle)
    RestoreLootFromReferences(newVehicle, lootData)
end

------------------------------------------------------------
-- Event hook
------------------------------------------------------------
Events.OnClientCommand.Add(function(module, command, player, args)
    if module == "SwapVehicle" and command == "Swap" then
        SwapVehicle_Server_Handle(player, args)
    end
end)