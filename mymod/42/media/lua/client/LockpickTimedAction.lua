require "TimedActions/ISBaseTimedAction"

LockpickTimedAction = ISBaseTimedAction:derive("LockpickTimedAction")

function LockpickTimedAction:isValid()
    return true
end

function LockpickTimedAction:update()
    self.character:faceThisObject(self.door)
end

function LockpickTimedAction:waitToStart()
    self.character:faceThisObject(self.door)
    return self.character:shouldBeTurning()
end

function LockpickTimedAction:start()
    -- Animation
    self:setActionAnim(CharacterActionAnims.InsertBullets)

    -- Start sound
    local emitter = self.character:getEmitter()
    if emitter then
        emitter:playSound("PickLock", self.door)
    end
end

function LockpickTimedAction:stop()
    ISBaseTimedAction.stop(self)
end

function LockpickTimedAction:perform()
    local emitter = self.character:getEmitter()

    -- Failure chance
    if ZombRand(100) < 20 then
        if emitter then emitter:playSound("FailedPickLock", self.door) end
        self.character:Say("The paperclip snapped.")
        self.onFail(self.character, self.door)
        ISBaseTimedAction.perform(self)
        return
    end

    -- Success
    if emitter then emitter:playSound("PickLock", self.door) end
    self.character:Say("Unlocked.")
    self.onSuccess(self.character, self.door)

    ISBaseTimedAction.perform(self)
end

function LockpickTimedAction:new(character, door, time, onSuccess, onFail)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.character = character
    o.door = door
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = time
    o.onSuccess = onSuccess
    o.onFail = onFail

    return o
end