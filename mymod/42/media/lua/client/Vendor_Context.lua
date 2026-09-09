-- Vendor_Context.lua
require "Vendor_UI"

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

    context:addOption("Emergency Vendor", worldobjects, function()
        VendorUI.open(player)
    end)
end

Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu_Vendor)