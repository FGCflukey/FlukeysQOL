-- ATM_Action.lua
-- Timed action for cashing out credit cards at ATMs

require "TimedActions/ISBaseTimedAction"

CashOutATMAction = ISBaseTimedAction:derive("CashOutATMAction")

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
    -- Face ATM once (prevents animation fighting)
    if self.atm then
        self.character:faceThisObject(self.atm)
    end

    -- Use looting animation instead of crafting
    if self.setActionAnim then
        self:setActionAnim("Loot")
    end
    if self.setAnimVariable then
        self:setAnimVariable("LootPosition", "Mid")
    end

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
    -- No more forced facing here (prevents turning away)
    -- Sound loop safety
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

    -----------------------------------------------------
    -- HAND OFF TO SERVER (MP-safe)
    --
    -- Server does the authoritative find+remove+payout AND
    -- syncs it properly via sendAddItemToContainer /
    -- sendRemoveItemFromContainer. No client-side prediction
    -- needed anymore -- the server-side sync is instant and
    -- reliable now that it's using the right functions.
    -----------------------------------------------------
    sendClientCommand(self.character, "ATM", "cashOut", {})

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
    o.card = card -- kept for compatibility, not relied on
    o.maxTime = 600
    o.stopOnWalk = true
    o.stopOnRun = true
    o.useProgressBar = true

    o.originalPrimary = character:getPrimaryHandItem()

    return o
end

-----------------------------------------------------
-- SERVER RESULT FEEDBACK (chat bubble)
--
-- The server can't reliably trigger Say() on a specific
-- client from server-side Lua, so it sends the outcome back
-- and the owning client says it locally instead.
-----------------------------------------------------
local function OnServerCommand(module, command, args)
    if module ~= "ATM" or command ~= "result" then return end

    local player = getPlayer()
    if not player then return end

    if args.reason == "noCard" then
        player:Say("Card not found.")
    elseif args.payout and args.payout > 0 then
        player:Say("Withdrew $" .. args.payout)
    else
        player:Say("Transaction failed")
    end
end
Events.OnServerCommand.Add(OnServerCommand)