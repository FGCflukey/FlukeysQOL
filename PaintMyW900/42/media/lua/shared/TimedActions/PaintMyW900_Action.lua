require "TimedActions/ISBaseTimedAction"
require "PaintMyW900/PaintMyW900_Defs"

-- Paint a W900 truck/trailer a different skin.
-- Networked B42 action: the client plays the animation, complete() runs
-- on the server (or locally in solo) and does the real change: re-checks
-- everything, switches the skin, clears rust, spends the paint.

PaintMyW900Action = ISBaseTimedAction:derive("PaintMyW900Action")

local dbg = PaintMyW900.dbg

function PaintMyW900Action:isValid()
    if not self.vehicle or self.vehicle:isRemovedFromWorld() then return false end
    if isClient() and self.started then return true end
    local ok, why = PaintMyW900.canPaint(self.character, self.vehicle, self.skinIndex)
    if not ok then dbg("isValid: " .. tostring(why)) end
    return ok
end

function PaintMyW900Action:waitToStart()
    self.character:faceThisObject(self.vehicle)
    return self.character:shouldBeTurning()
end

function PaintMyW900Action:makeNoise()
    local c = self.character
    addSound(c, c:getX(), c:getY(), c:getZ(), PaintMyW900.NOISE_RADIUS, PaintMyW900.NOISE_VOLUME)
    self.lastNoise = getTimestampMs()
end

function PaintMyW900Action:start()
    self.started = true
    self:setActionAnim(CharacterActionAnims.Paint)
    self:setOverrideHandModels("PaintBrush", nil)
    self.sound = self.character:playSound("Painting")
    self:makeNoise()
end

function PaintMyW900Action:update()
    self.character:faceThisObject(self.vehicle)
    self.character:setMetabolicTarget(Metabolics.MediumWork)
    if getTimestampMs() - (self.lastNoise or 0) >= PaintMyW900.NOISE_EVERY_MS then
        self:makeNoise()
    end
end

function PaintMyW900Action:stopSound()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
end

function PaintMyW900Action:stop()
    self:stopSound()
    ISBaseTimedAction.stop(self)
end

function PaintMyW900Action:perform()
    self:stopSound()
    ISBaseTimedAction.perform(self)
end

function PaintMyW900Action:complete()
    local vehicle, character = self.vehicle, self.character
    local ok, why = PaintMyW900.canPaint(character, vehicle, self.skinIndex)
    if not ok then
        dbg("complete rejected: " .. tostring(why))
        return false
    end

    local key = PaintMyW900.getColorKey(vehicle, self.skinIndex)
    local cost = PaintMyW900.getCost(vehicle, key)
    if not PaintMyW900.spendPaint(character, cost) then
        dbg("complete: spending paint failed")
        return false
    end

    vehicle:setSkinIndex(self.skinIndex)
    vehicle:setRust(0)
    if isServer() then
        vehicle:transmitSkinIndex()
        vehicle:transmitRust()
    else
        vehicle:updateSkin()
    end

    dbg("painted " .. tostring(vehicle:getScript():getName()) .. " -> " .. key .. " (skin " .. self.skinIndex .. ")")
    return true
end

function PaintMyW900Action:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return PaintMyW900.getPaintTime(self.vehicle)
end

function PaintMyW900Action:new(character, vehicle, skinIndex)
    local o = ISBaseTimedAction.new(self, character)
    o.vehicle = vehicle
    o.skinIndex = skinIndex
    o.stopOnWalk = true
    o.stopOnRun = true
    o.caloriesModifier = 4
    o.maxTime = o:getDuration()
    return o
end
