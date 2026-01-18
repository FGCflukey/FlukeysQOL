-- Corpse Cleanup - Final Context Menu (Build 42)

local function predicateNotBroken(item)
    return item and (not item:isBroken())
end

local function getHarvestTool(playerObj)
    local inv = playerObj:getInventory()

    local best = inv:getFirstTagEvalRecurse(ItemTag.SHARP_KNIFE, predicateNotBroken)
    if best and best:hasTag(ItemTag.BUTCHER_ANIMAL) then
        return best
    end

    return inv:getFirstTagEvalRecurse(ItemTag.BUTCHER_ANIMAL, predicateNotBroken)
end

local function getSquareFromWorldObjects(worldobjects)
    for _, obj in ipairs(worldobjects) do
        if obj.getSquare then
            local sq = obj:getSquare()
            if sq then return sq end
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
        local nsq = cell:getGridSquare(x + off[1], y + off[2], z)
        corpse = findCorpseOnSquare(nsq)
        if corpse then return corpse end
    end

    return nil
end

local function onFillWorldObjectContextMenu(player, context, worldobjects, test)
    if test then return end

    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end

    local corpse = findCorpseFromWorldObjects(worldobjects)
    if not corpse then return end

    local tool = getHarvestTool(playerObj)
    if not tool then return end

    -- ⭐ Correct Butchering skill requirement
    local requiredLevel = 1 -- change to 2 if desired
    local butcherLevel = playerObj:getPerkLevel(Perks.Butchering)

    if butcherLevel < requiredLevel then
        local opt = context:addOption("Butcher Corpse (Requires Butchering " .. requiredLevel .. ")", nil)
        opt.notAvailable = true
        return
    end

    context:addOption("Butcher Corpse", worldobjects, function()
        local tool = getHarvestTool(playerObj)
        if not tool then return end

        local originalPrimary = playerObj:getPrimaryHandItem()
        local originalSecondary = playerObj:getSecondaryHandItem()

        playerObj:setPrimaryHandItem(tool)
        playerObj:setSecondaryHandItem(nil)

        ISTimedActionQueue.add(
            CorpseCleanupAction:new(playerObj, corpse, tool, 100, originalPrimary, originalSecondary)
        )
    end)
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)