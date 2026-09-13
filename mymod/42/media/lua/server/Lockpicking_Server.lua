-- server/Lockpicking_Server.lua
-- Server-authoritative handler for the (building-door) Lockpicking mod.
--
-- Same architectural gap as VehicleLockpicking had: Lockpicking.lua /
-- LockpickTimedAction.lua decided success/failure and mutated door
-- lock flags (setLocked/setIsLocked/setLockedByKey/setLockedByPadlock/
-- setKeyId) entirely client-side, with no server file at all.
--
-- Unlike vehicle parts, a plain building door's lock state appears to
-- sync via the engine's normal object/chunk replication rather than
-- needing an explicit transmit call -- vanilla's own admin debug door
-- lock toggle (AdminContextMenu.OnDoorLock / DebugContextMenu.OnDoorLock)
-- does a bare door:setIsLocked() with no sync call afterward and is
-- known-working live in MP -- so this may not have shown the exact
-- "looks unlocked to me but not to others" visual symptom
-- VehicleLockpicking did. But the security gap is identical either
-- way: with zero server validation, a modified client could report
-- success and unlock any door without ever having the required tools.
-- Fixed to match this pack's "never trust the client" architecture,
-- same shape as VehicleLockpicking_Server.lua.

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

-- Mirrors Lockpicking.lua's own getDoorCluster() -- re-derived here
-- from square coords rather than trusting a client-sent object list.
local function getDoorCluster(square)
    local doors = {}
    if not square then return doors end

    local cell = square:getCell()
    local sx, sy, sz = square:getX(), square:getY(), square:getZ()

    local function addFromSquare(sq)
        if not sq then return end
        local objs = sq:getSpecialObjects()
        for i = 0, objs:size() - 1 do
            local obj = objs:get(i)
            if isDoorObject(obj) then
                table.insert(doors, obj)
            end
        end
    end

    for dx = -1, 1 do
        for dy = -1, 1 do
            addFromSquare(cell:getGridSquare(sx + dx, sy + dy, sz))
        end
    end

    return doors
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

    local doors = getDoorCluster(square)
    if #doors == 0 then
        dbg("No doors found in cluster at request square")
        return
    end

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

        dbg("Unlock succeeded for " .. tostring(player:getUsername()))
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
