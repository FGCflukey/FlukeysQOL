--========================================================
-- SwapVehicle UI (Vertical Layout + Full Script Names)
--========================================================

local SwapAction = ISSwapVinylAction

SwapVehicle_UI = ISCollapsableWindow:derive("SwapVehicle_UI")
SwapVehicle_UI.instance = nil

local UI_WIDTH  = 750
local UI_HEIGHT = 520

----------------------------------------------------------
-- Shared realism helpers (same as paint system)
----------------------------------------------------------

local DEBUG = false

local function PV_debugClimate()
    if not DEBUG then return end
    local climate = getClimateManager()
    print("---- Climate Debug ----")
    print("Rain:\t" .. tostring(climate:getRainIntensity()))
    print("Snow:\t" .. tostring(climate:getSnowIntensity()))
    print("Fog:\t" .. tostring(climate:getFogIntensity()))
    print("Storm:\t" .. tostring(climate:getThunderStorm()))
    print("NightStrength:\t" .. tostring(climate:getNightStrength()))
    print("------------------------")
end

local function PV_isBadWeather()
    local climate = getClimateManager()

    if climate:getRainIntensity() > 0 then return true end
    if climate:getSnowIntensity() > 0 then return true end
    if climate:getFogIntensity() > 0 then return true end

    local storm = climate:getThunderStorm()
    if storm and storm.active then return true end

    return false
end

local function PV_hasEnoughLight(character)
    local square = character:getSquare()
    if not square then return false end

    local playerIndex = character:getPlayerNum()

    -- Indoors: must have some light
    if not square:isOutside() then
        return square:getLightLevel(playerIndex) > 0.3
    end

    -- Outdoors
    local climate = getClimateManager()
    local isNight = climate:getNightStrength() > 0.5

    -- Daytime outdoors always OK
    if not isNight then
        return true
    end

    -- Night outdoors: must have strong artificial light
    return square:getLightLevel(playerIndex) > 0.6
end

----------------------------------------------------------
-- Correct blood‑check logic (matches paint system)
----------------------------------------------------------
local function PV_vehicleIsBloody(vehicle)
    if not vehicle or not vehicle.getBloodIntensity then
        return false
    end

    if vehicle:getBloodIntensity("Front") > 0 then return true end
    if vehicle:getBloodIntensity("Rear") > 0 then return true end
    if vehicle:getBloodIntensity("Left") > 0 then return true end
    if vehicle:getBloodIntensity("Right") > 0 then return true end

    return false
end

local function PV_needsCleaning(vehicle)
    return PV_vehicleIsBloody(vehicle)
end

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

    -- Normalize vehicle reference
    if vehicleObj and vehicleObj:getId() then
        vehicleObj = getVehicleById(vehicleObj:getId())
    end

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

    local th  = self:titleBarHeight()
    local pad = 10

    ------------------------------------------------------
    -- LEFT COLUMN: Variant List
    ------------------------------------------------------
    local listW = (self.width - pad*3) * 0.35
    local listH = self.height - th - pad*3 - 40

    self.list = ISScrollingListBox:new(
        pad, th + pad,
        listW,
        listH
    )

    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = getTextManager():getFontHeight(UIFont.NewSmall) + 10
    self.list.font = UIFont.NewSmall
    self.list.drawBorder = true

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
    -- RIGHT COLUMN: 3D Preview Panel
    ------------------------------------------------------
    local previewX = self.list:getRight() + pad
    local previewW = self.width - previewX - pad
    local previewH = listH

    self.preview = ISUI3DScene:new(
        previewX, th + pad,
        previewW, previewH
    )

    self.preview:initialise()
    self.preview:instantiate()
    self.preview:setView("Right")
    self.preview.javaObject:fromLua1("setZoom", 4)
    self.preview.javaObject:fromLua1("setDrawGrid", false)
    self.preview.javaObject:fromLua1("createVehicle", "swapPreview")

    self:addChild(self.preview)

    ------------------------------------------------------
    -- Swap Button
    ------------------------------------------------------
    self.swapBtn = ISButton:new(
        (self.width - 120) / 2,
        self.height - 35,
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
-- Swap Button Click (REALISM CHECKS ADDED)
----------------------------------------------------------
function SwapVehicle_UI:onSwapClick()
    local item = self.list.items[self.list.selected]
    if not item then return end

    local scriptName = item.scriptName

    PV_debugClimate()

    ------------------------------------------------------
    -- Weather / Light / Cleanliness gating
    ------------------------------------------------------
    if PV_isBadWeather() then
        self.player:Say("I can't apply vinyl in this weather.")
        return
    end

    if not PV_hasEnoughLight(self.player) then
        self.player:Say("It's too dark to apply vinyl.")
        return
    end

    if PV_needsCleaning(self.vehicleObj) then
        self.player:Say("I think I should wash it first.")
        return
    end

    ------------------------------------------------------
    -- REQUIRE ITEMS BEFORE STARTING TIMED ACTION
    ------------------------------------------------------
    local inv = self.player:getInventory()
    local hasSpray = inv:contains("SpraycanVinylCoat")
    local hasSanding = inv:contains("SandingBlock")

    if not hasSpray or not hasSanding then
        self.player:Say("I need a Spraycan Vinyl Coat and a Sanding Block.")
        return
    end

    ------------------------------------------------------
    -- Timed Action (Animation + Delay)
    ------------------------------------------------------
    ISTimedActionQueue.add(
        SwapAction:new(
            self.player,
            self.vehicleObj,
            scriptName,
            600
        )
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
