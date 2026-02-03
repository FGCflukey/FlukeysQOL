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

    local atm = isATM(worldobjects)
    if not atm then return end

    local cards = getAllCreditCards(player)

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