-- ATM_Action.lua
-- Timed action for cashing out credit cards at ATMs

require "TimedActions/ISBaseTimedAction"

CashOutATMAction = ISBaseTimedAction:derive("CashOutATMAction")

-----------------------------------------------------
-- RECURSIVE CREDIT CARD SEARCH
-----------------------------------------------------
local function findCreditCardRecursive(container)
    if not container then return nil end

    -- Direct cards in this container
    local cards = container:getAllType("CreditCard")
    if cards and not cards:isEmpty() then
        return cards:get(0)
    end

    -- Search inside subcontainers
    local items = container:getItems()
    if items then
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item and item:IsInventoryContainer() then
                local found = findCreditCardRecursive(item:getItemContainer())
                if found then return found end
            end
        end
    end

    return nil
end

-----------------------------------------------------
-- ACTION VALIDITY
-----------------------------------------------------
function CashOutATMAction:isValid()
    return self.character and not self.character:isDead()
end

-----------------------------------------------------
-- START
-----------------------------------------------------
function CashOutATMAction:start()
    self:setActionAnim("Craft")
    self.character:SetVariable("CraftingType", "ATM")

    -- Save & unequip primary
    if not self.originalPrimary then
        self.originalPrimary = self.character:getPrimaryHandItem()
    end

    if self.originalPrimary then
        self.character:removeFromHands(self.originalPrimary)
    end

    -- Play ATM sound
    local emitter = self.character:getEmitter()
    if emitter then
        self.atmSound = emitter:playSound("ATM_Machine")
    end
end

-----------------------------------------------------
-- UPDATE
-----------------------------------------------------
function CashOutATMAction:update()
    self.character:faceThisObject(self.atm)

    -- Loop sound safely
    local emitter = self.character:getEmitter()
    if emitter and self.atmSound and not emitter:isPlaying(self.atmSound) then
        self.atmSound = emitter:playSound("ATM_Machine")
    end
end

-----------------------------------------------------
-- RESTORE PRIMARY HAND
-----------------------------------------------------
local function restorePrimary(self)
    if self.originalPrimary and not self.character:isDead() then
        self.character:setPrimaryHandItem(self.originalPrimary)
    end
end

-----------------------------------------------------
-- STOP
-----------------------------------------------------
function CashOutATMAction:stop()
    local emitter = self.character:getEmitter()
    if emitter and self.atmSound then
        emitter:stopSound(self.atmSound)
    end

    restorePrimary(self)
    ISBaseTimedAction.stop(self)
end

-----------------------------------------------------
-- PERFORM
-----------------------------------------------------
function CashOutATMAction:perform()
    -- Stop sound
    local emitter = self.character:getEmitter()
    if emitter and self.atmSound then
        emitter:stopSound(self.atmSound)
    end

    local inv = self.character:getInventory()

    -----------------------------------------------------
    -- FIND & REMOVE CREDIT CARD RECURSIVELY
    -----------------------------------------------------
    local card = findCreditCardRecursive(inv)

    if not card then
        self.character:Say("Card not found.")
        restorePrimary(self)
        ISBaseTimedAction.perform(self)
        return
    end

    -- Remove from correct container
    local cardContainer = card:getContainer()
    if cardContainer then
        cardContainer:Remove(card)
    else
        inv:Remove(card)
    end

    -----------------------------------------------------
    -- DETERMINE PAYOUT
    -----------------------------------------------------
    local payout = 0
    if ZombRand(100) >= 45 then
        payout = ZombRand(0, 501) -- 0–500
    end

    -----------------------------------------------------
    -- GIVE MONEY
    -----------------------------------------------------
    if payout > 0 then
        local bundles = math.floor(payout / 100)
        local remainder = payout % 100

        for i = 1, bundles do
            inv:AddItem("Base.MoneyBundle")
        end

        for i = 1, remainder do
            inv:AddItem("Base.Money")
        end

        self.character:Say("Withdrew $" .. payout)
    else
        self.character:Say("Transaction failed")
    end

    restorePrimary(self)
    ISBaseTimedAction.perform(self)
end

-----------------------------------------------------
-- CONSTRUCTOR
-----------------------------------------------------
function CashOutATMAction:new(character, atm, card)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.atm = atm
    o.card = card -- still stored for compatibility, but not relied on
    o.maxTime = 600
    o.stopOnWalk = true
    o.stopOnRun = true
    o.useProgressBar = true

    o.originalPrimary = character:getPrimaryHandItem()

    return o
end