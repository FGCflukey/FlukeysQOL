-- ATM_Context.lua
-- Adds ATM cash-out options when right-clicking ATM tiles

require "ATM_Action"

-----------------------------------------------------
-- ATM TILE DEFINITIONS
-----------------------------------------------------
local ATM_SPRITES = {
    ["location_business_bank_01_64"] = true,
    ["location_business_bank_01_65"] = true,
    ["location_business_bank_01_66"] = true,
    ["location_business_bank_01_67"] = true,
}

local DEBUG = true
local function dbg(msg) if DEBUG then print("[ATM] " .. tostring(msg)) end end

local MAX_ATM_DIST = 2

local function atmOnSquare(sq)
    if not sq then return nil end
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        local spr = obj and obj:getSprite()
        local name = spr and spr:getName()
        if name and ATM_SPRITES[name] then return obj end
    end
    return nil
end

-- Wall-mounted tiles live on the square on ONE side of the wall. For some
-- facings that's the square behind the wall, not the one the player
-- clicked, so the ATM never shows up in `worldobjects`. Check each clicked
-- square plus its 4 neighbours, then the player's own square + neighbours.
local function isATM(worldobjects, player)
    local seen = {}
    local squares = {}
    local function addSq(sq)
        if sq and not seen[sq] then
            seen[sq] = true
            squares[#squares + 1] = sq
        end
    end
    local function addWithNeighbours(sq)
        if not sq then return end
        addSq(sq)
        addSq(sq:getN()); addSq(sq:getS()); addSq(sq:getE()); addSq(sq:getW())
    end

    for _, obj in ipairs(worldobjects) do
        local spr = obj:getSprite()
        local name = spr and spr:getName()
        dbg("clicked object sprite: " .. tostring(name))
        if name and ATM_SPRITES[name] then return obj end
        addWithNeighbours(obj:getSquare())
    end
    addWithNeighbours(player:getSquare())

    local psq = player:getSquare()
    for _, sq in ipairs(squares) do
        local atm = atmOnSquare(sq)
        if atm and psq and psq:DistToProper(sq) <= MAX_ATM_DIST then
            dbg("found ATM on nearby square " .. sq:getX() .. "," .. sq:getY())
            return atm
        end
    end
    return nil
end

-----------------------------------------------------
-- RECURSIVE CREDIT CARD COLLECTION
-----------------------------------------------------
local function collectCardsRecursive(container, list)
    if not container then return end

    -- Normal cards
    local normal = container:getAllType("CreditCard")
    if normal and not normal:isEmpty() then
        for i = 0, normal:size() - 1 do
            list[#list + 1] = normal:get(i)
        end
    end

    -- Stolen cards
    local stolen = container:getAllType("CreditCard_Stolen")
    if stolen and not stolen:isEmpty() then
        for i = 0, stolen:size() - 1 do
            list[#list + 1] = stolen:get(i)
        end
    end

    -- Recurse into subcontainers
    local items = container:getItems()
    if items then
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item and item:IsInventoryContainer() then
                collectCardsRecursive(item:getItemContainer(), list)
            end
        end
    end
end

local function getAllCreditCards(player)
    local list = {}
    collectCardsRecursive(player:getInventory(), list)
    return list
end

-----------------------------------------------------
-- CONTEXT MENU
-----------------------------------------------------
local function OnFillWorldObjectContextMenu_ATM(playerNum, context, worldobjects, test)
    if test then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    local atm = isATM(worldobjects, player)
    if not atm then return end

    local cards = getAllCreditCards(player)
    dbg("cards found: " .. tostring(#cards))

    -----------------------------------------------------
    -- NO CARDS ANYWHERE
    -----------------------------------------------------
    if #cards == 0 then
        player:Say("I should try getting a credit card.")
        return
    end

    -----------------------------------------------------
    -- SINGLE CARD OPTION (use first found)
    -----------------------------------------------------
    local firstCard = cards[1]
    context:addOption("Cash out Credit Card", worldobjects, function()
        ISTimedActionQueue.add(CashOutATMAction:new(player, atm, firstCard))
    end)

    -----------------------------------------------------
    -- BULK OPTION (only if more than one)
    -----------------------------------------------------
    if #cards > 1 then
        context:addOption("Cash out ALL Credit Cards", worldobjects, function()
            for _, card in ipairs(cards) do
                ISTimedActionQueue.add(CashOutATMAction:new(player, atm, card))
            end
        end)
    end
end

Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu_ATM)