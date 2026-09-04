require("TimedActions/ISBaseTimedAction")

-- Repair a jammed vehicle door lock with a paperclip (door:isLockBroken()).
--
-- Structure mirrors VLMRepairVehicleLock exactly: real work happens in complete(),
-- perform() is a trivial passthrough. Door lock state is not modData -- it lives on
-- the vanilla door object and syncs via vehicle:transmitPartDoor(part), the engine's
-- own authoritative client->server->broadcast call.

RepairCarLockAction = ISBaseTimedAction:derive("RepairCarLockAction")

local function getLockRepairFailChance(player)
    local mech = player:getPerkLevel(Perks.Mechanics)

    if mech >= 8 then
        return 20
    elseif mech >= 6 then
        return 50
    else
        return 70
    end
end

function RepairCarLockAction:isValid()
    if not self.part or not self.vehicle then
        return false
    end
    local door = self.part:getDoor()
    return door ~= nil and door:isLockBroken()
end

function RepairCarLockAction:waitToStart()
    if self.character:getVehicle() then
        return false
    end
    self.character:faceThisObject(self.vehicle)
    return self.character:shouldBeTurning()
end

function RepairCarLockAction:update()
    if not self.character:getVehicle() then
        self.character:faceThisObject(self.vehicle)
    end
end

function RepairCarLockAction:start()
    self:setActionAnim("VehicleWorkOnMid")
end

function RepairCarLockAction:stop()
    ISBaseTimedAction.stop(self)
end

function RepairCarLockAction:perform()
    ISBaseTimedAction.perform(self)
end

function RepairCarLockAction:complete()
    local player = self.character
    local vehicle = self.vehicle
    local part = self.part

    local door = part and part:getDoor()
    if not door then
        return false
    end

    -- Re-check at completion time, matching VLM: someone else may have fixed or
    -- re-broken this door since the action was queued.
    if not door:isLockBroken() then
        return false
    end

    local failChance = getLockRepairFailChance(player)
    local failed = ZombRand(100) < failChance

    if failed then
        player:Say("I messed it up...")

        local inv = player:getInventory()
        local paperclip = inv:getFirstEvalRecurse(function(item)
            return item:getType() == "Paperclip"
        end)

        if paperclip then
            local container = paperclip:getContainer()
            if container then
                container:Remove(paperclip)
            end
            player:Say("The paperclip snapped.")

            local emitter = player:getEmitter()
            if emitter then
                emitter:playSound("FailedPickLock")
            end
        end
    else
        door:setLockBroken(false)
        vehicle:transmitPartDoor(part)
        player:Say("I repaired the Lock!")
    end

    return true
end

function RepairCarLockAction:getDuration()
    if not self.character then
        return self.workTime or 300
    end
    if self.character:isMechanicsCheat() or self.character:isTimedActionInstant() then
        return 1
    end
    return self.workTime - (self.character:getPerkLevel(Perks.Mechanics) * (self.workTime / 15))
end

function RepairCarLockAction:new(character, part)
    local o = ISBaseTimedAction.new(self, character)
    o.part = part
    if part ~= nil then
        o.vehicle = part:getVehicle()
    end
    o.workTime = 300
    o.jobType = "Repairing Lock"
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end