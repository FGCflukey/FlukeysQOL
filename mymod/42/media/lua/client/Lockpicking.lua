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
-- Collect all door objects in a 3x3 cluster
-------------------------------------------------

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

-------------------------------------------------
-- Identify the "master" door tile
-------------------------------------------------

local function findMasterDoor(doors)
    if #doors == 0 then return nil end

    local master = doors[1]
    local bestScore = 0

    for _, door in ipairs(doors) do
        local score = 0

        if door.getMaxHealth and door:getMaxHealth() then
            score = score + door:getMaxHealth()
        end

        if door.getKeyId and door:getKeyId() and door:getKeyId() ~= -1 then
            score = score + 5000
        end

        if door.isLockedByKey and door:isLockedByKey() then
            score = score + 3000
        end

        if score > bestScore then
            bestScore = score
            master = door
        end
    end

    return master
end

-------------------------------------------------
-- Safe lock check for cluster
-------------------------------------------------

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

local function removeOnePaperclip(player)
    local inv = player:getInventory()
    local pc = findItemRecursive(inv, "Paperclip")
    if pc then
        local container = pc:getContainer()
        if container then
            container:Remove(pc)
        end
    end
end

-------------------------------------------------
-- Unlock all lock flags on a door
-------------------------------------------------

local function unlockDoorObject(door)
    if not door then return end

    if door.setLocked then door:setLocked(false) end
    if door.setIsLocked then door:setIsLocked(false) end
    if door.setLockedByKey then door:setLockedByKey(false) end
    if door.setLockedByPadlock then door:setLockedByPadlock(false) end
    if door.setKeyId then door:setKeyId(-1) end
end

-------------------------------------------------
-- Pick lock action (doors only, timed)
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

    local doors = getDoorCluster(square)
    if #doors == 0 then
        player:Say("There's nothing to pick here.")
        return
    end

    if not hasLockpickTools(player) then
        player:Say("I need a screwdriver or multitool, and a paperclip.")
        return
    end

    local door = doors[1]

    ISTimedActionQueue.add(
        LockpickTimedAction:new(
            player,
            door,
            ZombRand(6, 11) * 30,
            function(player, door)
                for _, d in ipairs(doors) do
                    unlockDoorObject(d)
                end
            end,
            function(player, door)
                removeOnePaperclip(player)
            end
        )
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

    local doors = getDoorCluster(square)
    if #doors == 0 then return end
    if not clusterLocked(doors) then return end
    if not hasLockpickTools(player) then return end

    context:addOption("Pick Lock", worldobjects, onPickLock, playerIndex)
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
