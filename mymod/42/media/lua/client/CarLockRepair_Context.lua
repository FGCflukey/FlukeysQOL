local function isLockBroken(part)
    local door = part:getDoor()
    if door and door.isLockBroken then
        return door:isLockBroken()
    end
    return part:getModData().LockBroken == true
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
                        ISTimedActionQueue.add(RepairCarLockAction:new(player, vehicle, part))
                    end
                )
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(addRepairCarLockOption)