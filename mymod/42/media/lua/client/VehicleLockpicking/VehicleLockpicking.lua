require "VehicleLockpicking/VehicleLockpickTimedAction"

-------------------------------------------------
-- Reliable recursive item search (42.20 safe)
-------------------------------------------------

local function findItemRecursive(container, itemTypes)
    if not container then return nil end

    if type(itemTypes) == "string" then
        itemTypes = { itemTypes }
    end

    -- direct check
    for _, t in ipairs(itemTypes) do
        local item = container:getFirstType(t)
        if item then return item end
    end

    -- nested containers
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local obj = items:get(i)
        if obj:IsInventoryContainer() then
            local found = findItemRecursive(obj:getItemContainer(), itemTypes)
            if found then return found end
        end
    end

    return nil
end

-------------------------------------------------
-- Tool checks (supports multitools)
-------------------------------------------------

local function hasTools(player)
    local inv = player:getInventory()

    -- Any of these count as the "tool"
    local tool = findItemRecursive(inv, {
        "Screwdriver",
        "Base.Multitool",
        "Base.SurvivorMultitool"
    })

    -- Paperclip still required
    local paperclip = findItemRecursive(inv, "Paperclip")

    return tool ~= nil and paperclip ~= nil
end

-------------------------------------------------
-- Detect locked vehicle door near player
-------------------------------------------------

local function getLockedVehicleDoor(player)
    local vehicle = player:getNearVehicle()
    if not vehicle then return nil, nil end

    local parts = {
        "DoorFrontLeft",
        "DoorFrontRight",
        "DoorRearLeft",
        "DoorRearRight"
    }

    for _, id in ipairs(parts) do
        local part = vehicle:getPartById(id)
        if part and part:getDoor() and part:getDoor():isLocked() then
            return vehicle, part
        end
    end

    return nil, nil
end

-------------------------------------------------
-- Context menu entry
-------------------------------------------------

local function onFillWorldObjectContextMenu(playerIndex, context, worldobjects, test)
    if test then return end

    local player = getSpecificPlayer(playerIndex)
    if not player then return end

    local vehicle, part = getLockedVehicleDoor(player)
    if not vehicle or not part then return end

    if not hasTools(player) then return end

    context:addOption(
        "Pick Vehicle Lock",
        worldobjects,
        function()
            ISTimedActionQueue.add(
                VehicleLockpickTimedAction:new(
                    player,
                    vehicle,
                    part,
                    ZombRand(6, 11) * 30
                )
            )
        end
    )
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
