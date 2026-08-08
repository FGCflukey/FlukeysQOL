require "VehicleLockpicking/VehicleLockpicking"

local LP_DEBUG = true
local function lpdbg(...) if LP_DEBUG then print("[LockpickRadial]", ...) end end

local old_showRadial = ISVehicleMenu.showRadialMenu

local function hasTools(player)
    local inv = player:getInventory()

    -- TOOL: screwdriver OR multitool OR survivor multitool
    local hasTool =
        inv:containsTypeRecurse("Base.Screwdriver") or
        inv:containsTypeRecurse("Screwdriver") or
        inv:containsTypeRecurse("Base.Multitool") or
        inv:containsTypeRecurse("Base.SurvivorMultitool")

    -- PICK: paperclip
    local hasPick =
        inv:containsTypeRecurse("Base.Paperclip") or
        inv:containsTypeRecurse("Paperclip")

    local ok = hasTool and hasPick
    lpdbg("HasTools:", ok, "Tool:", hasTool, "Pick:", hasPick)
    return ok
end

local function getLockedVehicleDoor(player)
    lpdbg("Checking for locked vehicle door...")

    -- Try modern detection
    local vehicle = ISVehicleMenu.getVehicleToInteractWith(player)
    lpdbg("Vehicle via getVehicleToInteractWith:", vehicle)

    -- Fallback to old detection
    if not vehicle then
        vehicle = player:getNearVehicle()
        lpdbg("Fallback getNearVehicle:", vehicle)
    end

    if not vehicle then
        lpdbg("No vehicle detected.")
        return nil, nil
    end

    local parts = {
        "DoorFrontLeft",
        "DoorFrontRight",
        "DoorRearLeft",
        "DoorRearRight"
    }

    for _, id in ipairs(parts) do
        local part = vehicle:getPartById(id)
        if part and part:getDoor() then
            lpdbg("Checking door:", id, "Locked:", part:getDoor():isLocked())
            if part:getDoor():isLocked() then
                lpdbg("Found locked door:", id)
                return vehicle, part
            end
        end
    end

    lpdbg("No locked doors found.")
    return nil, nil
end

function ISVehicleMenu.showRadialMenu(playerObj)
    lpdbg("showRadialMenu fired.")

    old_showRadial(playerObj)

    local player = playerObj
    local vehicle, part = getLockedVehicleDoor(player)

    lpdbg("Vehicle:", vehicle, "Part:", part)

    if not vehicle or not part then
        lpdbg("No valid vehicle/door → abort.")
        return
    end

    if not hasTools(player) then
        lpdbg("Missing tools → abort.")
        return
    end

    local menu = getPlayerRadialMenu(player:getPlayerNum())
    lpdbg("Radial menu:", menu)

    if not menu then
        lpdbg("No radial menu found → abort.")
        return
    end

    lpdbg("Adding lockpick slice to radial menu.")

    menu:addSlice(
        "Pick Lock",
        getTexture("media/ui/vehicles/lockpick.png"),
        function()
            lpdbg("Lockpick slice activated.")
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
