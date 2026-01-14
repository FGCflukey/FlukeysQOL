-- Corpse Cleanup - Final Context Menu (Build 42)

-- Local predicate: only accept non-broken items
local function predicateNotBroken(item)
    return item and (not item:isBroken())
end

-- Find any valid butchering tool using Build 42 tag system
local function getHarvestTool(playerObj)
    local inv = playerObj:getInventory()

    -- First try to find the BEST tool: SHARP_KNIFE + BUTCHER_ANIMAL
    local best = inv:getFirstTagEvalRecurse(ItemTag.SHARP_KNIFE, predicateNotBroken)
    if best and best:hasTag(ItemTag.BUTCHER_ANIMAL) then
        return best
    end

    -- Otherwise fall back to any BUTCHER_ANIMAL tool
    return inv:getFirstTagEvalRecurse(ItemTag.BUTCHER_ANIMAL, predicateNotBroken)
end


local function getSquareFromWorldObjects(worldobjects)
    for _, obj in ipairs(worldobjects) do
        if obj.getSquare then
            local sq = obj:getSquare()
            if sq then
                return sq
            end
        end
    end
    return nil
end

local function findCorpseOnSquare(square)
    if not square then return nil end

    local dead = square.getDeadBodys and square:getDeadBodys() or nil
    if dead and dead:size() > 0 then
        return dead:get(0)
    end

    return nil
end

local function findCorpseFromWorldObjects(worldobjects)
    local baseSquare = getSquareFromWorldObjects(worldobjects)
    if not baseSquare then return nil end

    local corpse = findCorpseOnSquare(baseSquare)
    if corpse then return corpse end

    local cell = getCell()
    local x, y, z = baseSquare:getX(), baseSquare:getY(), baseSquare:getZ()
    local offsets = {
        { -1, -1 }, { 0, -1 }, { 1, -1 },
        { -1,  0 },           { 1,  0 },
        { -1,  1 }, { 0,  1 }, { 1,  1 },
    }

    for _, off in ipairs(offsets) do
        local nx, ny = x + off[1], y + off[2]
        local nsq = cell:getGridSquare(nx, ny, z)
        corpse = findCorpseOnSquare(nsq)
        if corpse then
            return corpse
        end
    end

    return nil
end

local function onFillWorldObjectContextMenu(player, context, worldobjects, test)
    if test then return end

    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end

    -- 1) Find corpse
    local corpse = findCorpseFromWorldObjects(worldobjects)
    if not corpse then return end

    -- 2) Find a valid butchering tool using Build 42 tag system
    local tool = getHarvestTool(playerObj)
    if not tool then return end

    -- 3) Add the option
    context:addOption("Butcher Corpse", worldobjects, function()
        local tool = getHarvestTool(playerObj)
        if not tool then return end

        playerObj:setPrimaryHandItem(tool)
        playerObj:setSecondaryHandItem(nil)

        ISTimedActionQueue.add(CorpseCleanupAction:new(playerObj, corpse, tool, 100))
    end)

end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)