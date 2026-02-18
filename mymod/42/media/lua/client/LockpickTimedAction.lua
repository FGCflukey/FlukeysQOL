require "TimedActions/ISBaseTimedAction"

LockpickTimedAction = ISBaseTimedAction:derive("LockpickTimedAction")

-- Mechanics-based success chance
local function getLockpickSuccessChance(player)
    local mech = player:getPerkLevel(Perks.Mechanics)

    if mech <= 2 then
        return 15
    elseif mech <= 4 then
        return 45
    elseif mech <= 8 then
        return 75
    else
        return 100
    end
end

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

    local chance = getLockpickSuccessChance(self.character)
    local roll = ZombRand(100)

    if roll < chance then
        if emitter then emitter:playSound("PickLock", self.door) end
        self.character:Say("Unlocked.")
        self.onSuccess(self.character, self.door)
    else
        if emitter then emitter:playSound("FailedPickLock", self.door) end
        self.character:Say("The lock resisted.")

        -- 35% chance to break the paperclip
        local breakChance = 35
        local breakRoll = ZombRand(100)

        if breakRoll < breakChance then
            self.character:Say("The paperclip snapped.")
            self.onFail(self.character, self.door)
        else
            self.character:Say("The paperclip held.")
        end
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