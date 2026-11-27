require "LockpickTimedAction"

local DEBUG = true
local function dbg(...) if DEBUG then print("[Lockpicking]", ...) end end

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
-- Proximity: "Pick Lock" is only offered when standing right at the door.
-- For a garage door (a chain of segments) or a double door, being next to
-- ANY segment counts, and that segment's square is the one sent to the
-- server -- so the server's own 2-tile check always passes for a valid pick.
-------------------------------------------------

local PICK_RANGE = 1.5 -- tiles: adjacent, diagonals included

local function getDoorInReach(player, doors)
    local psq = player:getSquare()
    if not psq then return nil end
    local best, bestDist = nil, nil
    for _, d in ipairs(doors) do
        local dsq = d and d:getSquare()
        if dsq and dsq:getZ() == psq:getZ() then
            local dist = psq:DistToProper(dsq)
            if dist <= PICK_RANGE and (not bestDist or dist < bestDist) then
                best, bestDist = d, dist
            end
        end
    end
    return best
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

    -- Re-check reach at click time and target the segment we're actually at
    door = getDoorInReach(player, getRelatedDoors(door))
    if not door then
        player:Say("I need to be right at the door.")
        return
    end
    square = door:getSquare()

    if not hasLockpickTools(player) then
        player:Say("I need a screwdriver or multitool, and a paperclip.")
        return
    end

    ISTimedActionQueue.add(
        LockpickTimedAction:new(player, door, square, ZombRand(6, 11) * 30)
    )
end

-------------------------------------------------
-- Radial menu (V key / controller D-pad Up)
--
-- Vanilla sends the radial key to ISVehicleMenu when a vehicle is in
-- reach, and otherwise to AnimalContextMenu.showRadialMenu (both are
-- bound to V by default, and ISDPadWheels does the same fallback for
-- controllers). So: wrap AnimalContextMenu.showRadialMenu. A car always
-- wins (vanilla never reaches here then), a tame animal in reach wins
-- next, and only when neither is there do we offer "Pick Lock" for a
-- locked door in reach. Key-release-to-close works for free, because
-- vanilla calls this same function again on release to undisplay.
--
-- No worldobjects here, so scan the player's own square + its 8
-- neighbours for door objects. Doors sit on a square's edge, so the
-- door can be on the player's own square or the one they face; the
-- facing tile is preferred, then nearest. Same filters as the
-- right-click option: closed, actually locked, in reach.
-------------------------------------------------

local function findLockedDoorInReach(player)
    local psq = player:getSquare()
    if not psq then return nil end
    local cell = getCell()
    local facing = psq:getTileInDirection(player:getDir())

    local best, bestScore = nil, nil
    for dx = -1, 1 do
        for dy = -1, 1 do
            local sq = cell:getGridSquare(psq:getX() + dx, psq:getY() + dy, psq:getZ())
            local door = getDoorAtSquare(sq)
            if door and not (door.IsOpen and door:IsOpen()) then
                local doors = getRelatedDoors(door)
                if clusterLocked(doors) then
                    local reach = getDoorInReach(player, doors)
                    if reach then
                        local score = psq:DistToProper(reach:getSquare())
                        if sq == facing then score = score - 10 end
                        if not bestScore or score < bestScore then
                            best, bestScore = reach, score
                        end
                    end
                end
            end
        end
    end
    return best
end

local function onRadialPickLock(player, door)
    if not player or not door then return end
    -- Re-validate at click time, same as the right-click path
    if door.IsOpen and door:IsOpen() then return end
    local reach = getDoorInReach(player, getRelatedDoors(door))
    if not reach then
        player:Say("I need to be right at the door.")
        return
    end
    if not hasLockpickTools(player) then
        player:Say("I need a screwdriver or multitool, and a paperclip.")
        return
    end
    dbg("Radial pick started at", reach:getSquare():getX(), reach:getSquare():getY(), reach:getSquare():getZ())
    ISTimedActionQueue.add(
        LockpickTimedAction:new(player, reach, reach:getSquare(), ZombRand(6, 11) * 30)
    )
end

local function installRadialHook()
    if AnimalContextMenu.__lockpickWrapped then return end
    AnimalContextMenu.__lockpickWrapped = true

    local original = AnimalContextMenu.showRadialMenu

    AnimalContextMenu.showRadialMenu = function(playerObj)
        if not playerObj or playerObj:getVehicle() then
            return original(playerObj)
        end

        local playerIndex = playerObj:getPlayerNum()
        local menu = getPlayerRadialMenu(playerIndex)

        -- Menu already open (key release / second press): let vanilla close it
        if not menu or menu:isReallyVisible() then
            return original(playerObj)
        end

        -- A tame animal in reach keeps its vanilla radial
        local animal = AnimalContextMenu.getAnimalToInteractWith(playerObj)
        if animal and not animal:isWild() then
            dbg("Animal in reach, deferring to vanilla radial")
            return original(playerObj)
        end

        local door = findLockedDoorInReach(playerObj)
        if not door or not hasLockpickTools(playerObj) then
            dbg("No locked door/tools for radial. door:", tostring(door ~= nil))
            return original(playerObj)
        end

        dbg("Showing Pick Lock radial")
        menu:clear()
        menu:addSlice("Pick Lock", getTexture("media/ui/vehicles/lockpick.png"), onRadialPickLock, playerObj, door)

        menu:setX(getPlayerScreenLeft(playerIndex) + getPlayerScreenWidth(playerIndex) / 2 - menu:getWidth() / 2)
        menu:setY(getPlayerScreenTop(playerIndex) + getPlayerScreenHeight(playerIndex) / 2 - menu:getHeight() / 2)
        menu:addToUIManager()

        if getJoypadData(playerIndex) then
            menu:setHideWhenButtonReleased(Joypad.DPadUp)
            setJoypadFocus(playerIndex, menu)
            playerObj:setJoypadIgnoreAimUntilCentered(true)
        end
    end
end

-------------------------------------------------
-- Compatibility: Alice's Weapon Sling Radial Menu (Workshop 3775549570)
--
-- That mod also listens for V (no car / no animal) and, when a weapon
-- is slung, does menu:clear() + its own slices in the SAME key press,
-- after ours. Its "already open?" guard is isReallyVisible(), which is
-- still false right after our addToUIManager (it's only queued), so it
-- wipes our Pick Lock slice. Wrap its show(): after it rebuilds, append
-- Pick Lock so both appear together. If it bails early (no slung
-- weapon) our menu is untouched and already has the slice.
-------------------------------------------------

local function menuHasPickLock(menu)
    for _, s in ipairs(menu.slices or {}) do
        if s.command and s.command[1] == onRadialPickLock then return true end
    end
    return false
end

local function installSlingCompat()
    local radial = AliceWeaponSling and AliceWeaponSling.Radial
    if not radial or not radial.show or radial.__lockpickWrapped then return end
    radial.__lockpickWrapped = true

    local originalShow = radial.show
    radial.show = function(playerObj)
        originalShow(playerObj)
        if not playerObj or playerObj:getVehicle() then return end

        local menu = getPlayerRadialMenu(playerObj:getPlayerNum())
        if not menu or menu:isEmpty() or menuHasPickLock(menu) then return end

        local door = findLockedDoorInReach(playerObj)
        if not door or not hasLockpickTools(playerObj) then return end

        dbg("Sling radial rebuilt the menu, appending Pick Lock")
        menu:addSlice("Pick Lock", getTexture("media/ui/vehicles/lockpick.png"), onRadialPickLock, playerObj, door)
    end
    dbg("Weapon sling radial compatibility installed")
end

Events.OnGameStart.Add(installRadialHook)
Events.OnGameStart.Add(installSlingCompat)

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

    local doors = getRelatedDoors(door)
    if not clusterLocked(doors) then return end
    if not getDoorInReach(player, doors) then return end
    if not hasLockpickTools(player) then return end

    context:addOption("Pick Lock", worldobjects, onPickLock, playerIndex)
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
