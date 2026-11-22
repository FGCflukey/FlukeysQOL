require "BoulderMining/BoulderMining_Defs"
require "TimedActions/BoulderMining_Action"

-- Right-click a big boulder -> "Break Boulder" (pickaxe or sledgehammer).

local dbg = BoulderMining.dbg

local function toolPredicate(item)
    return BoulderMining.isTool(item)
end

-- Clicked object first; big boulder sprites overlap neighbouring
-- squares visually, so also check the clicked squares' neighbours.
local function findBoulder(worldobjects)
    local squares, seen = {}, {}
    for _, obj in ipairs(worldobjects) do
        if BoulderMining.getDef(obj) then return obj end
        local sq = obj:getSquare()
        if sq and not seen[sq] then
            seen[sq] = true
            squares[#squares + 1] = sq
        end
    end
    for _, sq in ipairs(squares) do
        for _, nb in ipairs({ sq:getN(), sq:getS(), sq:getE(), sq:getW() }) do
            local b = BoulderMining.findOnSquare(nb)
            if b then return b end
        end
    end
    return nil
end

local function onBreakBoulder(worldobjects, playerObj, boulder)
    local sq = boulder:getSquare()
    if not sq then return end
    if luautils.walkAdj(playerObj, sq) then
        ISWorldObjectContextMenu.equip(playerObj, playerObj:getPrimaryHandItem(), toolPredicate, true, true)
        ISTimedActionQueue.add(BoulderMiningAction:new(playerObj, boulder))
    end
end

local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or playerObj:getVehicle() then return end

    local boulder = findBoulder(worldobjects)
    if not boulder then return end
    if test then return ISWorldObjectContextMenu.setTest() end

    dbg("boulder: " .. tostring(BoulderMining.getSpriteName(boulder)))

    local tool = playerObj:getInventory():getFirstEvalRecurse(toolPredicate)
    local option = context:addGetUpOption("Break Boulder", worldobjects, onBreakBoulder, playerObj, boulder)
    if tool then
        option.itemForTexture = tool
    else
        option.notAvailable = true
        local tip = ISToolTip:new()
        tip:initialise()
        tip:setVisible(false)
        tip.description = "Needs a pickaxe or sledgehammer."
        option.toolTip = tip
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
