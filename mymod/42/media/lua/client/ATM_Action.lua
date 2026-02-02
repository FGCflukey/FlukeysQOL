-- ATM_Action.lua
-- Timed action for cashing out credit cards at ATMs

require "TimedActions/ISBaseTimedAction"

CashOutATMAction = ISBaseTimedAction:derive("CashOutATMAction")

function CashOutATMAction:isValid()
    return self.character and not self.character:isDead()
end

function CashOutATMAction:start()
    self:setActionAnim("Craft")
    self.character:SetVariable("CraftingType", "ATM")

    -----------------------------------------------------
    -- SAVE & UNEQUIP PRIMARY HAND ITEM
    -----------------------------------------------------
    if not self.originalPrimary then
        self.originalPrimary = self.character:getPrimaryHandItem()
    end

    if self.originalPrimary then
        self.character:removeFromHands(self.originalPrimary)
    end

    -----------------------------------------------------
    -- PLAY ATM SOUND
    -----------------------------------------------------
    local emitter = self.character:getEmitter()
    if emitter then
        self.atmSound = emitter:playSound("ATM_Machine")
    end
end

function CashOutATMAction:update()
    self.character:faceThisObject(self.atm)

    -----------------------------------------------------
    -- LOOP SOUND SAFELY
    -----------------------------------------------------
    local emitter = self.character:getEmitter()
    if emitter and self.atmSound and not emitter:isPlaying(self.atmSound) then
        self.atmSound = emitter:playSound("ATM_Machine")
    end
end

-----------------------------------------------------
-- RESTORE PRIMARY HAND (shared helper)
-----------------------------------------------------
local function restorePrimary(self)
    if self.originalPrimary and not self.character:isDead() then
        self.character:setPrimaryHandItem(self.originalPrimary)
    end
end

function CashOutATMAction:stop()
    -----------------------------------------------------
    -- STOP ATM SOUND
    -----------------------------------------------------
    local emitter = self.character:getEmitter()
    if emitter and self.atmSound then
        emitter:stopSound(self.atmSound)
    end

    -----------------------------------------------------
    -- ALWAYS RESTORE PRIMARY ON STOP
    -----------------------------------------------------
    restorePrimary(self)

    ISBaseTimedAction.stop(self)
end

function CashOutATMAction:perform()
    -----------------------------------------------------
    -- STOP ATM SOUND
    -----------------------------------------------------
    local emitter = self.character:getEmitter()
    if emitter and self.atmSound then
        emitter:stopSound(self.atmSound)
    end

    local inv = self.character:getInventory()

    -----------------------------------------------------
    -- REMOVE THE CREDIT CARD
    -----------------------------------------------------
    inv:Remove(self.card)

    -----------------------------------------------------
    -- DETERMINE PAYOUT
    -----------------------------------------------------
    local payout = 0
    if ZombRand(100) >= 45 then
        payout = ZombRand(0, 501) -- 0–500
    end

    -----------------------------------------------------
    -- GIVE MONEY BUNDLES + LOOSE MONEY
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

    -----------------------------------------------------
    -- ALWAYS RESTORE PRIMARY ON PERFORM
    -----------------------------------------------------
    restorePrimary(self)

    ISBaseTimedAction.perform(self)
end

function CashOutATMAction:new(character, atm, card)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.atm = atm
    o.card = card
    o.maxTime = 600 -- 10 seconds
    o.stopOnWalk = true
    o.stopOnRun = true
    o.useProgressBar = true

    -- Save original primary here
    o.originalPrimary = character:getPrimaryHandItem()

    return o
end