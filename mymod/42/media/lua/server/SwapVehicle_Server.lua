---------------------------------------------------------
-- Multi-tick fuel restore with stabilization
---------------------------------------------------------
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
            print("SERVER: Fuel tick", ticks, "current =", current, "target =", targetFuel)

            if math.abs(current - targetFuel) < 0.01 then
                print("SERVER: Fuel stable at", current, "stopping fuel restore")
                Events.OnTick.Remove(tickFunc)
                return
            end

            print("SERVER: Fuel mismatch, re-applying =", targetFuel)
            gasTank:setContainerContentAmount(targetFuel)
        end

        if ticks >= maxTicks then
            print("SERVER: FuelRestore: timeout, fuel not stabilized")
            Events.OnTick.Remove(tickFunc)
        end
    end

    print("SERVER: FuelRestore: scheduled, targetFuel =", targetFuel)
    Events.OnTick.Add(tickFunc)
end

---------------------------------------------------------
-- Main handler
---------------------------------------------------------
local function SwapVehicle_Server_Handle(player, args)
    print("SERVER: SwapVehicle_Server_Handle triggered")

    local vehicle = getVehicleById(args.vehicleId)
    print("SERVER: vehicle =", tostring(vehicle))
    if not vehicle then return end

    ---------------------------------------------------------
    -- Dump parts (debug)
    ---------------------------------------------------------
    print("SERVER: Dumping part IDs:")
    local count = vehicle:getPartCount()
    for i = 0, count - 1 do
        local part = vehicle:getPartByIndex(i)
        print("PART:", part:getId(), "COND:", part:getCondition())
    end

    ---------------------------------------------------------
    -- Determine new script
    ---------------------------------------------------------
    local oldScript = vehicle:getScript():getFullName()
    local newScript = nil

    if oldScript == "Base.CarTaxi" then
        newScript = "Base.CarTaxi2"
    elseif oldScript == "Base.CarTaxi2" then
        newScript = "Base.CarTaxi"
    else
        return
    end

    ---------------------------------------------------------
    -- Capture part conditions
    ---------------------------------------------------------
    local partIds = {
        "TrunkDoor","TruckBed",
        "SeatFrontLeft","SeatFrontRight","SeatRearLeft","SeatRearRight",
        "GloveBox","Radio","PassengerCompartment",
        "GasTank","Battery","Engine","Muffler","EngineDoor","Heater",
        "Windshield","WindshieldRear",
        "WindowFrontLeft","WindowFrontRight","WindowRearLeft","WindowRearRight",
        "DoorFrontLeft","DoorFrontRight","DoorRearLeft","DoorRearRight",
        "TireFrontLeft","TireFrontRight","TireRearLeft","TireRearRight",
        "BrakeFrontLeft","BrakeFrontRight","BrakeRearLeft","BrakeRearRight",
        "SuspensionFrontLeft","SuspensionFrontRight",
        "SuspensionRearLeft","SuspensionRearRight",
        "HeadlightLeft","HeadlightRight","HeadlightRearLeft","HeadlightRearRight"
    }

    local saved = {}
    for _, id in ipairs(partIds) do
        local part = vehicle:getPartById(id)
        if part then saved[id] = part:getCondition() end
    end

    ---------------------------------------------------------
    -- Capture fuel level
    ---------------------------------------------------------
    local fuel = nil
    local gasTank = vehicle:getPartById("GasTank")
    if gasTank and gasTank.getContainerContentAmount then
        fuel = gasTank:getContainerContentAmount()
    end
    print("SERVER: Captured fuel =", fuel)

    ---------------------------------------------------------
    -- Capture battery item (for transfer)
    ---------------------------------------------------------
    local oldBatteryPart = vehicle:getPartById("Battery")
    local oldBatteryItem = nil
    if oldBatteryPart and oldBatteryPart.getInventoryItem then
        oldBatteryItem = oldBatteryPart:getInventoryItem()
        if oldBatteryItem then
            print("SERVER: Captured battery item =", tostring(oldBatteryItem))
            -- detach from old vehicle
            oldBatteryPart:setInventoryItem(nil)
        else
            print("SERVER: No battery item found on old vehicle")
        end
    end

    ---------------------------------------------------------
    -- Save position
    ---------------------------------------------------------
    local x, y, z = vehicle:getX(), vehicle:getY(), vehicle:getZ()

    ---------------------------------------------------------
    -- Remove old vehicle
    ---------------------------------------------------------
    vehicle:permanentlyRemove()

    ---------------------------------------------------------
    -- Spawn new vehicle
    ---------------------------------------------------------
    local newVehicle = addVehicle(newScript, math.floor(x), math.floor(y), math.floor(z))
    print("SERVER: newVehicle =", tostring(newVehicle))
    if not newVehicle then return end

    local newVehicleId = newVehicle:getId()

    ---------------------------------------------------------
    -- Clean new vehicle (no rust, no dirt)
    ---------------------------------------------------------
    if newVehicle.setRust then
        newVehicle:setRust(0)
    end
    if newVehicle.setDirt then
        newVehicle:setDirt(0)
    end
    -- Blood is more granular in the engine; leaving it out to avoid calling unknown APIs.

    ---------------------------------------------------------
    -- Restore part conditions
    ---------------------------------------------------------
    for id, cond in pairs(saved) do
        local part = newVehicle:getPartById(id)
        if part then
            part:setCondition(cond)
        end
    end

    ---------------------------------------------------------
    -- Install old battery item into new vehicle
    ---------------------------------------------------------
    if oldBatteryItem then
        local newBatteryPart = newVehicle:getPartById("Battery")
        if newBatteryPart and newBatteryPart.setInventoryItem then
            print("SERVER: Installing old battery item into new vehicle")
            newBatteryPart:setInventoryItem(oldBatteryItem)
        else
            print("SERVER: New vehicle battery part missing or no setInventoryItem")
        end
    end

    ---------------------------------------------------------
    -- Restore fuel (multi-tick stabilization)
    ---------------------------------------------------------
    if fuel then
        QueueFuelRestoreStabilized(newVehicleId, fuel)
    else
        print("SERVER: No fuel captured, skipping fuel restore")
    end
end

---------------------------------------------------------
-- Event hook
---------------------------------------------------------
Events.OnClientCommand.Add(function(module, command, player, args)
    if module == "SwapVehicle" and command == "SwapVehicle_Request" then
        SwapVehicle_Server_Handle(player, args)
    end
end)