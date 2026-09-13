-- server/Lockpicking_Server.lua
-- Server-authoritative handler for the (building-door) Lockpicking mod.
--
-- Same architectural gap as VehicleLockpicking had: Lockpicking.lua /
-- LockpickTimedAction.lua decided success/failure and mutated door
-- lock flags entirely client-side, with no server file at all.
--
-- Two real bugs found and fixed here on top of that:
--
-- 1. The original hand-rolled "door cluster" detection scanned a
--    fixed 3x3 tile neighborhood around the target square. Garage
--    doors are NOT just "whatever's within 3 tiles" -- they're a
--    linked CHAIN of separate IsoDoor segments (IsoDoor.getGarageDoorPrev/
--    Next), which can span more tiles than that, and a 3x3 scan can
--    also wrongly catch an unrelated nearby door. This is exactly why
--    a garage door pick could target the wrong thing while standing
--    "tiles away" from what actually got attempted.
--
-- 2. Nothing ever called door:syncIsoObject(false, 0, nil, nil) after
--    changing lock flags. This is the real, confirmed sync call
--    vanilla's own lock/unlock action uses (shared/TimedActions/
--    ISLockDoor.lua:complete()) -- without it, a "successful" unlock
--    could fail to actually stick/broadcast, which is exactly why the
--    door kept re-reporting as locked on the very next attempt with
--    the log still saying "Unlock succeeded" every time.
--
-- The fix for both: use vanilla's own real helpers for finding every
-- object that must be unlocked together (buildUtil.getDoubleDoorObjects
-- / buildUtil.getGarageDoorObjects -- the exact ones ISLockDoor.lua
-- itself uses), starting from the single door object actually on the
-- target square (no neighbor scan needed -- these helpers walk the
-- real chain themselves), and call syncIsoObject on each one changed.

local DEBUG = true
local function dbg(msg) if DEBUG then print("[Lockpicking:Server] " .. tostring(msg)) end end

local function isDoorObject(obj)
    if not obj then return false end
    if instanceof(obj, "IsoDoor") then return true end
    if instanceof(obj, "IsoThumpable") and obj.isDoor and obj:isDoor() then
        return true
    end
    return false
end

-- The door object on THIS exact square only -- multi-tile doors are
-- resolved below via their real linkage, not by scanning neighbors.
local function getDoorAtSquare(square)
    if not square then return nil end
    local objs = square:getSpecialObjects()
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if isDoorObject(obj) then
            return obj
        end
    end
    return nil
end

-- Expands one door object into every object that must be unlocked
-- together with it, using the same real vanilla helpers
-- shared/TimedActions/ISLockDoor.lua uses.
local function getRelatedDoors(door)
    local seen = {}
    local list = {}

    local function add(d)
        if d and not seen[d] then
            seen[d] = true
            table.insert(list, d)
        end
    end

    add(door)
    for _, d in ipairs(buildUtil.getDoubleDoorObjects(door)) do add(d) end
    for _, d in ipairs(buildUtil.getGarageDoorObjects(door)) do add(d) end

    return list
end

local function clusterLocked(doors)
    for _, door in ipairs(doors) do
        if door then
            if door.isLocked and door:isLocked() then return true end
            if door.isLockedByKey and door:isLockedByKey() then return true end
            if door.isLockedByPadlock and door:isLockedByPadlock() then return true end
            if door.getKeyId and door:getKeyId() ~= -1 then return true end
        end
    end
    return false
end

local function unlockDoorObject(door)
    if not door then return end
    if door.setLocked then door:setLocked(false) end
    if door.setIsLocked then door:setIsLocked(false) end
    if door.setLockedByKey then door:setLockedByKey(false) end
    if door.setLockedByPadlock then door:setLockedByPadlock(false) end
    if door.setKeyId then door:setKeyId(-1) end
    if door.syncIsoObject then door:syncIsoObject(false, 0, nil, nil) end
end

local function getLockpickSuccessChance(player)
    local mech = player:getPerkLevel(Perks.Mechanics)

    if mech <= 2 then
        return 15
    elseif mech <= 4 then
        return 45
    elseif mech <= 8 then
        return 75
    else
        return 100
    end
end

local function hasTools(player)
    local inv = player:getInventory()

    local tool = inv:getFirstTypeRecurse("Screwdriver")
        or inv:getFirstTypeRecurse("Base.Multitool")
        or inv:getFirstTypeRecurse("Base.SurvivorMultitool")
    local paperclip = inv:getFirstTypeRecurse("Paperclip")

    return tool ~= nil and paperclip ~= nil
end

local function OnClientCommand(module, command, player, args)
    if module ~= "Lockpicking" or command ~= "attemptPickLock" then return end

    if not player or not args or not args.x or not args.y or not args.z then
        dbg("Malformed attemptPickLock request, ignoring")
        return
    end

    local square = getSquare(args.x, args.y, args.z)
    if not square then
        dbg("Square not found for " .. tostring(args.x) .. "," .. tostring(args.y) .. "," .. tostring(args.z))
        return
    end

    local playerSquare = player:getSquare()
    if not playerSquare or playerSquare:DistToProper(square) > 2 then
        dbg("Player too far from door, rejecting")
        return
    end

    local door = getDoorAtSquare(square)
    if not door then
        dbg("No door found at request square")
        return
    end

    local doors = getRelatedDoors(door)

    if not clusterLocked(doors) then
        dbg("Door cluster already unlocked, nothing to do")
        sendServerCommand(player, "Lockpicking", "lockpickResult", { success = true })
        return
    end

    if not hasTools(player) then
        dbg("REJECT: missing tools server-side for " .. tostring(player:getUsername()))
        return
    end

    -- Roll server-side -- trusting a client-reported result would let a
    -- modified client always report success.
    local chance = getLockpickSuccessChance(player)
    local roll = ZombRand(100)

    if roll < chance then
        for _, d in ipairs(doors) do
            unlockDoorObject(d)
        end

        dbg("Unlock succeeded for " .. tostring(player:getUsername()) .. " (" .. #doors .. " linked door object(s))")
        sendServerCommand(player, "Lockpicking", "lockpickResult", { success = true })
    else
        dbg("Unlock failed for " .. tostring(player:getUsername()))

        local broke = ZombRand(100) < 35
        if broke then
            local inv = player:getInventory()
            local pc = inv:getFirstTypeRecurse("Paperclip")
            if pc then
                local container = pc:getContainer() or inv
                container:Remove(pc)
                sendRemoveItemFromContainer(container, pc)
            end
        end

        sendServerCommand(player, "Lockpicking", "lockpickResult", { success = false, broke = broke })
    end
end

Events.OnClientCommand.Add(OnClientCommand)
