------------------------------------------------------------
-- SwapVehicle Server Logic
-- Fully registry-driven, preserves all original behaviors:
-- ✔ Part conditions
-- ✔ Battery item
-- ✔ Fuel (multi-tick stabilization)
-- ✔ Position
-- ✔ Rust/Dirt cleaning
-- ❌ No Taxi hardcoding
-- ✔ Supports all registry groups (Vanilla + KI5)
------------------------------------------------------------

if not SwapVehicleRegistry then
    print("ERROR: SwapVehicleRegistry missing! (Vanilla/KI5 registry not loaded)")
    return
end

------------------------------------------------------------
-- Multi-tick fuel restore with stabilization (unchanged)
------------------------------------------------------------
local function QueueFuelRestoreStabilized(newVehicleId, targetFuel)
    if not targetFuel then
        print("SERVER: QueueFuelRestoreStabilized: no fuel value to restore")
        return
    end

    local ticks = 0
    local maxTicks = 300 -- ~5 seconds at 60 FPS

    local function tickFunc()
        ticks = ticks + 1
        local vehicle = getVehicleById(newVehicleId)
        if not vehicle then
            print("SERVER: FuelRestore: vehicle gone, aborting")
            Events.OnTick.Remove(tickFunc)
            return
        end

        local gasTank = vehicle:getPartById("GasTank")
        if gasTank and gasTank.getContainerContentAmount and gasTank.setContainerContentAmount then
            local current = gasTank:getContainerContentAmount()
            if math.abs(current - targetFuel) < 0.01 then
                Events.OnTick.Remove(tickFunc)
                return
            end
            gasTank:setContainerContentAmount(targetFuel)
        end

        if ticks >= maxTicks then
            print("SERVER: FuelRestore: timeout, fuel not stabilized")
            Events.OnTick.Remove(tickFunc)
        end
    end

    Events.OnTick.Add(tickFunc)
end

------------------------------------------------------------
-- Main swap handler
------------------------------------------------------------
function SwapVehicle_Server_Handle(player, args)
    print("SERVER: SwapVehicle_Server_Handle triggered")

    local vehicle = getVehicleById(args.vehicleId)
    if not vehicle then
        print("SERVER: No vehicle found for ID", args.vehicleId)
        return
    end

    local oldScript = vehicle:getScript():getFullName()
    local newScript = args.newScript

    if not newScript then
        print("SERVER: No newScript provided")
        return
    end

    print("SERVER: Swapping", oldScript, "→", newScript)

    --------------------------------------------------------
    -- Determine part set for this group
    --------------------------------------------------------
    local group = SwapVehicleRegistry.Groups[oldScript]
    local partSet = SwapVehicleRegistry.PartSets[group] or SwapVehicleRegistry.PartSets.Default

    --------------------------------------------------------
    -- Capture part conditions
    --------------------------------------------------------
    local saved = {}
    for _, id in ipairs(partSet) do
        local part = vehicle:getPartById(id)
        if part then
            saved[id] = part:getCondition()
        end
    end

    --------------------------------------------------------
    -- Capture fuel level
    --------------------------------------------------------
    local fuel = nil
    local gasTank = vehicle:getPartById("GasTank")
    if gasTank and gasTank.getContainerContentAmount then
        fuel = gasTank:getContainerContentAmount()
    end

    --------------------------------------------------------
    -- Capture battery item
    --------------------------------------------------------
    local oldBatteryPart = vehicle:getPartById("Battery")
    local oldBatteryItem = nil
    if oldBatteryPart and oldBatteryPart.getInventoryItem then
        oldBatteryItem = oldBatteryPart:getInventoryItem()
        if oldBatteryItem then
            oldBatteryPart:setInventoryItem(nil)
        end
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
    if not newVehicle then
        print("SERVER: Failed to spawn new vehicle", newScript)
        return
    end

    local newVehicleId = newVehicle:getId()

    --------------------------------------------------------
    -- Clean new vehicle (no rust, no dirt)
    --------------------------------------------------------
    if newVehicle.setRust then newVehicle:setRust(0) end
    if newVehicle.setDirt then newVehicle:setDirt(0) end

    --------------------------------------------------------
    -- Restore part conditions
    --------------------------------------------------------
    for id, cond in pairs(saved) do
        local part = newVehicle:getPartById(id)
        if part then
            part:setCondition(cond)
        end
    end

    --------------------------------------------------------
    -- Restore battery item
    --------------------------------------------------------
    if oldBatteryItem then
        local newBatteryPart = newVehicle:getPartById("Battery")
        if newBatteryPart and newBatteryPart.setInventoryItem then
            newBatteryPart:setInventoryItem(oldBatteryItem)
        end
    end

    --------------------------------------------------------
    -- Restore fuel (multi-tick stabilization)
    --------------------------------------------------------
    if fuel then
        QueueFuelRestoreStabilized(newVehicleId, fuel)
    end
end

------------------------------------------------------------
-- Event hook (modern command)
------------------------------------------------------------
Events.OnClientCommand.Add(function(module, command, player, args)
    if module == "SwapVehicle" and command == "Swap" then
        SwapVehicle_Server_Handle(player, args)
    end
end)