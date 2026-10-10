-- Shared timed action for both "heavy lift" moments in this mod -- detaching the
-- decorative safe off the floor (withCrowbar=true), and picking up an already-placed
-- empty safe (withCrowbar=false, no tool needed since it's just your own box). Both
-- were previously instant, silent server commands.
--
-- withCrowbar=true: CharacterActionAnims.Disassemble + a held Crowbar model, matching
-- vanilla's own moveable-dismantle action exactly (ISMoveablesAction.lua:183-184,
-- which does self:setActionAnim(CharacterActionAnims.Disassemble) +
-- self:setOverrideHandModels("Screwdriver", nil) for its own tool-based case --
-- same pattern, our tool instead of theirs).
-- withCrowbar=false: no anim/hand override at all, exactly matching vanilla's own
-- moveable PICKUP mode, which (same file, same function) never calls setActionAnim
-- or setOverrideHandModels when mode isn't "scrap"/"repair" -- confirmed by reading
-- the whole function, not guessed.
--
-- Sound is vanilla's own real crowbar-prying SFX either way (BeginRemoveBarricadePlankCrowbar,
-- confirmed from sounds_object_barricade.txt -- named for the wood barricade context
-- it was authored for, but it's the actual crowbar audio event, not wood-specific).
-- Ends with a short "that's heavy" line.

ISMPBSHeavyLiftAction = ISBaseTimedAction:derive("ISMPBSHeavyLiftAction")

function ISMPBSHeavyLiftAction:isValid()
    return self.obj ~= nil and self.obj:getSquare() ~= nil
end

function ISMPBSHeavyLiftAction:update()
end

function ISMPBSHeavyLiftAction:start()
    self.character:faceThisObject(self.obj)
    if self.withCrowbar then
        self:setActionAnim(CharacterActionAnims.Disassemble)
        self:setOverrideHandModels("Crowbar", nil)
    end
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
--- @param withCrowbar boolean true = show the crowbar in-hand (detach); false = plain
---        pickup pose, no tool (retrieving your own already-placed safe)
function ISMPBSHeavyLiftAction:new(character, obj, onComplete, withCrowbar)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.obj = obj
    o.onComplete = onComplete
    o.withCrowbar = withCrowbar
    o.maxTime = 300 -- ~10 real seconds, matches this pack's other ~20s/~4s actions scaled proportionally
    o.stopOnWalk = true
    o.stopOnRun = true
    o.useProgressBar = true
    return o
end
