-- Vendor_Context.lua
require "Vendor_UI"

local function countMoneyRecursive(container)
    if not container then return 0 end

    local total = 0

    local bundles = container:getAllType("MoneyBundle")
    if bundles then total = total + (bundles:size() * 100) end

    local singles = container:getAllType("Money")
    if singles then total = total + singles:size() end

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

local VENDOR_SPRITES = {
    ["location_shop_accessories_01_16"] = true,
    ["location_shop_accessories_01_17"] = true,
    ["location_shop_accessories_01_18"] = true,
    ["location_shop_accessories_01_19"] = true,
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