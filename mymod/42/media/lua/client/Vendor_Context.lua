-- Vendor_Context.lua
require "Vendor_UI"

-----------------------------------------------------
-- UPDATED MONEY COUNTER (supports money bags)
-----------------------------------------------------
local MONEY_VALUES = {
    ["Money"] = 1,
    ["MoneyBundle"] = 100,
    ["Bag_FullMoneyBag"] = 500,
    ["Bag_FullBigMoneyBag"] = 1000,
}

local function countMoneyRecursive(container)
    if not container then return 0 end

    local total = 0

    for typeName, value in pairs(MONEY_VALUES) do
        local items = container:getAllType(typeName)
        if items then
            total = total + (items:size() * value)
        end
    end

    local items = container:getItems()
    if items then
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item and item:IsInventoryContainer() then
                total = total + countMoneyRecursive(item:getItemContainer())
            end
        end
    end

    return total
end

-----------------------------------------------------
-- VENDOR SPRITES
-----------------------------------------------------
local VENDOR_SPRITES = {
    ["location_shop_accessories_01_16"] = true,
    ["location_shop_accessories_01_17"] = true,
    ["location_shop_accessories_01_18"] = true,
    ["location_shop_accessories_01_19"] = true,
    ["location_shop_accessories_01_29"] = true,
    ["location_shop_accessories_01_31"] = true,
}

local function isVendorMachine(worldobjects)
    for _, obj in ipairs(worldobjects) do
        local spr = obj:getSprite()
        if spr then
            local name = spr:getName()
            if name and VENDOR_SPRITES[name] then
                return obj
            end
        end
    end
    return nil
end

-----------------------------------------------------
-- CONTEXT MENU
-----------------------------------------------------
local function OnFillWorldObjectContextMenu_Vendor(playerNum, context, worldobjects, test)
    if test then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    local vendor = isVendorMachine(worldobjects)
    if not vendor then return end

    local money = countMoneyRecursive(player:getInventory())
    if money <= 0 then return end

    context:addOption("Emergency Vendor", worldobjects, function()
        VendorUI.open(player)
    end)
end

Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu_Vendor)