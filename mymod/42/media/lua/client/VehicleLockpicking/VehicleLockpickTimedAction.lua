require "TimedActions/ISBaseTimedAction"

-- This used to mutate door/trunk lock state directly on the client
-- (door:setLocked(false), no server involvement) and, on the rare
-- failure-to-stick path, sent a fallback command to module "vehicle"
-- command "setDoorLocked" -- which isn't a real vanilla server command
-- (grepped the whole vanilla server lua tree, no handler exists). So
-- the common/successful case never told the server anything: the
-- client showed "unlocked" as a pure local prediction, but the
-- server's real vehicle-part lock state (which actually gates trunk/
-- container access) never changed -- surfaced as "trunk shows unlocked
-- but the container never shows up until you toggle the real vanilla
-- lock from the driver's seat." All of that now lives server-side in
-- VehicleLockpicking_Server.lua -- this file just requests it and
-- reports the result.
VehicleLockpickTimedAction = ISBaseTimedAction:derive("VehicleLockpickTimedAction")

function VehicleLockpickTimedAction:isValid()
    return true
end

function VehicleLockpickTimedAction:update()
    self.character:faceThisObject(self.vehicle)
end

function VehicleLockpickTimedAction:waitToStart()
    self.character:faceThisObject(self.vehicle)
    return self.character:shouldBeTurning()
end

function VehicleLockpickTimedAction:start()
    self:setActionAnim(CharacterActionAnims.InsertBullets)

    local emitter = self.character:getEmitter()
    if emitter then
        emitter:playSound("PickLock", self.vehicle)
    end
end

function VehicleLockpickTimedAction:stop()
    ISBaseTimedAction.stop(self)
end

function VehicleLockpickTimedAction:perform()
    -- No local roll, no local setLocked() -- the server is the only
    -- place that decides success/failure and actually mutates the
    -- door/trunk lock state now. This is just the request; feedback
    -- (sound, Say(), paperclip breaking) comes back via lockpickResult
    -- below, same "request now, react to the server's real answer"
    -- pattern this pack's other server-authoritative mods use.
    sendClientCommand(self.character, "VehicleLockpicking", "attemptUnlock", {
        vehicleId = self.vehicle:getId(),
        partId    = self.part:getId(),
    })

    ISBaseTimedAction.perform(self)
end

function VehicleLockpickTimedAction:new(character, vehicle, part, time)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.character = character
    o.vehicle = vehicle
    o.part = part
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = time

    return o
end

---------------------------------------------------------
-- Server's authoritative result comes back here -- feedback only,
-- the actual lock/trunk state and paperclip removal already happened
-- server-side by the time this fires.
---------------------------------------------------------
local function OnServerCommand(module, command, args)
    if module ~= "VehicleLockpicking" or command ~= "lockpickResult" then return end

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