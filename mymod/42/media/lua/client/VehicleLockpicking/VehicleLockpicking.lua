require "VehicleLockpicking/VehicleLockpickTimedAction"

-------------------------------------------------
-- Tool checks
-------------------------------------------------

local function hasTools(player)
    local inv = player:getInventory()
    return inv:containsTypeRecurse("Screwdriver")
       and inv:containsTypeRecurse("Paperclip")
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