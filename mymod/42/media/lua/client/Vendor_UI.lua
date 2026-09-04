-- Vendor_UI.lua
-- Emergency Vendor UI (Tabbed Buy/Sell System)

require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "Vendor_Items"
require "Vendor_SellItems"

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
-- NOTE: money removal / change-giving now happens
-- server-authoritatively in lua\server\Vendor_Server.lua.
-- The client only does a quick pre-check with
-- countMoneyRecursive above; it never mutates the
-- container directly.
-----------------------------------------------------

-----------------------------------------------------
-- WINDOW CLASS
-----------------------------------------------------
VendorWindow = ISCollapsableWindow:derive("VendorWindow")

function VendorWindow:initialise()
    ISCollapsableWindow.initialise(self)

    self.resizable = true
    self.resizeWidget = true
    self.minimumWidth = 300
    self.minimumHeight = 260

    -----------------------------------------------------
    -- BUILD TAB LIST FROM CATEGORIES
    -----------------------------------------------------
    self.tabs = { "All" }

    for _, entry in ipairs(VendorItems) do
        if entry.category then
            table.insert(self.tabs, entry.category)
        end
    end

    table.insert(self.tabs, "Sell")

    self.activeTab = "All"

    -----------------------------------------------------
    -- CREATE TAB BUTTONS
    -----------------------------------------------------
    self.tabButtons = {}
    local x = 10
    for _, tab in ipairs(self.tabs) do
        local btn = ISButton:new(x, 30, 80, 25, tab, self, VendorWindow.onTab)
        btn.internal = tab
        btn:initialise()
        btn:instantiate()
        self:addChild(btn)
        table.insert(self.tabButtons, btn)
        x = x + 85
    end

    -----------------------------------------------------
    -- LIST BOX
    -----------------------------------------------------
    self.list = ISScrollingListBox:new(10, 60, self.width - 20, self.height - 130)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = 22
    self.list.font = UIFont.Small
    self.list.drawBorder = true
    self.list.doDrawItem = VendorWindow.drawListItem
    self:addChild(self.list)

    -----------------------------------------------------
    -- BUY / SELL BUTTON
    -----------------------------------------------------
    self.actionButton = ISButton:new(10, self.height - 40, 80, 25, "Buy", self, VendorWindow.onAction)
    self.actionButton:initialise()
    self.actionButton:instantiate()
    self:addChild(self.actionButton)

    -----------------------------------------------------
    -- CLOSE BUTTON
    -----------------------------------------------------
    self.closeButton = ISButton:new(self.width - 90, self.height - 40, 80, 25, "Close", self, VendorWindow.onClose)
    self.closeButton:initialise()
    self.closeButton:instantiate()
    self:addChild(self.closeButton)

    -----------------------------------------------------
    -- FOOTER TEXT
    -----------------------------------------------------
    self.footerText = "All Sales Are Final."
    self.footerY = self.height - 60

    self.onResize = VendorWindow.onResize

    self:populateList()
end

-----------------------------------------------------
-- FOOTER DRAWING
-----------------------------------------------------
function VendorWindow:render()
    ISCollapsableWindow.render(self)

    -- Center the footer text
    local textWidth = getTextManager():MeasureStringX(UIFont.Small, self.footerText)
    local centerX = (self.width - textWidth) / 2

    self:drawText(
        self.footerText,
        centerX,
        self.footerY,
        0.9, 0.9, 0.9, 1,
        UIFont.Small
    )
end

-----------------------------------------------------
-- TAB CLICK HANDLER
-----------------------------------------------------
function VendorWindow:onTab(button)
    self.activeTab = button.internal
    self.actionButton:setTitle(self.activeTab == "Sell" and "Sell" or "Buy")
    self:populateList()
end

-----------------------------------------------------
-- RESIZE HANDLER
-----------------------------------------------------
function VendorWindow:onResize()
    ISCollapsableWindow.onResize(self)

    if self.list then
        self.list:setWidth(self.width - 20)
        self.list:setHeight(self.height - 130)
    end

    if self.actionButton then
        self.actionButton:setY(self.height - 40)
    end

    if self.closeButton then
        self.closeButton:setX(self.width - 90)
        self.closeButton:setY(self.height - 40)
    end

    -- Keep footer pinned above buttons
    self.footerY = self.height - 60
end

-----------------------------------------------------
-- POPULATE LIST BASED ON ACTIVE TAB
-----------------------------------------------------
function VendorWindow:populateList()
    self.list:clear()

    local inv = self.player:getInventory()

    -- SELL TAB
    if self.activeTab == "Sell" then
        for _, entry in ipairs(VendorSellItems) do
            local count = inv:getCountType(entry.id)
            local text = string.format("%s  -  $%d (x%d)", entry.name, entry.price, count)
            self.list:addItem(text, entry)
        end
        return
    end

    -- BUY TABS
    local currentCategory = nil

    for _, entry in ipairs(VendorItems) do
        if entry.category then
            currentCategory = entry.category
        else
            entry._category = currentCategory

            if self.activeTab == "All" or entry._category == self.activeTab then
                local text = string.format("%s  -  $%d", entry.name, entry.price)
                self.list:addItem(text, entry)
            end
        end
    end
end

-----------------------------------------------------
-- DRAW LIST ITEM
-----------------------------------------------------
function VendorWindow.drawListItem(self, y, item, alt)
    local data = item.item

    if self.selected == item.index then
        self:drawRect(0, y, self.width, self.itemheight, 0.3, 0.3, 0.6, 1)
    end

    self:drawText(item.text, 10, y + 2, 1, 1, 1, 1, UIFont.Small)
    return y + self.itemheight
end

-----------------------------------------------------
-- ACTION BUTTON (BUY OR SELL)
-----------------------------------------------------
function VendorWindow:onAction()
    -- print("[VendorMod-DEBUG] onAction called, activeTab=" .. tostring(self.activeTab))

    local player = self.player
    local inv = player:getInventory()

    local selectedIndex = self.list.selected
    local selected = selectedIndex and self.list.items[selectedIndex]
    if not selected then
        -- print("[VendorMod-DEBUG] no selection (selectedIndex=" .. tostring(selectedIndex) .. ")")
        player:Say("I should pick something first.")
        return
    end

    local entry = selected.item
    -- print("[VendorMod-DEBUG] selected entry.id=" .. tostring(entry and entry.id))

    if self.activeTab == "Sell" then
        return self:handleSell(entry, inv, player)
    else
        return self:handleBuy(entry, inv, player)
    end
end

-----------------------------------------------------
-- BUY LOGIC
-- Client only does a quick affordability pre-check for
-- instant feedback. The actual money removal + item grant
-- happens server-side in Vendor_Server.lua. Sound/message/
-- list refresh fire from the buySuccess/buyFail response
-- (see OnServerCommand_Vendor below).
-----------------------------------------------------
function VendorWindow:handleBuy(entry, inv, player)
    -- print("[VendorMod-DEBUG] handleBuy called for entry.id=" .. tostring(entry and entry.id))

    local price = entry.price or 0
    local totalMoney = countMoneyRecursive(inv)
    -- print("[VendorMod-DEBUG] price=" .. tostring(price) .. " totalMoney=" .. tostring(totalMoney))

    if totalMoney < price then
        player:Say("I don't have enough money.")
        return
    end

    -- print("[VendorMod-DEBUG] sending buyItem command to server")
    sendClientCommand(player, "VendorMod", "buyItem", { itemId = entry.id })
    -- print("[VendorMod-DEBUG] sendClientCommand call returned")
end

-----------------------------------------------------
-- SELL LOGIC
-- Same story: pre-check only, server does the real work.
-----------------------------------------------------
function VendorWindow:handleSell(entry, inv, player)
    local count = inv:getCountType(entry.id)
    if count <= 0 then
        player:Say("I don't have any " .. entry.name .. " to sell.")
        return
    end

    sendClientCommand(player, "VendorMod", "sellItem", { itemId = entry.id })
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
    o.minimumWidth = 600
    o.minimumHeight = 450
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
    local w, h = 700, 550
    local x = (sw - w) / 2
    local y = (sh - h) / 2

    local window = VendorWindow:new(x, y, w, h, player)
    window:initialise()
    window:addToUIManager()
    VendorUI.instance = window
end

-----------------------------------------------------
-- SERVER RESPONSE HANDLER (buy/sell confirmation)
-----------------------------------------------------
local function OnServerCommand_Vendor(module, command, args)
    if module ~= "VendorMod" then return end

    local player = getPlayer()
    if not player then return end

    if command == "buySuccess" then
        getSoundManager():PlayWorldSound("vendingdispense", player:getSquare(), 0, 10, 1.0, false)
        player:Say("Bought " .. args.name .. " for $" .. args.price)
        if VendorUI.instance then VendorUI.instance:populateList() end

    elseif command == "buyFail" then
        if args.reason == "money" then
            player:Say("I don't have enough money.")
        elseif args.reason == "invalid_item" then
            player:Say("That item isn't available right now.")
        else
            player:Say("Something went wrong with that purchase.")
        end

    elseif command == "sellSuccess" then
        player:Say("Sold " .. args.name .. " for $" .. args.price)
        if VendorUI.instance then VendorUI.instance:populateList() end

    elseif command == "sellFail" then
        player:Say("I don't have any of that to sell.")
    end
end

Events.OnServerCommand.Add(OnServerCommand_Vendor)