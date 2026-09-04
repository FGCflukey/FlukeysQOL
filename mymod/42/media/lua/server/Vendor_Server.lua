-- Vendor_Server.lua
-- Server-authoritative buy/sell handling for the Emergency Vendor
-- Location: lua\server\Vendor_Server.lua
--
-- Requires copies of Vendor_Items.lua and Vendor_SellItems.lua to also
-- exist in lua\server\ so the server has its own authoritative price/id
-- lookup and never trusts anything the client sends except the item id.

require "Vendor_Items"
require "Vendor_SellItems"

-- print("[VendorMod-DEBUG] Vendor_Server.lua loaded")

-----------------------------------------------------
-- MONEY CONSTANTS
-----------------------------------------------------
local MONEY_VALUES = {
    ["Money"] = 1,
    ["MoneyBundle"] = 100,
    ["Bag_FullMoneyBag"] = 500,
    ["Bag_FullBigMoneyBag"] = 1000,
}

local MONEY_BAG_TYPES = {
    ["Bag_FullMoneyBag"] = true,
    ["Bag_FullBigMoneyBag"] = true,
}

-----------------------------------------------------
-- RECURSIVE MONEY COUNT (server-authoritative)
-----------------------------------------------------
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
-- RECURSIVE MONEY REMOVAL (server-authoritative, synced)
-----------------------------------------------------
local function removeMoneyRecursive(container, amount, playerInv, allowBreak)
    if amount <= 0 or not container then return amount end
    allowBreak = allowBreak ~= false

    local function removeType(typeName, value)
        local items = container:getAllType(typeName)
        while amount >= value and items and not items:isEmpty() do
            local itm = items:get(0)
            container:Remove(itm)
            sendRemoveItemFromContainer(container, itm)
            amount = amount - value

            if MONEY_BAG_TYPES[typeName] then
                local newBag = playerInv:AddItem("Base.Bag_MoneyBag")
                sendAddItemToContainer(playerInv, newBag)
            end

            items = container:getAllType(typeName)
        end
    end

    removeType("Bag_FullBigMoneyBag", 1000)
    removeType("Bag_FullMoneyBag", 500)
    removeType("MoneyBundle", 100)
    removeType("Money", 1)

    local items = container:getItems()
    if items then
        for i = 0, items:size() - 1 do
            if amount <= 0 then break end
            local item = items:get(i)
            if item and item:IsInventoryContainer() then
                amount = removeMoneyRecursive(item:getItemContainer(), amount, playerInv, false)
            end
        end
    end

    if allowBreak and amount > 0 then
        local big = container:getAllType("Bag_FullBigMoneyBag")
        if big and not big:isEmpty() then
            local itm = big:get(0)
            container:Remove(itm)
            sendRemoveItemFromContainer(container, itm)
            local newBag = playerInv:AddItem("Base.Bag_MoneyBag")
            sendAddItemToContainer(playerInv, newBag)
            amount = amount - 1000
            return amount
        end

        local small = container:getAllType("Bag_FullMoneyBag")
        if small and not small:isEmpty() then
            local itm = small:get(0)
            container:Remove(itm)
            sendRemoveItemFromContainer(container, itm)
            local newBag = playerInv:AddItem("Base.Bag_MoneyBag")
            sendAddItemToContainer(playerInv, newBag)
            amount = amount - 500
            return amount
        end

        local bundle = container:getAllType("MoneyBundle")
        if bundle and not bundle:isEmpty() then
            local itm = bundle:get(0)
            container:Remove(itm)
            sendRemoveItemFromContainer(container, itm)
            amount = amount - 100
            return amount
        end
    end

    return amount
end

-----------------------------------------------------
-- GIVE CHANGE (server-authoritative, synced)
-----------------------------------------------------
local function giveChange(inv, change)
    if change <= 0 then return end

    local bundles = math.floor(change / 100)
    local singles = change % 100

    for i = 1, bundles do
        local itm = inv:AddItem("Base.MoneyBundle")
        sendAddItemToContainer(inv, itm)
    end
    for i = 1, singles do
        local itm = inv:AddItem("Base.Money")
        sendAddItemToContainer(inv, itm)
    end
end

-----------------------------------------------------
-- LOOKUP HELPERS (server is the source of truth for price/id)
-----------------------------------------------------
local function findVendorItem(id)
    for _, entry in ipairs(VendorItems) do
        if entry.id == id then return entry end
    end
    return nil
end

local function isValidItemType(id)
    local scriptItem = getScriptManager():getItem(id)
    return scriptItem ~= nil
end

local function findSellItem(id)
    for _, entry in ipairs(VendorSellItems) do
        if entry.id == id then return entry end
    end
    return nil
end

-----------------------------------------------------
-- CLIENT COMMAND HANDLER
-----------------------------------------------------
local function OnClientCommand_Vendor(module, command, player, args)
    -- print("[VendorMod-DEBUG] OnClientCommand received: module=" .. tostring(module) .. " command=" .. tostring(command))
    if module ~= "VendorMod" then return end
    if not player then
        -- print("[VendorMod-DEBUG] player arg is nil!")
        return
    end

    local username = player:getUsername()

    if command == "buyItem" then
        local entry = findVendorItem(args and args.itemId)
        if not entry then
            -- print("[VendorMod] REJECTED buy: unknown item id " .. tostring(args and args.itemId))
            return
        end

        if not isValidItemType(entry.id) then
            -- print("[VendorMod] REJECTED buy: item type does not exist in this game version: " .. tostring(entry.id))
            sendServerCommand(player, "VendorMod", "buyFail", { reason = "invalid_item" })
            return
        end

        local inv = player:getInventory()
        local price = entry.price or 0
        local totalMoney = countMoneyRecursive(inv)

        if totalMoney < price then
            -- print("[VendorMod] REJECTED buy: " .. username .. " has $" .. totalMoney .. " needs $" .. price)
            sendServerCommand(player, "VendorMod", "buyFail", { reason = "money" })
            return
        end

        local leftover = removeMoneyRecursive(inv, price, inv)

        if leftover < 0 then
            giveChange(inv, math.abs(leftover))
            leftover = 0
        end

        if leftover > 0 then
            -- print("[VendorMod] ERROR: money removal mismatch for " .. username .. " (leftover " .. leftover .. ")")
            sendServerCommand(player, "VendorMod", "buyFail", { reason = "error" })
            return
        end

        local newItem = inv:AddItem(entry.id)

        if not newItem then
            -- Shouldn't happen since isValidItemType passed, but refund
            -- defensively rather than leave the player charged with nothing.
            -- print("[VendorMod] ERROR: AddItem returned nil for " .. entry.id .. ", refunding " .. username)
            giveChange(inv, price)
            sendServerCommand(player, "VendorMod", "buyFail", { reason = "error" })
            return
        end

        sendAddItemToContainer(inv, newItem)

        noise("[VendorMod] " .. username .. " bought " .. entry.name .. " for $" .. price)
        sendServerCommand(player, "VendorMod", "buySuccess", { name = entry.name, price = price })

    elseif command == "sellItem" then
        local entry = findSellItem(args and args.itemId)
        if not entry then
            -- print("[VendorMod] REJECTED sell: unknown item id " .. tostring(args and args.itemId))
            return
        end

        local inv = player:getInventory()
        local count = inv:getCountType(entry.id)

        if count <= 0 then
            -- print("[VendorMod] REJECTED sell: " .. username .. " has none of " .. entry.id)
            sendServerCommand(player, "VendorMod", "sellFail", { reason = "none" })
            return
        end

        local item = inv:FindAndReturn(entry.id)
        inv:Remove(item)
        sendRemoveItemFromContainer(inv, item)

        giveChange(inv, entry.price or 0)

        noise("[VendorMod] " .. username .. " sold " .. entry.name .. " for $" .. (entry.price or 0))
        sendServerCommand(player, "VendorMod", "sellSuccess", { name = entry.name, price = entry.price })
    end
end

Events.OnClientCommand.Add(OnClientCommand_Vendor)