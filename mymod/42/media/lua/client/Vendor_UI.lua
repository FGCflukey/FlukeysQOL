-- Vendor_UI.lua
-- Emergency Vendor UI window (with category support + resizable window)

require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "Vendor_Items"

VendorUI = {}
VendorUI.instance = nil

-----------------------------------------------------
-- RECURSIVE MONEY HELPERS
-----------------------------------------------------

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

local function removeMoneyRecursive(container, amount)
    if amount <= 0 or not container then return amount end

    local bundles = container:getAllType("MoneyBundle")
    while amount >= 100 and bundles and not bundles:isEmpty() do
        container:Remove(bundles:get(0))
        amount = amount - 100
        bundles = container:getAllType("MoneyBundle")
    end

    local singles = container:getAllType("Money")
    while amount > 0 and singles and not singles:isEmpty() do
        container:Remove(singles:get(0))
        amount = amount - 1
        singles = container:getAllType("Money")
    end

    local items = container:getItems()
    if items then
        for i = 0, items:size() - 1 do
            if amount <= 0 then break end
            local item = items:get(i)
            if item and item:IsInventoryContainer() then
                amount = removeMoneyRecursive(item:getItemContainer(), amount)
            end
        end
    end

    return amount
end

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

    -- Enable resizing
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

    -- Hook resize callback
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
-- DRAW LIST ITEM (with category support)
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

    local leftover = removeMoneyRecursive(inv, price)
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