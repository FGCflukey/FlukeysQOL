-- Vendor_UI.lua
-- Emergency Vendor UI window (with category support + resizable window)

require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "Vendor_Items"

VendorUI = {}
VendorUI.instance = nil

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
-- RECURSIVE MONEY HELPERS
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
-- REMOVE MONEY (supports breaking bags)
-----------------------------------------------------

local function removeMoneyRecursive(container, amount, playerInv, allowBreak)
    if amount <= 0 or not container then return amount end
    allowBreak = allowBreak ~= false  -- default true

    -- Helper to remove items of a type
    local function removeType(typeName, value)
        local items = container:getAllType(typeName)
        while amount >= value and items and not items:isEmpty() do
            local itm = items:get(0)
            container:Remove(itm)
            amount = amount - value

            if MONEY_BAG_TYPES[typeName] then
                playerInv:AddItem("Base.Bag_MoneyBag")
            end

            items = container:getAllType(typeName)
        end
    end

    -- Remove in descending value order
    removeType("Bag_FullBigMoneyBag", 1000)
    removeType("Bag_FullMoneyBag", 500)
    removeType("MoneyBundle", 100)
    removeType("Money", 1)

    -- Recurse into subcontainers (but do NOT allow breaking bags inside them)
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

    ---------------------------------------------------------
    -- NEW: Only top-level call may break a bag
    ---------------------------------------------------------
    if allowBreak and amount > 0 then
        -- Try big bag first
        local big = container:getAllType("Bag_FullBigMoneyBag")
        if big and not big:isEmpty() then
            container:Remove(big:get(0))
            playerInv:AddItem("Base.Bag_MoneyBag")
            amount = amount - 1000
            return amount
        end

        -- Try small bag
        local small = container:getAllType("Bag_FullMoneyBag")
        if small and not small:isEmpty() then
            container:Remove(small:get(0))
            playerInv:AddItem("Base.Bag_MoneyBag")
            amount = amount - 500
            return amount
        end
    end

    return amount
end

-----------------------------------------------------
-- GIVE CHANGE
-----------------------------------------------------

local function giveChange(inv, change)
    if change <= 0 then return end

    local bundles = math.floor(change / 100)
    local singles = change % 100

    for i = 1, bundles do inv:AddItem("Base.MoneyBundle") end
    for i = 1, singles do inv:AddItem("Base.Money") end
end

-----------------------------------------------------
-- WINDOW CLASS
-----------------------------------------------------
VendorWindow = ISCollapsableWindow:derive("VendorWindow")

function VendorWindow:initialise()
    ISCollapsableWindow.initialise(self)

    self.resizable = true
    self.resizeWidget = true
    self.minimumWidth = 250
    self.minimumHeight = 200

    self.list = ISScrollingListBox:new(10, 30, self.width - 20, self.height - 80)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = 22
    self.list.font = UIFont.Small
    self.list.drawBorder = true
    self.list.doDrawItem = VendorWindow.drawListItem
    self:addChild(self.list)

    self.buyButton = ISButton:new(10, self.height - 40, 80, 25, "Buy", self, VendorWindow.onBuy)
    self.buyButton:initialise()
    self.buyButton:instantiate()
    self:addChild(self.buyButton)

    self.closeButton = ISButton:new(self.width - 90, self.height - 40, 80, 25, "Close", self, VendorWindow.onClose)
    self.closeButton:initialise()
    self.closeButton:instantiate()
    self:addChild(self.closeButton)

    self.onResize = VendorWindow.onResize

    self:populateList()
end

function VendorWindow:onResize()
    ISCollapsableWindow.onResize(self)

    if self.list then
        self.list:setWidth(self.width - 20)
        self.list:setHeight(self.height - 80)
    end

    if self.buyButton then
        self.buyButton:setY(self.height - 40)
    end

    if self.closeButton then
        self.closeButton:setX(self.width - 90)
        self.closeButton:setY(self.height - 40)
    end
end

function VendorWindow:populateList()
    self.list:clear()

    for _, entry in ipairs(VendorItems) do
        if entry.category then
            self.list:addItem("[ " .. entry.name .. " ]", { category = true })
        else
            local text = string.format("%s  -  $%d", entry.name, entry.price)
            self.list:addItem(text, entry)
        end
    end

    if #self.list.items > 0 then
        self.list.selected = 1
    end
end

-----------------------------------------------------
-- DRAW LIST ITEM
-----------------------------------------------------
function VendorWindow.drawListItem(self, y, item, alt)
    local data = item.item

    if data.category then
        self:drawRect(0, y, self.width, self.itemheight, 0.4, 0.1, 0.1, 0.1)
        self:drawText(item.text, 10, y + 2, 0.9, 0.9, 0.4, 1, UIFont.Medium)
        return y + self.itemheight
    end

    if self.selected == item.index then
        self:drawRect(0, y, self.width, self.itemheight, 0.3, 0.3, 0.6, 1)
    end

    self:drawText(item.text, 10, y + 2, 1, 1, 1, 1, UIFont.Small)
    return y + self.itemheight
end

-----------------------------------------------------
-- BUY BUTTON
-----------------------------------------------------
function VendorWindow:onBuy()
    local player = self.player
    if not player then return end

    local inv = player:getInventory()
    local selectedIndex = self.list.selected
    local selected = selectedIndex and self.list.items[selectedIndex]

    if not selected then
        player:Say("I should pick something first.")
        return
    end

    local entry = selected.item

    if entry.category then
        player:Say("That's a category, not an item.")
        return
    end

    local price = entry.price or 0
    local totalMoney = countMoneyRecursive(inv)

    if totalMoney < price then
        player:Say("I don't have enough money.")
        return
    end

    local leftover = removeMoneyRecursive(inv, price, inv)

    -- leftover < 0 means we broke a bag and need to give change
    if leftover < 0 then
        giveChange(inv, math.abs(leftover))
        leftover = 0
    end

    if leftover > 0 then
        player:Say("Error removing money.")
        return
    end

    inv:AddItem(entry.id)
    player:Say("Bought " .. entry.name .. " for $" .. price)
end

-----------------------------------------------------
-- CLOSE WINDOW
-----------------------------------------------------
function VendorWindow:onClose()
    self:close()
end

function VendorWindow:close()
    VendorUI.instance = nil
    self:setVisible(false)
    self:removeFromUIManager()
end

function VendorWindow:new(x, y, width, height, player)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.player = player
    o.title = "Emergency Vendor"
    o.resizable = true
    o.resizeWidget = true
    o.minimumWidth = 250
    o.minimumHeight = 200
    o.moveWithMouse = true
    return o
end

function VendorUI.open(player)
    if VendorUI.instance then
        VendorUI.instance:close()
        VendorUI.instance = nil
    end

    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    local w, h = 350, 260
    local x = (sw - w) / 2
    local y = (sh - h) / 2

    local window = VendorWindow:new(x, y, w, h, player)
    window:initialise()
    window:addToUIManager()
    VendorUI.instance = window
end