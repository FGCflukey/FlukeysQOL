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

function RepairCarLockAction:new(player, vehicle, part)
    local o = ISBaseTimedAction.new(self, player)
    o.character = player
    o.vehicle = vehicle
    o.partID = part:getId()
    o.maxTime = 300
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end

function RepairCarLockAction:isValid()
    return self.character ~= nil and self.vehicle ~= nil
end

function RepairCarLockAction:start()
    self:setActionAnim("VehicleWorkOnMid")
    self.character:reportEvent("EventRepair")
end

function RepairCarLockAction:update()
    self.character:faceThisObject(self.vehicle)
end

function RepairCarLockAction:perform()
    local player = self.character
    local vehicle = self.vehicle

    if not vehicle then
        ISBaseTimedAction.perform(self)
        return
    end

    local part = vehicle:getPartById(self.partID)
    if not part then
        player:Say("The door part vanished?")
        ISBaseTimedAction.perform(self)
        return
    end

    local door = part:getDoor()
    local md = part:getModData()

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
                emitter:playSound("FailedPickLock")  -- same name as in your picklocks mod
            end
        end
    else
        if door and type(door.setLockBroken) == "function" then
            door:setLockBroken(false)
        end

        md.LockBroken = false

        if vehicle.transmitPartModData then
            vehicle:transmitPartModData(part)
        elseif part.transmitModData then
            part:transmitModData()
        end

        player:Say("I repaired the Lock!")
    end

    ISBaseTimedAction.perform(self)
end