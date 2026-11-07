-- Timed action for prying the Metal Bandsaw up off the floor with a
-- crowbar -- same technique as MyPersonalBankSafe's ISMPBSHeavyLiftAction
-- (CharacterActionAnims.Disassemble + a held Crowbar model, matching
-- vanilla's own ISMoveablesAction.lua tool-based dismantle case; the sound
-- is vanilla's own real crowbar-prying SFX, BeginRemoveBarricadePlankCrowbar).
-- Always needs the crowbar here -- unlike MPBS's own safe (which skips the
-- tool for picking up your own empty box), a bandsaw is heavy machinery
-- either way, whether it's a map-found one or one you placed yourself.

ISWorkingBandsawHeavyLiftAction = ISBaseTimedAction:derive("ISWorkingBandsawHeavyLiftAction")

function ISWorkingBandsawHeavyLiftAction:isValid()
    return self.obj ~= nil and self.obj:getSquare() ~= nil
end

function ISWorkingBandsawHeavyLiftAction:update()
end

function ISWorkingBandsawHeavyLiftAction:start()
    self.character:faceThisObject(self.obj)
    self:setActionAnim(CharacterActionAnims.Disassemble)
    self:setOverrideHandModels("Crowbar", nil)
    self.sound = self.character:playSound("BeginRemoveBarricadePlankCrowbar")
end

function ISWorkingBandsawHeavyLiftAction:stop()
    self.character:stopOrTriggerSound(self.sound)
    ISBaseTimedAction.stop(self)
end

function ISWorkingBandsawHeavyLiftAction:perform()
    self.character:stopOrTriggerSound(self.sound)
    self.character:Say(getText("IGUI_WorkingBandsaw_Heavy"))
    self.onComplete(self.character, self.obj)
    ISBaseTimedAction.perform(self)
end

--- @param character IsoPlayer
--- @param obj IsoObject the bandsaw being lifted
--- @param onComplete fun(character, obj) called once the action finishes,
---        before ISBaseTimedAction.perform -- send the actual server
---        command from here.
function ISWorkingBandsawHeavyLiftAction:new(character, obj, onComplete)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.obj = obj
    o.onComplete = onComplete
    o.maxTime = 300 -- ~10 real seconds, matches MPBS's own heavy-lift action
    o.stopOnWalk = true
    o.stopOnRun = true
    o.useProgressBar = true
    return o
end
