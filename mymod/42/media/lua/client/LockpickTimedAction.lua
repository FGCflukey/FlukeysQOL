require "TimedActions/ISBaseTimedAction"

-- This used to roll success chance and mutate door lock flags entirely
-- client-side (onSuccess/onFail callbacks invoked locally in perform(),
-- no server involvement at all) -- same architectural gap
-- VehicleLockpicking had. All of that now lives server-side in
-- Lockpicking_Server.lua, which re-derives the same door cluster from
-- the square coords this file sends; this file just requests it and
-- reports the result.
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
    ISBaseTimedAction.stop(self)
end

function LockpickTimedAction:perform()
    -- No local roll, no local door mutation -- the server is the only
    -- place that decides success/failure and actually unlocks the
    -- door cluster now. This is just the request; feedback (sound,
    -- Say(), paperclip breaking) comes back via lockpickResult below.
    sendClientCommand(self.character, "Lockpicking", "attemptPickLock", {
        x = self.square:getX(),
        y = self.square:getY(),
        z = self.square:getZ(),
    })

    ISBaseTimedAction.perform(self)
end

function LockpickTimedAction:new(character, door, square, time)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.character = character
    o.door = door
    o.square = square
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = time

    return o
end

---------------------------------------------------------
-- Server's authoritative result comes back here -- feedback only,
-- the actual door unlocking and paperclip removal already happened
-- server-side by the time this fires.
---------------------------------------------------------
local function OnServerCommand(module, command, args)
    if module ~= "Lockpicking" or command ~= "lockpickResult" then return end

    local player = getSpecificPlayer(0)
    if not player then return end

    local emitter = player:getEmitter()

    if args.success then
        if emitter then emitter:playSound("PickLock") end
        player:Say("Unlocked.")
    else
        if emitter then emitter:playSound("FailedPickLock") end
        if args.broke then
            player:Say("The paperclip snapped.")
        else
            player:Say("The lock resisted.")
        end
    end
end
Events.OnServerCommand.Add(OnServerCommand)
