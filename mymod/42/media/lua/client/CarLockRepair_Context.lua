require("Vehicles/ISUI/ISVehicleMenu")

local function isLockBroken(part)
    local door = part:getDoor()
    return door ~= nil and door:isLockBroken()
end

local function playerHasTools(player)
    local inv = player:getInventory()
    return inv:containsTypeRecurse("Screwdriver") and
           inv:containsTypeRecurse("Paperclip")
end

local function canRepairLock(player)
    local mech = player:getPerkLevel(Perks.Mechanics)
    local mw = player:getPerkLevel(Perks.MetalWelding)

    if mw < 2 then return false end
    if mech < 0 then return false end

    return true
end

-- Mirrors VehicleLockMechanicsUI's walkToPart: without this, the repair action still
-- runs and completes on its timer, but the vehicle-work animation has nowhere to
-- attach to since the character was never moved to the door's area, so it silently
-- doesn't play.
local function walkToPart(playerObj, part)
    if playerObj:getVehicle() == part:getVehicle() then
        return
    end
    local area = part:getArea()
    if not area then
        return
    end
    ISTimedActionQueue.add(ISPathFindAction:pathToVehicleArea(playerObj, part:getVehicle(), area))
end

local function onRepairCarLock(playerObj, part)
    if playerObj:getVehicle() ~= part:getVehicle() and playerObj:getVehicle() then
        ISVehicleMenu.onExit(playerObj)
    end
    walkToPart(playerObj, part)
    ISTimedActionQueue.add(RepairCarLockAction:new(playerObj, part))
end

local function addRepairCarLockOption(playerIndex, context, worldobjects, test)
    local player = getSpecificPlayer(playerIndex)
    if not player then return end

    local vehicle = ISVehicleMenu.getVehicleToInteractWith(player)
    if not vehicle then return end

    for _, doorId in ipairs({"DoorFrontLeft", "DoorFrontRight", "DoorRearLeft", "DoorRearRight"}) do
        local part = vehicle:getPartById(doorId)
        if part and isLockBroken(part) then

            if test then return true end

            if canRepairLock(player) and playerHasTools(player) then
                context:addOption(
                    "Repair Car Door Lock (" .. doorId .. ")",
                    vehicle,
                    function()
                        onRepairCarLock(player, part)
                    end
                )
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(addRepairCarLockOption)