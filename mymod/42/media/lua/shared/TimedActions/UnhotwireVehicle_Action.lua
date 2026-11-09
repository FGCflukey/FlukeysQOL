require "TimedActions/ISBaseTimedAction"

-- UnhotwireVehicle: the driver of a hotwired car can strip the hotwire back out,
-- so the car needs a key again. Our own build, informed by reading the Workshop mod
-- "Custom Hotwire Car" (3789954867).
--
-- Server-authoritative: the state change happens in complete(), which in B42 runs on
-- the server, using vanilla's own vehicle:cheatHotwire(hotwired, broken) -- the same
-- call vanilla's server-side "cheatHotwire" command makes (server/Vehicles/VehicleCommands.lua).
-- This file lives in shared/ so the server has the action class too.
--
-- Constructor takes only the character, and the vehicle is read from
-- character:getVehicle() at each step, so the server rebuilds it from the same data.

local DEBUG = false
local function dbg(msg) if DEBUG then print("[UnhotwireVehicle] " .. tostring(msg)) end end

UnhotwireVehicle = UnhotwireVehicle or {}

local DEFAULT_ELECTRICAL = 2
local DEFAULT_MECHANICS = 3

local function sandboxLevel(name, fallback)
    local opts = SandboxVars and SandboxVars.UnhotwireVehicle
    local value = opts and tonumber(opts[name])
    if value == nil then return fallback end
    return math.max(0, math.min(10, math.floor(value)))
end

function UnhotwireVehicle.getRequirements()
    return sandboxLevel("ElectricalLevel", DEFAULT_ELECTRICAL),
           sandboxLevel("MechanicsLevel", DEFAULT_MECHANICS)
end

-- Show the option: driver, engine off, car stopped, and a working (not broken) hotwire
function UnhotwireVehicle.canShow(character, vehicle)
    if not character or not vehicle then return false end
    if character:getVehicle() ~= vehicle or not vehicle:isDriver(character) then return false end
    if vehicle:isEngineStarted() or vehicle:isEngineRunning() then return false end
    if not vehicle:isStopped() then return false end
    return vehicle:isHotwired() and not vehicle:isHotwiredBroken()
end

function UnhotwireVehicle.hasSkills(character)
    local elec, mech = UnhotwireVehicle.getRequirements()
    return character:getPerkLevel(Perks.Electricity) >= elec and
           character:getPerkLevel(Perks.Mechanics) >= mech
end

function UnhotwireVehicle.canDo(character, vehicle)
    return UnhotwireVehicle.canShow(character, vehicle) and UnhotwireVehicle.hasSkills(character)
end

UnhotwireVehicleAction = ISBaseTimedAction:derive("UnhotwireVehicleAction")

function UnhotwireVehicleAction:isValid()
    return UnhotwireVehicle.canDo(self.character, self.character:getVehicle())
end

function UnhotwireVehicleAction:update()
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
end

function UnhotwireVehicleAction:start()
    self.sound = self.character:getEmitter():playSound("VehicleHotwireStart")
end

function UnhotwireVehicleAction:stopSound()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
end

function UnhotwireVehicleAction:stop()
    self:stopSound()
    ISBaseTimedAction.stop(self)
end

function UnhotwireVehicleAction:perform()
    self:stopSound()
    ISBaseTimedAction.perform(self)
end

function UnhotwireVehicleAction:complete()
    local vehicle = self.character:getVehicle()
    -- Re-check at completion: engine may have been started, or someone else changed it
    if not UnhotwireVehicle.canDo(self.character, vehicle) then
        dbg("complete: conditions no longer met, nothing changed")
        return false
    end
    vehicle:cheatHotwire(false, false)
    dbg("complete: hotwire removed from vehicle id=" .. tostring(vehicle:getId()) ..
        " hotwired=" .. tostring(vehicle:isHotwired()) .. " broken=" .. tostring(vehicle:isHotwiredBroken()))
    return true
end

-- Same timing as vanilla hotwiring
function UnhotwireVehicleAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 200 - (self.character:getPerkLevel(Perks.Electricity) * 3)
end

function UnhotwireVehicleAction:new(character)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnWalk = false
    o.stopOnRun = false
    o.maxTime = o:getDuration()
    return o
end
