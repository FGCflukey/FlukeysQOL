-- Vendor_Server.lua
-- Server-authoritative buy/sell handling for the Emergency Vendor
-- Location: lua\server\Vendor_Server.lua
--
-- Requires copies of Vendor_Items.lua and Vendor_SellItems.lua to also
-- exist in lua\server\ so the server has its own authoritative price/id
-- lookup and never trusts anything the client sends except the item id.

require "Vendor_Items"
require "Vendor_SellItems"

local function noise(msg)
    print("[VendorMod] " .. tostring(msg))
end

-- print("[VendorMod-DEBUG] Vendor_Server.lua loaded")

-----------------------------------------------------
-- MONEY CONSTANTS
-- Only real cash counts. A Money Bag is just a container: whatever
-- bundles/bills are inside it are found by the recursive search below.
-- (The old fixed-value "full" money bags were removed -- they were
-- empty containers worth $500/$1000 by type alone.)
-----------------------------------------------------
local MONEY_VALUES = {
    ["Money"] = 1,
    ["MoneyBundle"] = 100,
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
-- Collects every bundle/bill anywhere in the inventory (bags inside
-- bags included), then pays greedily: bundles first, then bills, then
-- breaks one more bundle if bills alone can't cover the remainder.
-- Breaking used to only look at the top-level inventory, so paying $50
-- with all your bundles inside a bag failed with "something went wrong".
--
-- Returns the leftover amount: 0 = exact, negative = change owed,
-- positive = couldn't cover (caller refunds).
-----------------------------------------------------
local function collectMoney(container, bundles, bills)
    if not container then return end
    local items = container:getItems()
    if not items then return end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            local t = item:getType()
            if t == "MoneyBundle" then
                table.insert(bundles, { item = item, container = container })
            elseif t == "Money" then
                table.insert(bills, { item = item, container = container })
            elseif item:IsInventoryContainer() then
                collectMoney(item:getItemContainer(), bundles, bills)
            end
        end
    end
end

local function takeMoneyItem(entry)
    entry.container:Remove(entry.item)
    sendRemoveItemFromContainer(entry.container, entry.item)
end

local function removeMoneyRecursive(inv, amount)
    if amount <= 0 or not inv then return amount end

    -- Collect first, remove after: never mutate a container mid-iteration
    local bundles, bills = {}, {}
    collectMoney(inv, bundles, bills)

    local b = 1
    while amount >= 100 and b <= #bundles do
        takeMoneyItem(bundles[b]); b = b + 1
        amount = amount - 100
    end

    local s = 1
    while amount >= 1 and s <= #bills do
        takeMoneyItem(bills[s]); s = s + 1
        amount = amount - 1
    end

    -- Bills ran out: break one more bundle, the difference becomes change
    if amount > 0 and b <= #bundles then
        takeMoneyItem(bundles[b])
        amount = amount - 100
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
            noise("REJECTED buy: unknown item id " .. tostring(args and args.itemId))
            return
        end

        if not isValidItemType(entry.id) then
            noise("REJECTED buy: item type does not exist in this game version: " .. tostring(entry.id))
            sendServerCommand(player, "VendorMod", "buyFail", { reason = "invalid_item" })
            return
        end

        local inv = player:getInventory()
        local price = entry.price or 0
        local totalMoney = countMoneyRecursive(inv)
        noise(username .. " attempting to buy " .. entry.name .. " (price=$" .. price .. ", has $" .. totalMoney .. ")")

        if totalMoney < price then
            noise("REJECTED buy: " .. username .. " has $" .. totalMoney .. " needs $" .. price)
            sendServerCommand(player, "VendorMod", "buyFail", { reason = "money" })
            return
        end

        local leftover = removeMoneyRecursive(inv, price)
        noise("removeMoneyRecursive leftover=" .. tostring(leftover) .. " (price was $" .. price .. ")")

        -- Track exactly how much has actually been taken from the player,
        -- net of any change already given below -- so any later refund is
        -- always for the real amount removed, never a blind guess of `price`.
        local amountTaken = price

        if leftover < 0 then
            local change = math.abs(leftover)
            giveChange(inv, change)
            amountTaken = amountTaken - change
            leftover = 0
        end

        if leftover > 0 then
            -- removeMoneyRecursive couldn't find the full price -- refund
            -- whatever it DID manage to remove (price - leftover) instead of
            -- leaving the player short with nothing to show for it. This was
            -- a real bug: this branch used to take the player's money with
            -- zero refund whenever the recursive removal came up short.
            local actuallyRemoved = price - leftover
            noise("ERROR: money removal mismatch for " .. username .. " (short by $" .. leftover .. ", refunding $" .. actuallyRemoved .. ")")
            if actuallyRemoved > 0 then
                giveChange(inv, actuallyRemoved)
            end
            sendServerCommand(player, "VendorMod", "buyFail", { reason = "error" })
            return
        end

        local newItem = inv:AddItem(entry.id)

        if not newItem then
            -- Shouldn't happen since isValidItemType passed, but refund
            -- defensively rather than leave the player charged with nothing.
            -- Refund amountTaken (not price): if change was already given
            -- above for overpayment, refunding the full price again here
            -- would hand the player back more than they actually lost.
            noise("ERROR: AddItem returned nil for " .. entry.id .. ", refunding " .. username .. " $" .. amountTaken)
            if amountTaken > 0 then
                giveChange(inv, amountTaken)
            end
            sendServerCommand(player, "VendorMod", "buyFail", { reason = "error" })
            return
        end

        sendAddItemToContainer(inv, newItem)

        noise(username .. " bought " .. entry.name .. " for $" .. price)
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

        noise(username .. " sold " .. entry.name .. " for $" .. (entry.price or 0))
        sendServerCommand(player, "VendorMod", "sellSuccess", { name = entry.name, price = entry.price })
    end
end

Events.OnClientCommand.Add(OnClientCommand_Vendor)