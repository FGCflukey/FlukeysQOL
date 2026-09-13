require "LockpickTimedAction"

-------------------------------------------------
-- Utility: determine if object is a door
-------------------------------------------------

local function isDoorObject(obj)
    if not obj then return false end
    if instanceof(obj, "IsoDoor") then return true end
    if instanceof(obj, "IsoThumpable") and obj.isDoor and obj:isDoor() then
        return true
    end
    return false
end

-------------------------------------------------
-- Find the linked set of door objects for a target square
--
-- The door object on THIS exact square only -- NOT a 3x3 neighbor
-- scan. A garage door is a linked CHAIN of separate door segments
-- (IsoDoor.getGarageDoorPrev/Next) that can span more tiles than a
-- fixed 3x3 area, and a blind neighbor scan can also wrongly catch an
-- unrelated nearby door. buildUtil.getDoubleDoorObjects/
-- getGarageDoorObjects -- the same real vanilla helpers
-- shared/TimedActions/ISLockDoor.lua itself uses -- correctly walk
-- the real chain from a single starting door instead.
-------------------------------------------------

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

-------------------------------------------------
-- Safe lock check for cluster
-------------------------------------------------

-- getKeyId() ~= -1 was checked here before -- that's WRONG. getKeyId()
-- just says which key CAN lock/unlock this door (a structural property
-- from how the door/building was generated); it says nothing about
-- whether it's actually locked right now. Almost every real door has
-- some key ID assigned whether it's locked or not, so that check alone
-- made "Pick Lock" appear on nearly any door with a real lock
-- mechanism, closed-and-unlocked included. Only the three real "is it
-- actually locked" flags below matter.
local function clusterLocked(doors)
    for _, door in ipairs(doors) do
        if door then
            if door.isLocked and door:isLocked() then return true end
            if door.isLockedByKey and door:isLockedByKey() then return true end
            if door.isLockedByPadlock and door:isLockedByPadlock() then return true end
        end
    end
    return false
end

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

local function hasLockpickTools(player)
    local inv = player:getInventory()

    local tool = findItemRecursive(inv, {
        "Screwdriver",
        "Base.Multitool",
        "Base.SurvivorMultitool"
    })

    local paperclip = findItemRecursive(inv, "Paperclip")

    return tool ~= nil and paperclip ~= nil
end

-------------------------------------------------
-- Pick lock action (doors only, timed)
--
-- No local door mutation or paperclip removal here anymore -- the
-- server re-derives the same door cluster from these square coords
-- and is the only place that decides success/failure and actually
-- unlocks anything now. See Lockpicking_Server.lua.
-------------------------------------------------

local function onPickLock(worldobjects, playerIndex)
    local player = getSpecificPlayer(playerIndex)
    if not player then return end

    local square = nil
    if worldobjects and #worldobjects > 0 then
        local obj = worldobjects[1]
        if obj and obj.getSquare then
            square = obj:getSquare()
        end
    end
    if not square then
        local sq = player:getSquare()
        if sq then square = sq:getTileInDirection(player:getDir()) end
    end
    if not square then return end

    local door = getDoorAtSquare(square)
    if not door then
        player:Say("There's nothing to pick here.")
        return
    end

    if not hasLockpickTools(player) then
        player:Say("I need a screwdriver or multitool, and a paperclip.")
        return
    end

    ISTimedActionQueue.add(
        LockpickTimedAction:new(player, door, square, ZombRand(6, 11) * 30)
    )
end

-------------------------------------------------
-- Context menu
-------------------------------------------------

local function onFillWorldObjectContextMenu(playerIndex, context, worldobjects, test)
    if test then return end

    local player = getSpecificPlayer(playerIndex)
    if not player then return end

    local square = nil
    if worldobjects and #worldobjects > 0 then
        local obj = worldobjects[1]
        if obj and obj.getSquare then
            square = obj:getSquare()
        end
    end
    if not square then
        local sq = player:getSquare()
        if sq then square = sq:getTileInDirection(player:getDir()) end
    end
    if not square then return end

    local door = getDoorAtSquare(square)
    if not door then return end

    -- Vanilla itself never offers a lock/unlock option on an open door
    -- (confirmed: ISWorldObjectContextMenu's own door menu shows only
    -- "Close Door" for one, no lock-related entries at all) -- a door's
    -- stored lock flags can stay stale/irrelevant while it's open, so
    -- "Pick Lock" showing up on an obviously-open, obviously-unlocked
    -- door was exactly that: match the same real-door:IsOpen() guard.
    if door.IsOpen and door:IsOpen() then return end

    if not clusterLocked(getRelatedDoors(door)) then return end
    if not hasLockpickTools(player) then return end

    context:addOption("Pick Lock", worldobjects, onPickLock, playerIndex)
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
