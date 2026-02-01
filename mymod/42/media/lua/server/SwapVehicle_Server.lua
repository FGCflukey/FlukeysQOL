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
-- Main Swap Handler
------------------------------------------------------------
function SwapVehicle_Server_Handle(player, args)
    local vehicle = getVehicleById(args.vehicleId)
    if not vehicle then return end

    local oldScript = vehicle:getScript():getFullName()
    local newScript = args.newScript

    --------------------------------------------------------
    -- Determine part set
    --------------------------------------------------------
    local group = SwapVehicleRegistry.Groups[oldScript]
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

    print("[SwapVehicle] Old tank item: " .. tostring(oldTankType))
    print("[SwapVehicle] Old tank condition: " .. tostring(oldTankCondition))
    print("[SwapVehicle] Old tank fuel: " .. tostring(oldTankFuel))

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
    -- Save position + rotation (SAFE)
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

    --------------------------------------------------------
    -- Remove old vehicle
    --------------------------------------------------------
    vehicle:permanentlyRemove()

    --------------------------------------------------------
    -- Spawn new vehicle
    --------------------------------------------------------
    local newVehicle = addVehicle(newScript, x, y, z)
    if not newVehicle then return end

    local newVehicleId = newVehicle:getId()

    --------------------------------------------------------
    -- Force new vehicle to old transform (Quaternion‑Based)
    --------------------------------------------------------

    -- Capture quaternion rotation from old vehicle
    local rot = nil
    if vehicle.getWorldRotation then
        rot = vehicle:getWorldRotation()
    end

    -- Apply position
    if newVehicle.setX then newVehicle:setX(x) end
    if newVehicle.setY then newVehicle:setY(y) end
    if newVehicle.setZ then newVehicle:setZ(z) end

    if newVehicle.setWorldPos then
        newVehicle:setWorldPos(x, y, z)
    end

    -- Apply rotation using quaternion
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
            print("[SwapVehicle] Removing new car's default tank item")
            newTankPart:setInventoryItem(nil)

            print("[SwapVehicle] Installing tank item: " .. tostring(oldTankType))
            local newTankItem = instanceItem(oldTankType)

            if newTankItem then
                newTankItem:setCondition(oldTankCondition or 100)
                newTankPart:setInventoryItem(newTankItem)
                newTankPart:setContainerContentAmount(oldTankFuel or 0)

                print("[SwapVehicle] Tank condition restored: " .. tostring(oldTankCondition))
                print("[SwapVehicle] Tank fuel restored: " .. tostring(oldTankFuel))
            else
                print("[SwapVehicle] ERROR: Failed to create tank item " .. tostring(oldTankType))
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