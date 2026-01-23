require "VehicleLockpicking/VehicleLockpicking"

local old_showRadial = ISVehicleMenu.showRadialMenu

local function hasTools(player)
    local inv = player:getInventory()
    return inv:containsTypeRecurse("Screwdriver")
       and inv:containsTypeRecurse("Paperclip")
end

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

function ISVehicleMenu.showRadialMenu(playerObj)
    old_showRadial(playerObj)

    local player = playerObj
    local vehicle, part = getLockedVehicleDoor(player)
    if not vehicle or not part then return end
    if not hasTools(player) then return end

    local menu = getPlayerRadialMenu(player:getPlayerNum())
    if not menu then return end

    menu:addSlice(
        "Pick Lock",
        getTexture("media/ui/vehicles/lockpick.png"),
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