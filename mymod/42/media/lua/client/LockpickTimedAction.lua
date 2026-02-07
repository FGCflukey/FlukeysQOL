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
    self:setActionAnim(CharacterActionAnims.InsertBullets)

    local emitter = self.character:getEmitter()
    if emitter then
        emitter:playSound("PickLock", self.door)
    end
end

function LockpickTimedAction:stop()
    -- Interrupted: do NOT run success/fail logic
    ISBaseTimedAction.stop(self)
end

function LockpickTimedAction:perform()
    local emitter = self.character:getEmitter()

    if ZombRand(100) < 40 then
        if emitter then emitter:playSound("FailedPickLock", self.door) end
        self.character:Say("The paperclip snapped.")
        self.onFail(self.character, self.door)
    else
        if emitter then emitter:playSound("PickLock", self.door) end
        self.character:Say("Unlocked.")
        self.onSuccess(self.character, self.door)
    end

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