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

-- Height reserved above the list for the "Item" / "Price" column
-- header, and the right-edge padding the price column's text is
-- right-aligned against. Both the header (drawn in render(), in
-- window-relative coordinates) and each row (drawn in
-- drawListItem(), in list-relative coordinates) use PRICE_COL_PAD so
-- their columns line up -- the list sits inset 10px from each side
-- of the window, so window-relative and list-relative right edges
-- are already 10px apart and cancel out against that same inset.
VendorWindow.LIST_HEADER_H = 20
VendorWindow.PRICE_COL_PAD = 20

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
    -- TAB COLORS
    -----------------------------------------------------
    self.tabActiveBg = { r = 0.28, g = 0.35, b = 0.55, a = 1 }
    self.tabActiveBorder = { r = 0.55, g = 0.68, b = 1.0, a = 1 }
    self.tabInactiveBg = { r = 0.08, g = 0.08, b = 0.1, a = 1 }
    self.tabInactiveBorder = { r = 0.4, g = 0.4, b = 0.45, a = 1 }

    -----------------------------------------------------
    -- CREATE TAB BUTTONS
    -- Widths are sized to each tab's text; actual screen
    -- position is assigned by layoutTabs() so the strip
    -- can scroll when it doesn't fit the window.
    -----------------------------------------------------
    self.tabButtons = {}
    self.tabWidths = {}
    self.tabScrollIndex = 1

    for i, tab in ipairs(self.tabs) do
        local textW = getTextManager():MeasureStringX(UIFont.Small, tab)
        self.tabWidths[i] = math.max(60, textW + 20)

        local btn = ISButton:new(10, 30, self.tabWidths[i], 25, tab, self, VendorWindow.onTab)
        btn.internal = tab
        btn:initialise()
        btn:instantiate()
        self:styleTabButton(btn, tab == self.activeTab)
        self:addChild(btn)
        table.insert(self.tabButtons, btn)
    end

    self.tabScrollLeftBtn = ISButton:new(10, 30, 20, 25, "<", self, VendorWindow.onTabScrollLeft)
    self.tabScrollLeftBtn:initialise()
    self.tabScrollLeftBtn:instantiate()
    self.tabScrollLeftBtn:setVisible(false)
    self:addChild(self.tabScrollLeftBtn)

    self.tabScrollRightBtn = ISButton:new(10, 30, 20, 25, ">", self, VendorWindow.onTabScrollRight)
    self.tabScrollRightBtn:initialise()
    self.tabScrollRightBtn:instantiate()
    self.tabScrollRightBtn:setVisible(false)
    self:addChild(self.tabScrollRightBtn)

    -----------------------------------------------------
    -- LIST BOX (offset down to leave room for the column
    -- header drawn in render() below)
    -----------------------------------------------------
    self.list = ISScrollingListBox:new(10, 60 + VendorWindow.LIST_HEADER_H, self.width - 20, self.height - 130 - VendorWindow.LIST_HEADER_H)
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

    self:layoutTabs()
    self:populateList()
end

-----------------------------------------------------
-- FOOTER DRAWING
-----------------------------------------------------
function VendorWindow:render()
    ISCollapsableWindow.render(self)

    -----------------------------------------------------
    -- LIST COLUMN HEADER ("Item" / "Price")
    -- Drawn here (window-relative coords) rather than inside the
    -- list itself, so it stays put above the list while the list's
    -- own content scrolls underneath it.
    -----------------------------------------------------
    local headerY = 60

    self:drawText("Item", 20, headerY + 2, 0.7, 0.7, 0.7, 1, UIFont.Small)

    local priceLabel = "Price"
    local priceLabelW = getTextManager():MeasureStringX(UIFont.Small, priceLabel)
    local priceLabelX = self.width - 10 - VendorWindow.PRICE_COL_PAD - priceLabelW
    self:drawText(priceLabel, priceLabelX, headerY + 2, 0.7, 0.7, 0.7, 1, UIFont.Small)

    self:drawRect(10, headerY + VendorWindow.LIST_HEADER_H - 2, self.width - 20, 1, 0.5, 0.4, 0.4, 0.4)

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

    for _, btn in ipairs(self.tabButtons) do
        self:styleTabButton(btn, btn.internal == self.activeTab)
    end

    self:populateList()
end

-----------------------------------------------------
-- TAB STYLING
-----------------------------------------------------
function VendorWindow:styleTabButton(btn, active)
    local bg = active and self.tabActiveBg or self.tabInactiveBg
    local border = active and self.tabActiveBorder or self.tabInactiveBorder

    btn:setBackgroundRGBA(bg.r, bg.g, bg.b, bg.a)
    btn:setBorderRGBA(border.r, border.g, border.b, border.a)
    btn:setBackgroundColorMouseOverRGBA(
        math.min(1, bg.r + 0.12),
        math.min(1, bg.g + 0.12),
        math.min(1, bg.b + 0.12),
        1
    )
end

-----------------------------------------------------
-- TAB SCROLL HANDLERS
-----------------------------------------------------
function VendorWindow:onTabScrollLeft()
    self.tabScrollIndex = math.max(1, self.tabScrollIndex - 1)
    self:layoutTabs()
end

function VendorWindow:onTabScrollRight()
    self.tabScrollIndex = self.tabScrollIndex + 1
    self:layoutTabs()
end

-----------------------------------------------------
-- TAB LAYOUT
-- Tabs are sized to their text and placed left-to-right
-- in a virtual strip. When the strip is wider than the
-- window, arrow buttons page hidden tabs into view instead
-- of requiring the window to be stretched to see them.
-----------------------------------------------------
function VendorWindow:layoutTabs()
    local margin = 10
    local spacing = 4
    local arrowW = 20
    local tabY = 30
    local availX = margin
    local availW = self.width - margin * 2

    local totalW = -spacing
    for _, w in ipairs(self.tabWidths) do
        totalW = totalW + w + spacing
    end

    local needsScroll = totalW > availW
    local viewportX, viewportW

    if needsScroll then
        viewportX = availX + arrowW + spacing
        viewportW = availW - (arrowW + spacing) * 2

        self.tabScrollLeftBtn:setX(availX)
        self.tabScrollLeftBtn:setY(tabY)
        self.tabScrollLeftBtn:setVisible(true)

        self.tabScrollRightBtn:setX(availX + availW - arrowW)
        self.tabScrollRightBtn:setY(tabY)
        self.tabScrollRightBtn:setVisible(true)
    else
        viewportX = availX
        viewportW = availW
        self.tabScrollIndex = 1

        self.tabScrollLeftBtn:setVisible(false)
        self.tabScrollRightBtn:setVisible(false)
    end

    -- Clamp scrolling so the last tab never leaves a trailing
    -- gap at the right edge of the strip.
    local maxScrollIndex = 1
    if needsScroll then
        local acc = -spacing
        for i = #self.tabWidths, 1, -1 do
            acc = acc + self.tabWidths[i] + spacing
            if acc > viewportW then
                maxScrollIndex = i + 1
                break
            end
            maxScrollIndex = i
        end
    end
    self.tabScrollIndex = math.max(1, math.min(self.tabScrollIndex, maxScrollIndex))

    local x = viewportX
    for i, btn in ipairs(self.tabButtons) do
        if i < self.tabScrollIndex then
            btn:setVisible(false)
        else
            local w = self.tabWidths[i]
            if x + w <= viewportX + viewportW + 0.5 then
                btn:setX(x)
                btn:setY(tabY)
                btn:setVisible(true)
                x = x + w + spacing
            else
                btn:setVisible(false)
            end
        end
    end
end

-----------------------------------------------------
-- RESIZE HANDLER
-----------------------------------------------------
function VendorWindow:onResize()
    ISCollapsableWindow.onResize(self)

    self:layoutTabs()

    if self.list then
        self.list:setWidth(self.width - 20)
        self.list:setHeight(self.height - 130 - VendorWindow.LIST_HEADER_H)
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
            self.list:addItem(entry.name, { entry = entry, qty = count })
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
                self.list:addItem(entry.name, { entry = entry })
            end
        end
    end
end

-----------------------------------------------------
-- DRAW LIST ITEM
-----------------------------------------------------
function VendorWindow.drawListItem(self, y, item, alt)
    local data = item.item
    local entry = data.entry

    if self.selected == item.index then
        self:drawRect(0, y, self.width, self.itemheight, 0.3, 0.3, 0.6, 1)
    end

    self:drawText(entry.name, 10, y + 2, 1, 1, 1, 1, UIFont.Small)

    local priceText = "$" .. tostring(entry.price)
    if data.qty then
        priceText = priceText .. "  (x" .. data.qty .. ")"
    end
    local priceW = getTextManager():MeasureStringX(UIFont.Small, priceText)
    local priceX = self.width - VendorWindow.PRICE_COL_PAD - priceW
    self:drawText(priceText, priceX, y + 2, 1, 1, 1, 1, UIFont.Small)

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

    local entry = selected.item.entry
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