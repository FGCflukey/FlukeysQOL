-- Automaker_UI.lua
-- Vehicle-building window. Structure (list + live 3D preview side by
-- side) is modeled directly on SwapVehicle_UI.lua, which already
-- proves this exact 3D-preview approach works in this game version --
-- same javaObject:fromLua1/fromLua2 calls, same ISUI3DScene usage.

AutomakerUI = ISCollapsableWindow:derive("AutomakerUI")
AutomakerUI.instance = nil

local UI_WIDTH = 845
local UI_HEIGHT = 600

function AutomakerUI.open(player)
    if AutomakerUI.instance then
        AutomakerUI.instance:close()
    end

    local x = (getCore():getScreenWidth() - UI_WIDTH) / 2
    local y = (getCore():getScreenHeight() - UI_HEIGHT) / 2

    local ui = AutomakerUI:new(x, y, UI_WIDTH, UI_HEIGHT, player)
    ui:initialise()
    ui:addToUIManager()

    AutomakerUI.instance = ui
end

function AutomakerUI:new(x, y, w, h, player)
    local o = ISCollapsableWindow:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self

    o.player = player
    o.title = "Automaker: Please create your vehicle outside in an open area!"
    o.resizable = false
    return o
end

function AutomakerUI:createChildren()
    ISCollapsableWindow.createChildren(self)

    local th = self:titleBarHeight()

    self.panel = ISTabPanel:new(1, th, self.width - 2, self.height - (th + 1))
    self.panel:initialise()
    self.panel:setAnchorRight(true)
    self.panel:setAnchorBottom(true)
    self.panel.tabHeight = 25
    self.panel:setEqualTabWidth(false)
    self:addChild(self.panel)

    local buckets = Automaker_Util.collectBuildableVehicles()

    local tabWidth = self.width
    local tabHeight = self.panel.height - self.panel.tabHeight

    local tab

    tab = AutomakerTab:new(0, 0, tabWidth, tabHeight, self.player, 1, buckets[1], "std")
    tab:initialise()
    self.panel:addView("Standard Models", tab)

    tab = AutomakerTab:new(0, 0, tabWidth, tabHeight, self.player, 2, buckets[2], "hvy")
    tab:initialise()
    self.panel:addView("Heavy Duty Models", tab)

    tab = AutomakerTab:new(0, 0, tabWidth, tabHeight, self.player, 3, buckets[3], "spt")
    tab:initialise()
    self.panel:addView("Sport Models", tab)

    tab = AutomakerTab:new(0, 0, tabWidth, tabHeight, self.player, 0, buckets[0], "oth")
    tab:initialise()
    self.panel:addView("Other Models", tab)

    self.panel:activateView("Standard Models")
end

function AutomakerUI:close()
    self:setVisible(false)
    self:removeFromUIManager()
    AutomakerUI.instance = nil
end

-----------------------------------------------------
-- ONE TAB: vehicle list (left) + 3D preview (right) +
-- requirement description + Build button.
-----------------------------------------------------
AutomakerTab = ISPanelJoypad:derive("AutomakerTab")

function AutomakerTab:new(x, y, width, height, player, mechanictype, vehicles, previewKey)
    local o = ISPanelJoypad:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.player = player
    o.mechanictype = mechanictype
    o.vehicles = vehicles or {}
    o.previewKey = "automakerPreview_" .. previewKey
    o:noBackground()
    return o
end

function AutomakerTab:initialise()
    ISPanelJoypad.initialise(self)

    local pad = 10

    ------------------------------------------------------
    -- LEFT: vehicle list
    ------------------------------------------------------
    local listW = (self.width - pad * 3) * 0.35
    local listH = self.height - 100

    self.list = ISScrollingListBox:new(pad, pad, listW, listH)
    self.list:initialise()
    self.list:instantiate()
    self.list.font = UIFont.NewSmall
    self.list.itemheight = getTextManager():getFontHeight(UIFont.NewSmall) + 10
    self.list.drawBorder = true

    self.list.onMouseDown = function(list, x, y)
        ISScrollingListBox.onMouseDown(list, x, y)
        self:onSelectVehicle()
    end

    self:addChild(self.list)

    for _, v in ipairs(self.vehicles) do
        local item = self.list:addItem(Automaker_Util.getVehicleRealName(v.name), v)
        item.vehicle = v
    end

    ------------------------------------------------------
    -- RIGHT: 3D preview
    ------------------------------------------------------
    local previewX = self.list:getRight() + pad
    local previewW = self.width - previewX - pad
    local previewH = listH * 0.55

    self.preview = ISUI3DScene:new(previewX, pad, previewW, previewH)
    self.preview:initialise()
    self.preview:instantiate()
    self.preview:setView("Right")
    self.preview.javaObject:fromLua1("setZoom", 4)
    self.preview.javaObject:fromLua1("setDrawGrid", false)
    self.preview.javaObject:fromLua1("createVehicle", self.previewKey)
    self:addChild(self.preview)

    ------------------------------------------------------
    -- Description panel (materials/skill/recipe requirements)
    ------------------------------------------------------
    self.descriptionPanel = ISRichTextPanel:new(previewX, self.preview:getBottom() + pad, previewW, listH - previewH - pad)
    self.descriptionPanel.marginLeft = 0
    self.descriptionPanel.marginRight = 0
    self.descriptionPanel:initialise()
    self.descriptionPanel:instantiate()
    self.descriptionPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.5 }
    self.descriptionPanel.borderColor = { r = 1, g = 1, b = 1, a = 1 }
    self.descriptionPanel:setMargins(5, 5, 5, 5)
    self:addChild(self.descriptionPanel)

    ------------------------------------------------------
    -- Build button
    ------------------------------------------------------
    self.buildButton = ISButton:new(pad, self.height - 34, 150, 24, "Build Vehicle", self, AutomakerTab.onBuildClick)
    self.buildButton:initialise()
    self.buildButton:instantiate()
    self:addChild(self.buildButton)

    if #self.vehicles > 0 then
        self.list.selected = 1
        self:onSelectVehicle()
    else
        self.descriptionPanel:setText("No vehicles in this category.")
        self.descriptionPanel:paginate()
        self.buildButton:setEnable(false)
    end
end

function AutomakerTab:onSelectVehicle()
    local item = self.list.items[self.list.selected]
    if not item then return end

    self.preview.javaObject:fromLua2("setVehicleScript", self.previewKey, item.vehicle.fullName)
    self:updateDescription(item.vehicle)
end

-----------------------------------------------------
-- Keep requirements/button state current while the window
-- is open (e.g. the player picks up more sheet metal without
-- re-selecting a vehicle) -- throttled, matching the cadence
-- HomeHeat's client-side heat source scan already uses.
-----------------------------------------------------
local TICKS_BETWEEN_REFRESH = 30
function AutomakerTab:update()
    ISPanelJoypad.update(self)

    self.refreshTickCounter = (self.refreshTickCounter or 0) + 1
    if self.refreshTickCounter < TICKS_BETWEEN_REFRESH then return end
    self.refreshTickCounter = 0

    local item = self.list.items[self.list.selected]
    if item then
        self:updateDescription(item.vehicle)
    end
end

function AutomakerTab:updateDescription(v)
    local player = self.player
    local playerInv = player:getInventory()
    local mechanictype = self.mechanictype
    local buildCheat = isAdmin() and player:isBuildCheat()

    local requirements = Automaker_Util.getMaterialReq(mechanictype, buildCheat)
    local mechanicReq, metalworkReq, electricalReq = Automaker_Util.getSkillReq(player, mechanictype)
    local materialOnGround = buildUtil.checkMaterialOnGround(player:getSquare())

    local function line(current, required, label)
        local color = current < required and "<RGB:1,0,0>" or "<RGB:0,1,0>"
        return " <LINE> " .. color .. label .. " " .. current .. "/" .. required
    end

    local description = "<RGB:1,1,1> " .. Automaker_Util.getVehicleRealName(v.name) .. " <LINE>"

    for _, mat in ipairs({ "SheetMetal", "MetalBar", "ElectronicsScrap", "ElectricWire", "EngineParts" }) do
        local total = (materialOnGround[mat] or 0) + playerInv:getCountTypeRecurse(mat)
        description = description .. line(total, requirements[mat], mat)
    end

    description = description .. line(player:getPerkLevel(Perks.Mechanics), mechanicReq, "Mechanics")
    description = description .. line(player:getPerkLevel(Perks.MetalWelding), metalworkReq, "Metalworking")
    description = description .. line(player:getPerkLevel(Perks.Electricity), electricalReq, "Electrical")

    local recipeName = Automaker_Util.recipeForType(mechanictype)
    local hasRecipe = player:getKnownRecipes():contains(recipeName)
    description = description .. " <LINE> " .. (hasRecipe and "<RGB:0,1,0>" or "<RGB:1,0,0>") .. "Recipe: " .. recipeName

    self.descriptionPanel:setText(description)
    self.descriptionPanel:paginate()

    -- ISRichTextPanel:setText() only stores the text -- paginate() is
    -- what actually renders it. Missing that call is why the box
    -- showed blank before.
    local ok = Automaker_Util.canBuild(player, mechanictype)
    self.buildButton:setEnable(ok)
end

function AutomakerTab:onBuildClick()
    local item = self.list.items[self.list.selected]
    if not item then return end

    local ok = Automaker_Util.canBuild(self.player, self.mechanictype)
    if not ok then
        self.player:Say("I can't make that vehicle!")
        return
    end

    sendClientCommand(self.player, "Automaker", "CreateVehicle", {
        VehicleID = item.vehicle.fullName,
        MechanicType = self.mechanictype,
    })

    AutomakerUI.instance:close()
end
