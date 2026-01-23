require "TimedActions/ISBaseTimedAction"

VehicleLockpickTimedAction = ISBaseTimedAction:derive("VehicleLockpickTimedAction")

local function unlockVehicleDoor(player, vehicle, part)
    if not vehicle or not part then return end

    local door = part:getDoor()
    if not door then
        player:Say("Can't find door mechanism.")
        return
    end

    -- Attempt unlock
    door:setLocked(false)

    -- Optional: unlock trunk
    local trunk = vehicle:getPartById("TrunkDoor")
    if trunk and trunk:getDoor() then
        trunk:getDoor():setLocked(false)
    end

    -- Verify unlock
    if door:isLocked() then
        -- Fallback: send client command
        sendClientCommand(player, "vehicle", "setDoorLocked", {
            vehicle = vehicle:getId(),
            part = part:getId(),
            locked = false
        })

        -- Recheck after sync
        if door:isLocked() then
            player:Say("Still locked... something's off.")
            return
        end
    end

    -- Success
    vehicle:playPartSound(part, player, "Unlock")
end

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
    local emitter = self.character:getEmitter()

    -- Failure chance (20%)
    if ZombRand(100) < 20 then
        if emitter then emitter:playSound("FailedPickLock", self.vehicle) end
        self.character:Say("The paperclip snapped.")

        -- Remove one paperclip
        local inv = self.character:getInventory()
        local pc = inv:getFirstTypeRecurse("Paperclip")
        if pc then inv:Remove(pc) end

        ISBaseTimedAction.perform(self)
        return
    end

    -- Success
    if emitter then emitter:playSound("PickLock", self.vehicle) end
    self.character:Say("Unlocked.")

    unlockVehicleDoor(self.character, self.vehicle, self.part)

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