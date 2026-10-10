-- Shared timed action for both "heavy lift" moments in this mod -- detaching the
-- decorative safe off the floor, and picking up an already-placed empty safe. Both
-- were previously instant, silent server commands. Uses vanilla's own real
-- crowbar-prying sound (BeginRemoveBarricadePlankCrowbar, confirmed from
-- sounds_object_barricade.txt -- named for the wood barricade context it was
-- authored for, but it's the actual crowbar SFX, not a wood-specific one) and the
-- same anim vanilla's own moveable pickup action uses (CharacterActionAnims.Disassemble,
-- confirmed from ISMoveablesAction.lua:183). Ends with a short "that's heavy" line.

ISMPBSHeavyLiftAction = ISBaseTimedAction:derive("ISMPBSHeavyLiftAction")

function ISMPBSHeavyLiftAction:isValid()
    return self.obj ~= nil and self.obj:getSquare() ~= nil
end

function ISMPBSHeavyLiftAction:update()
end

function ISMPBSHeavyLiftAction:start()
    self.character:faceThisObject(self.obj)
    self:setActionAnim(CharacterActionAnims.Disassemble)
    self.sound = self.character:playSound("BeginRemoveBarricadePlankCrowbar")
end

function ISMPBSHeavyLiftAction:stop()
    self.character:stopOrTriggerSound(self.sound)
    ISBaseTimedAction.stop(self)
end

function ISMPBSHeavyLiftAction:perform()
    self.character:stopOrTriggerSound(self.sound)
    self.character:Say(getText("IGUI_MPBS_DetachHeavy"))
    self.onComplete(self.character, self.obj)
    ISBaseTimedAction.perform(self)
end

--- @param character IsoPlayer
--- @param obj IsoObject the safe (decorative or placed) being lifted
--- @param onComplete fun(character, obj) called once the action finishes, before
---        ISBaseTimedAction.perform -- send the actual server command from here.
function ISMPBSHeavyLiftAction:new(character, obj, onComplete)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.obj = obj
    o.onComplete = onComplete
    o.maxTime = 300 -- ~10 real seconds, matches this pack's other ~20s/~4s actions scaled proportionally
    o.stopOnWalk = true
    o.stopOnRun = true
    o.useProgressBar = true
    return o
end
