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

-- Animal corpses (killed wildlife) use the exact same IsoDeadBody class
-- and the same per-square dead-body list as human/zombie corpses, so
-- square:getDeadBodys() returns both indiscriminately. This feature is
-- zombie-corpse cleanup specifically (it hardcodes Base.ZombieMeat as
-- the yield) -- running it on an animal would destroy the real,
-- butcherable animal corpse and hand out fake zombie meat instead of
-- the actual meat/hide/head/feathers vanilla's animal butchering gives.
-- isAnimal() is vanilla's own established way to tell them apart --
-- see ISWorldObjectContextMenu.lua's handleGrabCorpseSubmenu(), which
-- excludes animal corpses from its own corpse-grab menu the same way.
local function findCorpseOnSquare(square)
    if not square then return nil end
    local dead = square.getDeadBodys and square:getDeadBodys() or nil
    if not dead then return nil end

    for i = 0, dead:size() - 1 do
        local body = dead:get(i)
        if body and not (body.isAnimal and body:isAnimal()) then
            return body
        end
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
    local requiredLevel = 2 -- change to 2 if desired
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