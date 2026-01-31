------------------------------------------------------------
-- SwapVehicle Server Logic (SAFE + FINAL)
------------------------------------------------------------

if not SwapVehicleRegistry then
    print("ERROR: SwapVehicleRegistry missing! (Vanilla/KI5 registry not loaded)")
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
        local vehicle = getVehicleById(newVehicleId)
        if not vehicle then Events.OnTick.Remove(tickFunc) return end

        local gasTank = vehicle:getPartById("GasTank")
        if gasTank then
            local current = gasTank:getContainerContentAmount()
            if math.abs(current - targetFuel) < 0.01 then
                Events.OnTick.Remove(tickFunc)
                return
            end
            gasTank:setContainerContentAmount(targetFuel)
        end

        if ticks >= maxTicks then
            Events.OnTick.Remove(tickFunc)
        end
    end

    Events.OnTick.Add(tickFunc)
end

------------------------------------------------------------
-- Main swap handler
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
    -- Capture part conditions
    --------------------------------------------------------
    local saved = {}
    for _, id in ipairs(partSet) do
        local part = vehicle:getPartById(id)
        if part then saved[id] = part:getCondition() end
    end

    --------------------------------------------------------
    -- Capture full tank data
    --------------------------------------------------------
    local oldTank = vehicle:getPartById("GasTank")
    local tankData = {}

    if oldTank then
        tankData.capacity  = oldTank:getContainerCapacity()
        tankData.condition = oldTank:getCondition()
        tankData.fuel      = oldTank:getContainerContentAmount()
    end

    --------------------------------------------------------
    -- Capture battery item
    --------------------------------------------------------
    local oldBatteryPart = vehicle:getPartById("Battery")
    local oldBatteryItem = oldBatteryPart and oldBatteryPart:getInventoryItem()

    if oldBatteryItem then
        oldBatteryPart:setInventoryItem(nil)
    end

    --------------------------------------------------------
    -- Save position
    --------------------------------------------------------
    local x, y, z = vehicle:getX(), vehicle:getY(), vehicle:getZ()

    --------------------------------------------------------
    -- Remove old vehicle
    --------------------------------------------------------
    vehicle:permanentlyRemove()

    --------------------------------------------------------
    -- Spawn new vehicle
    --------------------------------------------------------
    local newVehicle = addVehicle(newScript, math.floor(x), math.floor(y), math.floor(z))
    if not newVehicle then return end

    local newVehicleId = newVehicle:getId()

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
    -- Restore battery item
    --------------------------------------------------------
    if oldBatteryItem then
        local newBatteryPart = newVehicle:getPartById("Battery")
        if newBatteryPart then newBatteryPart:setInventoryItem(oldBatteryItem) end
    end

    --------------------------------------------------------
    -- Restore tank capacity + condition
    --------------------------------------------------------
    if tankData.capacity then
        local newTank = newVehicle:getPartById("GasTank")
        if newTank then
            if newTank.setContainerCapacity then
                newTank:setContainerCapacity(tankData.capacity)
            end
            newTank:setCondition(tankData.condition)
        end
    end

    --------------------------------------------------------
    -- Restore fuel
    --------------------------------------------------------
    if tankData.fuel then
        QueueFuelRestoreStabilized(newVehicleId, tankData.fuel)
    end
end

------------------------------------------------------------
-- Event hook
------------------------------------------------------------
Events.OnClientCommand.Add(function(module, command, player, args)
    if module == "SwapVehicle" and command == "Swap" then
        SwapVehicle_Server_Handle(player, args)
    end
end)