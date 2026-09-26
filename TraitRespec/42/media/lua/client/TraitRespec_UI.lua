-- media/lua/client/TraitRespec_UI.lua
--
-- Two-list browser (owned traits you can refund / traits you can spend
-- points on), opened via a real rebindable keybind (getCore():addKeyBinding,
-- same API vanilla's own MainOptions.lua uses -- shows up in Options >
-- Keybinding like any other action, not a hardcoded key check). Client
-- only ever requests; TraitRespec_Server.lua re-validates and does the
-- actual mutation, same pattern as every other feature in this pack.

require "TraitRespec_Util"
require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISModalDialog"

local DEBUG = false
local function dbg(msg)
    if DEBUG then
        print("[TraitRespec:UI] " .. tostring(msg))
    end
end

local KEYBIND_NAME = "Toggle Trait Respec"
local DEFAULT_KEY = Keyboard.KEY_F7

local currentPoints = 0

---------------------------------------------------------
-- TraitRespec_Window
---------------------------------------------------------
TraitRespec_Window = ISCollapsableWindow:derive("TraitRespec_Window")

function TraitRespec_Window:refreshLists()
    self.listOwned:clear()
    self.listAvailable:clear()

    local player = self.player
    local ownedTypes = {}
    local knownTraits = player:getCharacterTraits():getKnownTraits()
    for i = 0, knownTraits:size() - 1 do
        ownedTypes[knownTraits:get(i)] = true
    end

    local allTraits = CharacterTraitDefinition.getTraits()
    for i = 0, allTraits:size() - 1 do
        local trait = allTraits:get(i)
        if TraitRespec_Util.isTraitEligible(trait:getType()) then
            local cost = TraitRespec_Util.getTraitCost(trait)
            local label = trait:getLabel() .. " (" .. cost .. ")"
            if ownedTypes[trait:getType()] then
                self.listOwned:addItem(label, trait)
            else
                self.listAvailable:addItem(label, trait)
            end
        end
    end

    self.pointsLabel:setName(getText("UI_TraitRespec_Points") .. currentPoints)
end

function TraitRespec_Window:onConfirmRefund(button, trait)
    if button.internal ~= "YES" then return end
    sendClientCommand(self.player, "TraitRespec", "RefundTrait", { traitType = trait:getType():toString() })
end

function TraitRespec_Window:onDblClickOwned(trait)
    if not trait then return end
    local cost = TraitRespec_Util.getTraitCost(trait)
    local modal = ISModalDialog:new(0, 0, 300, 150,
        getText("UI_TraitRespec_ConfirmRefund", trait:getLabel(), cost), true,
        self, TraitRespec_Window.onConfirmRefund, self.player, trait)
    modal:initialise()
    modal:addToUIManager()
end

function TraitRespec_Window:onConfirmPurchase(button, trait)
    if button.internal ~= "YES" then return end
    sendClientCommand(self.player, "TraitRespec", "PurchaseTrait", { traitType = trait:getType():toString() })
end

function TraitRespec_Window:onDblClickAvailable(trait)
    if not trait then return end
    local cost = TraitRespec_Util.getTraitCost(trait)
    if currentPoints < cost then
        self.player:Say(getText("UI_TraitRespec_NotEnoughPoints"))
        return
    end
    local modal = ISModalDialog:new(0, 0, 300, 150,
        getText("UI_TraitRespec_ConfirmPurchase", trait:getLabel(), cost), true,
        self, TraitRespec_Window.onConfirmPurchase, self.player, trait)
    modal:initialise()
    modal:addToUIManager()
end

function TraitRespec_Window:createChildren()
    ISCollapsableWindow.createChildren(self)

    local pad = 10
    local listWidth = (self.width - pad * 3) / 2
    local listHeight = self.height - 70

    self.ownedLabel = ISLabel:new(pad, 30, 20, getText("UI_TraitRespec_Owned"), 1, 1, 1, 1, UIFont.Small, true)
    self.ownedLabel:initialise()
    self:addChild(self.ownedLabel)

    self.availableLabel = ISLabel:new(pad * 2 + listWidth, 30, 20, getText("UI_TraitRespec_Available"), 1, 1, 1, 1, UIFont.Small, true)
    self.availableLabel:initialise()
    self:addChild(self.availableLabel)

    self.listOwned = ISScrollingListBox:new(pad, 50, listWidth, listHeight)
    self.listOwned:initialise()
    self.listOwned:instantiate()
    self.listOwned.itemheight = 20
    self.listOwned.drawBorder = true
    self.listOwned:setOnMouseDoubleClick(self, self.onDblClickOwned)
    self:addChild(self.listOwned)

    self.listAvailable = ISScrollingListBox:new(pad * 2 + listWidth, 50, listWidth, listHeight)
    self.listAvailable:initialise()
    self.listAvailable:instantiate()
    self.listAvailable.itemheight = 20
    self.listAvailable.drawBorder = true
    self.listAvailable:setOnMouseDoubleClick(self, self.onDblClickAvailable)
    self:addChild(self.listAvailable)

    self.pointsLabel = ISLabel:new(pad, self.height - 20, 20, getText("UI_TraitRespec_Points") .. currentPoints, 1, 1, 1, 1, UIFont.Small, true)
    self.pointsLabel:initialise()
    self:addChild(self.pointsLabel)

    self:refreshLists()
end

function TraitRespec_Window:new(x, y, width, height, player)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o:setTitle(getText("UI_TraitRespec_Title"))
    o:setResizable(true)
    return o
end

---------------------------------------------------------
-- Entry point
---------------------------------------------------------
TraitRespec_UI = TraitRespec_UI or {}
TraitRespec_UI.window = nil

function TraitRespec_UI.toggleWindow()
    local player = getPlayer()
    if not player then return end

    if TraitRespec_UI.window then
        TraitRespec_UI.window:close()
        TraitRespec_UI.window:removeFromUIManager()
        TraitRespec_UI.window = nil
        return
    end

    local width, height = 500, 400
    local x = (getCore():getScreenWidth() - width) / 2
    local y = (getCore():getScreenHeight() - height) / 2
    TraitRespec_UI.window = TraitRespec_Window:new(x, y, width, height, player)
    TraitRespec_UI.window:initialise()
    TraitRespec_UI.window:addToUIManager()
    sendClientCommand(player, "TraitRespec", "RequestPoints", {})
end

local function OnServerCommand_TraitRespec(module, command, args)
    if module ~= "TraitRespec" then return end
    if not args then return end

    if command == "PointsUpdate" then
        currentPoints = args.points or currentPoints
    elseif command == "RefundSuccess" then
        currentPoints = args.points or currentPoints
        getPlayer():Say(getText("UI_TraitRespec_Refunded", args.refund or 0))
    elseif command == "PurchaseSuccess" then
        currentPoints = args.points or currentPoints
        getPlayer():Say(getText("UI_TraitRespec_Purchased"))
    elseif command == "RefundFail" or command == "PurchaseFail" then
        dbg((command) .. " reason=" .. tostring(args.reason))
        getPlayer():Say(getText("UI_TraitRespec_ActionFailed"))
    end

    if TraitRespec_UI.window then
        TraitRespec_UI.window:refreshLists()
    end
end
Events.OnServerCommand.Add(OnServerCommand_TraitRespec)

---------------------------------------------------------
-- Keybind registration + handling
---------------------------------------------------------
local function RegisterKeyBind()
    getCore():addKeyBinding(KEYBIND_NAME, DEFAULT_KEY, 0, false, false, false)
end
Events.OnGameBoot.Add(RegisterKeyBind)

local function OnKeyStartPressed(key)
    if key == getCore():getKey(KEYBIND_NAME) then
        TraitRespec_UI.toggleWindow()
    end
end
Events.OnKeyStartPressed.Add(OnKeyStartPressed)
