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

-- Capture references to containers + items
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

-- Clear all items from the new vehicle's containers
local function ClearNewVehicleContainers(newVehicle)
    for _, id in ipairs(VANILLA_CONTAINERS) do
        local part = newVehicle:getPartById(id)
        if part and part:getItemContainer() then
            part:getItemContainer():clear()
        end
    end
end

-- Restore items from old container references into new vehicle
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
    -- Capture loot references (Lua table method)
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
    -- Capture tank data
    --------------------------------------------------------
    local tank = vehicle:getPartById("GasTank")
    local tankData = {}
    if tank then
        tankData.capacity  = tank:getContainerCapacity()
        tankData.condition = tank:getCondition()
        tankData.fuel      = tank:getContainerContentAmount()
    end

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
    -- Restore tank
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