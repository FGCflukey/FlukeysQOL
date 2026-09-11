-- HomeHeat_UI.lua
-- Right-click settings dialog for a placed HomeHeat radiator:
-- on/off and 3 presets (Cool/Normal/Hot).

require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"

HomeHeat_UI = {}
HomeHeat_UI.instance = nil

HomeHeatWindow = ISCollapsableWindow:derive("HomeHeatWindow")

HomeHeatWindow.WIDTH = 360
HomeHeatWindow.HEIGHT = 165

function HomeHeat_UI.open(player, isoObject)
    if HomeHeat_UI.instance then
        HomeHeat_UI.instance:close()
        HomeHeat_UI.instance = nil
    end

    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    local w, h = HomeHeatWindow.WIDTH, HomeHeatWindow.HEIGHT
    local x = (sw - w) / 2
    local y = (sh - h) / 2

    local window = HomeHeatWindow:new(x, y, w, h, player, isoObject)
    window:initialise()
    window:addToUIManager()
    HomeHeat_UI.instance = window
end

-----------------------------------------------------
-- WINDOW
-----------------------------------------------------
function HomeHeatWindow:initialise()
    ISCollapsableWindow.initialise(self)

    self.resizable = false

    self.activeBg     = { r = 0.28, g = 0.35, b = 0.55, a = 1 }
    self.activeBorder = { r = 0.55, g = 0.68, b = 1.0,  a = 1 }
    self.inactiveBg     = { r = 0.08, g = 0.08, b = 0.1,  a = 1 }
    self.inactiveBorder = { r = 0.4,  g = 0.4,  b = 0.45, a = 1 }

    -----------------------------------------------------
    -- PRESET BUTTONS
    -----------------------------------------------------
    self.presetButtons = {}
    local x = 10
    local y = 40
    for _, preset in ipairs(HomeHeat_Util.PRESETS) do
        local btn = ISButton:new(x, y, 110, 30, preset.label, self, HomeHeatWindow.onPreset)
        btn.internal = preset.key
        btn:initialise()
        btn:instantiate()
        self:addChild(btn)
        table.insert(self.presetButtons, btn)
        x = x + 115
    end

    -----------------------------------------------------
    -- ON/OFF BUTTON
    -----------------------------------------------------
    self.onOffButton = ISButton:new(10, 80, 175, 30, "Turn On", self, HomeHeatWindow.onToggle)
    self.onOffButton:initialise()
    self.onOffButton:instantiate()
    self:addChild(self.onOffButton)

    -----------------------------------------------------
    -- CLOSE BUTTON
    -----------------------------------------------------
    self.closeButton = ISButton:new(self.width - 90, self.height - 40, 80, 25, "Close", self, HomeHeatWindow.onClose)
    self.closeButton:initialise()
    self.closeButton:instantiate()
    self:addChild(self.closeButton)

    self:refreshFromObject()
end

-----------------------------------------------------
-- PULL LATEST STATE FROM THE PLACED OBJECT'S MODDATA
-- (server-authoritative -- this window only ever reads
-- it and requests changes, never writes it directly)
-----------------------------------------------------
function HomeHeatWindow:refreshFromObject()
    local modData = self.isoObject:getModData()
    self.on = modData.on == true
    self.presetKey = modData.presetKey or HomeHeat_Util.DEFAULT_PRESET
    self.power = HomeHeat_Util.hasPower(self.isoObject:getSquare())
    self.outside = self.isoObject:getSquare():isOutside()

    self.onOffButton:setTitle(self.on and "Turn Off" or "Turn On")
    self.onOffButton.enable = self.power and not self.outside

    for _, btn in ipairs(self.presetButtons) do
        btn.enable = self.power and not self.outside
        local active = self.on and self.power and not self.outside and btn.internal == self.presetKey
        local bg = active and self.activeBg or self.inactiveBg
        local border = active and self.activeBorder or self.inactiveBorder
        btn:setBackgroundRGBA(bg.r, bg.g, bg.b, bg.a)
        btn:setBorderRGBA(border.r, border.g, border.b, border.a)
    end
end

-----------------------------------------------------
-- STATUS TEXT
-----------------------------------------------------
function HomeHeatWindow:render()
    ISCollapsableWindow.render(self)

    local statusText
    if self.outside then
        statusText = "Outdoor Placement (No Effect)"
    elseif not self.power then
        statusText = "No Power"
    elseif self.on then
        local preset = HomeHeat_Util.presetByKey(self.presetKey)
        statusText = "On - " .. preset.label
    else
        statusText = "Off"
    end

    self:drawText("Status: " .. statusText, 10, 118, 0.9, 0.9, 0.9, 1, UIFont.Small)
end

-----------------------------------------------------
-- KEEP IN SYNC + CLOSE IF THE PLAYER WALKS AWAY OR THE
-- OBJECT DISAPPEARS (matches this pack's other world-
-- object settings windows, e.g. VendorWindow)
-----------------------------------------------------
function HomeHeatWindow:update()
    ISCollapsableWindow.update(self)

    if not self.isoObject or not self.isoObject:getSquare() then
        self:close()
        return
    end

    local dx = math.abs(self.player:getX() - self.isoObject:getX())
    local dy = math.abs(self.player:getY() - self.isoObject:getY())
    if dx > 2 or dy > 2 then
        self:close()
        return
    end

    self:refreshFromObject()
end

-----------------------------------------------------
-- BUTTON HANDLERS
-----------------------------------------------------
function HomeHeatWindow:sendSetState(on, presetKey)
    sendClientCommand(self.player, "HomeHeat", "setState", {
        x = self.isoObject:getX(),
        y = self.isoObject:getY(),
        z = self.isoObject:getZ(),
        on = on,
        presetKey = presetKey,
    })
end

function HomeHeatWindow:onPreset(button)
    self:sendSetState(true, button.internal)
end

function HomeHeatWindow:onToggle()
    self:sendSetState(not self.on, self.presetKey)
end

function HomeHeatWindow:onClose()
    self:close()
end

function HomeHeatWindow:close()
    HomeHeat_UI.instance = nil
    self:setVisible(false)
    self:removeFromUIManager()
end

function HomeHeatWindow:new(x, y, width, height, player, isoObject)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.player = player
    o.isoObject = isoObject
    o.title = "Home Heat Radiator"
    o.resizable = false
    o.moveWithMouse = true
    return o
end

-----------------------------------------------------
-- SERVER RESPONSE (feedback only -- the actual state
-- change propagates to every client automatically via
-- the object's own modData replication)
-----------------------------------------------------
local function OnServerCommand_HomeHeat(module, command, args)
    if module ~= "HomeHeat" then return end

    local player = getPlayer()
    if not player then return end

    if command == "stateResult" and not args.success then
        if args.reason == "power" then
            player:Say("There's no power here.")
        elseif args.reason == "outside" then
            player:Say("This won't work outdoors.")
        elseif args.reason == "missing" then
            player:Say("That radiator isn't there anymore.")
        else
            player:Say("Something went wrong with the radiator.")
        end
    end
end

Events.OnServerCommand.Add(OnServerCommand_HomeHeat)
