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

local function isATM(worldobjects)
    for _, obj in ipairs(worldobjects) do
        local spr = obj:getSprite()
        if spr then
            local name = spr:getName()
            if name and ATM_SPRITES[name] then
                return obj
            end
        end
    end
    return nil
end

-----------------------------------------------------
-- CREDIT CARD COLLECTION
-----------------------------------------------------
local function getCreditCards(inv)
    local cards = ArrayList.new()

    -- Normal credit cards
    local normal = inv:getAllType("CreditCard")
    if normal and not normal:isEmpty() then
        for i = 0, normal:size() - 1 do
            cards:add(normal:get(i))
        end
    end

    -- Stolen credit cards
    local stolen = inv:getAllType("CreditCard_Stolen")
    if stolen and not stolen:isEmpty() then
        for i = 0, stolen:size() - 1 do
            cards:add(stolen:get(i))
        end
    end

    return cards
end

-----------------------------------------------------
-- CONTEXT MENU
-----------------------------------------------------
local function OnFillWorldObjectContextMenu_ATM(playerNum, context, worldobjects, test)
    if test then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    local atm = isATM(worldobjects)
    if not atm then return end

    local inv = player:getInventory()
    local cards = getCreditCards(inv)

    -----------------------------------------------------
    -- NO CREDIT CARDS
    -----------------------------------------------------
    if cards:isEmpty() then
        context:addOption("Cash out Credit Card", worldobjects, function()
            player:Say("I need some credit cards to try")
        end)
        return
    end

    -----------------------------------------------------
    -- SINGLE CARD OPTION
    -----------------------------------------------------
    context:addOption("Cash out Credit Card", worldobjects, function()
        local card = cards:get(0)
        ISTimedActionQueue.add(CashOutATMAction:new(player, atm, card))
    end)

    -----------------------------------------------------
    -- MULTIPLE CARDS OPTION
    -----------------------------------------------------
    if cards:size() > 1 then
        context:addOption("Cash out ALL Credit Cards", worldobjects, function()
            for i = 0, cards:size() - 1 do
                local card = cards:get(i)
                ISTimedActionQueue.add(CashOutATMAction:new(player, atm, card))
            end
        end)
    end
end

Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu_ATM)