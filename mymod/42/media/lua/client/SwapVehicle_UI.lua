--========================================================
-- SwapVehicle UI (Vertical Layout + Full Script Names)
--========================================================

SwapVehicle_UI = ISCollapsableWindow:derive("SwapVehicle_UI")
SwapVehicle_UI.instance = nil

local UI_WIDTH  = 750
local UI_HEIGHT = 520

----------------------------------------------------------
-- Entry Point (called by context menu)
----------------------------------------------------------
function SwapVehicle_UI.Open(player, vehicleObj, groupID, variants)
    if SwapVehicle_UI.instance then
        SwapVehicle_UI.instance:close()
    end

    local x = (getCore():getScreenWidth()  - UI_WIDTH)  / 2
    local y = (getCore():getScreenHeight() - UI_HEIGHT) / 2

    local ui = SwapVehicle_UI:new(x, y, UI_WIDTH, UI_HEIGHT, player, vehicleObj, groupID, variants)
    ui:initialise()
    ui:addToUIManager()

    SwapVehicle_UI.instance = ui
end

----------------------------------------------------------
-- Constructor
----------------------------------------------------------
function SwapVehicle_UI:new(x, y, w, h, player, vehicleObj, groupID, variants)
    local o = ISCollapsableWindow:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self

    o.player     = player
    o.vehicleObj = vehicleObj
    o.groupID    = groupID
    o.variants   = variants or {}

    o.resizable  = false
    o.title      = "Swap Vehicle Vinyl"

    return o
end

----------------------------------------------------------
-- Create Children
----------------------------------------------------------
function SwapVehicle_UI:createChildren()
    ISCollapsableWindow.createChildren(self)

    local th = self:titleBarHeight()
    local pad = 10

    ------------------------------------------------------
    -- Variant List (full width, top half)
    ------------------------------------------------------
    local listH = (self.height - th - pad*3) * 0.45

    self.list = ISScrollingListBox:new(
        pad, th + pad,
        self.width - pad*2 - 20,
        listH
    )

    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = getTextManager():getFontHeight(UIFont.NewSmall) + 10
    self.list.font = UIFont.NewSmall
    self.list.drawBorder = true

    -- FIX: Restore built-in selection logic
    self.list.onMouseDown = function(list, x, y)
        ISScrollingListBox.onMouseDown(list, x, y)
        self:onSelectVariant()
    end

    self:addChild(self.list)

    ------------------------------------------------------
    -- Populate list with FULL script names
    ------------------------------------------------------
    for _, scriptName in ipairs(self.variants) do
        local full = scriptName
        if not full:find("%.") then
            full = "Base." .. full
        end
        local item = self.list:addItem(full, full)
        item.scriptName = full
    end

    ------------------------------------------------------
    -- 3D Preview Panel (full width, below list)
    ------------------------------------------------------
    local previewY = self.list:getBottom() + pad
    local previewH = (self.height - th - pad*3) * 0.45

    self.preview = ISUI3DScene:new(
        pad, previewY,
        self.width - pad*2,
        previewH
    )
    self.preview:initialise()
    self.preview:instantiate()
    self.preview:setView("Right")
    self.preview.javaObject:fromLua1("setZoom", 4)
    self.preview.javaObject:fromLua1("setDrawGrid", false)
    self.preview.javaObject:fromLua1("createVehicle", "swapPreview")

    self:addChild(self.preview)

    ------------------------------------------------------
    -- Swap Button (bottom right)
    ------------------------------------------------------
    self.swapBtn = ISButton:new(
        self.width - 140, self.height - 35,
        120, 25,
        "Swap Vinyl",
        self,
        SwapVehicle_UI.onSwapClick
    )
    self.swapBtn:initialise()
    self.swapBtn:instantiate()
    self:addChild(self.swapBtn)

    ------------------------------------------------------
    -- Auto-select first item
    ------------------------------------------------------
    if #self.variants > 0 then
        self.list.selected = 1
        self:onSelectVariant()
    end
end

----------------------------------------------------------
-- Update Preview When Selecting a Variant
----------------------------------------------------------
function SwapVehicle_UI:onSelectVariant()
    local item = self.list.items[self.list.selected]
    if not item then return end

    local scriptName = item.scriptName
    if not scriptName then return end

    self.preview.javaObject:fromLua2("setVehicleScript", "swapPreview", scriptName)
end

----------------------------------------------------------
-- Swap Button Click
----------------------------------------------------------
function SwapVehicle_UI:onSwapClick()
    local item = self.list.items[self.list.selected]
    if not item then return end

    local scriptName = item.scriptName

    sendClientCommand(
        self.player,
        "SwapVehicle",
        "Swap",
        {
            vehicleId = self.vehicleObj:getId(),
            newScript = scriptName
        }
    )

    self:close()
end

----------------------------------------------------------
-- Close
----------------------------------------------------------
function SwapVehicle_UI:close()
    self:setVisible(false)
    self:removeFromUIManager()
    SwapVehicle_UI.instance = nil
end