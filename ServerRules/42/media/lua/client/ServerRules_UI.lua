-- ServerRules_UI.lua
-- On joining a multiplayer server, asks the server whether this player has accepted the current
-- rules. If not, shows a window that can't be closed: welcome text, one checkbox per rule, and
-- Accept (only clickable once every rule is ticked) / Decline. Declining once shows a warning;
-- declining again, or running out of time, leaves the server the same way vanilla's in-game
-- "Exit" button does (getCore():quit()).

require "ServerRules_Shared"
require "ISUI/ISPanel"
require "ISUI/ISRichTextPanel"
require "ISUI/ISTickBox"
require "ISUI/ISButton"
require "ISUI/ISLabel"

local DEBUG = false
local function dbg(msg) if DEBUG then print("[ServerRules:UI] " .. tostring(msg)) end end

local PAD = 15
local MAX_WIDTH = 640
local MAX_WELCOME_HEIGHT = 220
local BUTTON_W, BUTTON_H = 120, 28
local LEAVE_DELAY_MS = 1500        -- give the Decline log message time to reach the server
local ACCEPT_TIMEOUT_MS = 10000    -- server should answer Accept well within this

local function nowMs() return getTimestampMs() end

---------------------------------------------------------
-- Leaving the server (same steps as MainScreen's in-game "EXIT" option)
---------------------------------------------------------
local function quitToMenu()
    if isQuitCooldown() then return false end   -- vanilla refuses to quit during the cooldown; retry later
    setGameSpeed(1)
    pauseSoundAndMusic()
    setShowPausedMessage(true)
    getCore():quit()
    return true
end

---------------------------------------------------------
-- Window
---------------------------------------------------------
ServerRules_Window = ISPanel:derive("ServerRules_Window")

function ServerRules_Window:createChildren()
    ISPanel.createChildren(self)

    local innerW = self.width - PAD * 2
    local y = PAD

    -- Title
    local titleFont = UIFont.Large
    self.titleY = y
    y = y + getTextManager():getFontHeight(titleFont) + PAD

    -- Welcome text (scrolls if it's long)
    if self.data.welcome and self.data.welcome ~= "" then
        local welcome = ISRichTextPanel:new(PAD, y, innerW, MAX_WELCOME_HEIGHT)
        welcome:initialise()
        self:addChild(welcome)
        welcome:addScrollBars()
        welcome.background = false
        welcome.clip = true
        welcome.autosetheight = false
        welcome.text = self.data.welcome
        welcome:paginate()
        welcome:setHeight(math.min(welcome:getScrollHeight(), MAX_WELCOME_HEIGHT))
        y = y + welcome:getHeight() + PAD
    end

    -- Rules header
    local header = ISLabel:new(PAD, y, getTextManager():getFontHeight(UIFont.Medium),
        getText("UI_ServerRules_RulesHeader"), 1, 0.85, 0.4, 1, UIFont.Medium, true)
    header:initialise()
    self:addChild(header)
    y = y + header:getHeight() + 8

    -- One checkbox + word-wrapped text per rule (ISTickBox rows can't wrap long text themselves)
    self.ticks = {}
    self.ticked = {}
    local textX = PAD + 30
    for i, ruleText in ipairs(self.data.rules or {}) do
        local tick = ISTickBox:new(PAD, y, 24, 20, "", self, ServerRules_Window.onTick, i)
        tick:initialise()
        tick:addOption("")
        self:addChild(tick)
        self.ticks[i] = tick
        self.ticked[i] = false

        local text = ISRichTextPanel:new(textX, y - 2, self.width - textX - PAD, 20)
        text:initialise()
        text.background = false
        text.autosetheight = true
        text.marginTop = 2
        text.text = tostring(i) .. ". " .. ruleText
        self:addChild(text)
        text:paginate()

        y = y + math.max(text:getHeight(), tick:getHeight()) + 6
    end

    -- Warning (after the first Decline) and status / timer lines
    y = y + 4
    self.warningLabel = ISLabel:new(PAD, y, getTextManager():getFontHeight(UIFont.Small),
        "", 1, 0.3, 0.3, 1, UIFont.Small, true)
    self.warningLabel:initialise()
    self:addChild(self.warningLabel)
    y = y + self.warningLabel:getHeight() + 4

    self.statusLabel = ISLabel:new(PAD, y, getTextManager():getFontHeight(UIFont.Small),
        "", 0.8, 0.8, 0.8, 1, UIFont.Small, true)
    self.statusLabel:initialise()
    self:addChild(self.statusLabel)
    y = y + self.statusLabel:getHeight() + PAD

    -- Buttons
    local gap = 20
    local bx = (self.width - (BUTTON_W * 2 + gap)) / 2
    self.acceptButton = ISButton:new(bx, y, BUTTON_W, BUTTON_H, getText("UI_ServerRules_Accept"), self, ServerRules_Window.onAccept)
    self.acceptButton:initialise()
    self:addChild(self.acceptButton)

    self.declineButton = ISButton:new(bx + BUTTON_W + gap, y, BUTTON_W, BUTTON_H, getText("UI_ServerRules_Decline"), self, ServerRules_Window.onDecline)
    self.declineButton:initialise()
    self:addChild(self.declineButton)
    y = y + BUTTON_H + PAD

    -- Size to content and centre on screen
    self:setHeight(y)
    self:setX((getCore():getScreenWidth() - self.width) / 2)
    self:setY(math.max(10, (getCore():getScreenHeight() - self.height) / 2))

    self:updateAcceptButton()
end

function ServerRules_Window:prerender()
    ISPanel.prerender(self)
    local title = (self.data.title and self.data.title ~= "") and self.data.title or getText("UI_ServerRules_DefaultTitle")
    self:drawTextCentre(title, self.width / 2, self.titleY, 1, 1, 1, 1, UIFont.Large)
end

function ServerRules_Window:allTicked()
    for i = 1, #self.ticks do
        if not self.ticked[i] then return false end
    end
    return true
end

function ServerRules_Window:updateAcceptButton()
    self.acceptButton:setEnable(self:allTicked() and not self.busy)
end

function ServerRules_Window:onTick(optionIndex, selected, ruleIndex)
    self.ticked[ruleIndex] = selected and true or false
    self:updateAcceptButton()
end

function ServerRules_Window:onAccept()
    if self.busy or not self:allTicked() then return end
    self.busy = true
    self.acceptSentAt = nowMs()
    self.statusLabel:setName(getText("UI_ServerRules_Saving"))
    self:updateAcceptButton()
    self.declineButton:setEnable(false)
    sendClientCommand(self.player, ServerRules.MODULE, ServerRules.CMD_ACCEPT, {
        version = self.data.version,
        steamId = tostring(getCurrentUserSteamID() or ""),
    })
end

function ServerRules_Window:startLeaving(reason)
    if self.leaving then return end
    self.leaving = true
    self.busy = true
    self:updateAcceptButton()
    self.declineButton:setEnable(false)
    for _, tick in ipairs(self.ticks) do tick.enable = false end
    self.statusLabel:setName(getText(reason == "timeout" and "UI_ServerRules_TimeUp" or "UI_ServerRules_Leaving"))
    sendClientCommand(self.player, ServerRules.MODULE, ServerRules.CMD_DECLINE, {
        reason = reason,
        steamId = tostring(getCurrentUserSteamID() or ""),
    })
    self.quitAt = nowMs() + LEAVE_DELAY_MS
    dbg("leaving: " .. reason)
end

function ServerRules_Window:onDecline()
    if self.busy then return end
    if not self.warned then
        self.warned = true
        self.warningLabel:setName(getText("UI_ServerRules_Warning"))
        return
    end
    self:startLeaving("declined")
end

function ServerRules_Window:update()
    ISPanel.update(self)
    local now = nowMs()

    -- Leaving: wait out the short delay, then quit (retrying while vanilla's quit cooldown is active)
    if self.quitAt then
        if now >= self.quitAt and quitToMenu() then self.quitAt = nil end
        return
    end

    -- Server didn't answer the Accept in time: let them try again
    if self.acceptSentAt and now - self.acceptSentAt > ACCEPT_TIMEOUT_MS then
        self.acceptSentAt = nil
        self.busy = false
        self.statusLabel:setName(getText("UI_ServerRules_NoResponse"))
        self.declineButton:setEnable(true)
        self:updateAcceptButton()
        return
    end

    -- Countdown
    if self.deadline and not self.acceptSentAt then
        local left = math.max(0, math.ceil((self.deadline - now) / 1000))
        self.statusLabel:setName(getText("UI_ServerRules_TimeLeft", string.format("%d:%02d", math.floor(left / 60), left % 60)))
        if left <= 0 then self:startLeaving("timeout") end
    end
end

function ServerRules_Window:close()
    self:setVisible(false)
    self:removeFromUIManager()
    if ServerRules.window == self then ServerRules.window = nil end
end

function ServerRules_Window:new(player, data)
    local width = math.min(MAX_WIDTH, getCore():getScreenWidth() - 40)
    local o = ISPanel:new(0, 0, width, 200)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.data = data
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.92 }
    o.borderColor = { r = 1, g = 0.85, b = 0.4, a = 0.8 }
    o.moveWithMouse = false
    if (tonumber(data.timeLimit) or 0) > 0 then
        o.deadline = nowMs() + tonumber(data.timeLimit) * 1000
    end
    return o
end

---------------------------------------------------------
-- Showing / closing
---------------------------------------------------------
local function showWindow(data)
    if ServerRules.window then ServerRules.window:close() end   -- e.g. rules changed while reading
    local w = ServerRules_Window:new(getPlayer(), data)
    w:initialise()
    w:addToUIManager()
    w:setAlwaysOnTop(true)
    w:bringToTop()
    ServerRules.window = w
end

---------------------------------------------------------
-- Asking the server on join (retried a few times in case the first message is too early)
---------------------------------------------------------
local FIRST_ASK_DELAY_MS = 3000
local RETRY_MS = 10000
local MAX_ASKS = 5

local asking = nil   -- { nextAt = ms, count = n } while waiting for the server's answer

local function onTickAsk()
    if not asking then
        Events.OnTick.Remove(onTickAsk)
        return
    end
    local player = getPlayer()
    if not player or nowMs() < asking.nextAt then return end
    if asking.count >= MAX_ASKS then
        dbg("no answer from server after " .. MAX_ASKS .. " tries (is ServerRules installed on the server?)")
        asking = nil
        return
    end
    asking.count = asking.count + 1
    asking.nextAt = nowMs() + RETRY_MS
    dbg("asking server, try " .. asking.count)
    sendClientCommand(player, ServerRules.MODULE, ServerRules.CMD_CHECK, {})
end

local function onGameStart()
    if not isClient() then return end   -- multiplayer only
    asking = { nextAt = nowMs() + FIRST_ASK_DELAY_MS, count = 0 }
    Events.OnTick.Add(onTickAsk)
end

local function onServerCommand(module, command, args)
    if module ~= ServerRules.MODULE then return end
    asking = nil   -- any answer means the server heard us
    dbg("server said: " .. tostring(command))

    if command == ServerRules.CMD_SHOW then
        showWindow(args or {})
    elseif command == ServerRules.CMD_RECORDED or command == ServerRules.CMD_ACCEPTED or command == ServerRules.CMD_NONE then
        if ServerRules.window then ServerRules.window:close() end
    end
end

Events.OnGameStart.Add(onGameStart)
Events.OnServerCommand.Add(onServerCommand)
