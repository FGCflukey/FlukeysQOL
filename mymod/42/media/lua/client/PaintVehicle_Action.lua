-- PaintVehicle_Action.lua
-- Timed action for spraycan-based vehicle repainting

require "TimedActions/ISBaseTimedAction"

-----------------------------------------------------
-- LARGE VEHICLE CHECK
-----------------------------------------------------
local function PV_isLargeVehicle(name)
    if not name then return false end
    return string.find(name, "Van")
        or string.find(name, "Truck")
        or string.find(name, "Pickup")
        or string.find(name, "SUV")
end

-----------------------------------------------------
-- TIMED ACTION CLASS
-----------------------------------------------------
ISPaintVehicleAction = ISBaseTimedAction:derive("ISPaintVehicleAction")

function ISPaintVehicleAction:isValid()
    if not self.vehicle or self.vehicle:isRemovedFromWorld() then return false end
    if not self.character or self.character:isDead() then return false end

    if self.spraycan then
        if self.spraycan:getCurrentUses() <= 0 then return false end
        if not self.character:getInventory():contains(self.spraycan) then return false end
    end

    return true
end

function ISPaintVehicleAction:start()
    -- Face the vehicle
    self.character:faceThisObject(self.vehicle)

    -- Animation
    self:setActionAnim("Craft")
    self.character:SetVariable("CraftingType", "Spraycan")

    -- Play shake sound (WaterPour)
    local emitter = self.character:getEmitter()
    if emitter then
        emitter:playSound("WaterPour")
    end

    -- Start looping spray sound (PaintVehicleSpray)
    if emitter then
        self.loopSound = emitter:playSound("PaintVehicleSpray")
    end
end

function ISPaintVehicleAction:update()
    -- Keep facing the vehicle
    self.character:faceThisObject(self.vehicle)

    -- Restart spray sound if it stops
    local emitter = self.character:getEmitter()
    if emitter and self.loopSound and not emitter:isPlaying(self.loopSound) then
        self.loopSound = emitter:playSound("PaintVehicleSpray")
    end
end

function ISPaintVehicleAction:stop()
    -- Stop looping spray sound
    local emitter = self.character:getEmitter()
    if emitter and self.loopSound then
        emitter:stopSound(self.loopSound)
    end

    ISBaseTimedAction.stop(self)
end

function ISPaintVehicleAction:perform()
    -- Stop looping spray sound
    local emitter = self.character:getEmitter()
    if emitter and self.loopSound then
        emitter:stopSound(self.loopSound)
    end

    -- Apply color
    if self.hsv and self.vehicle then
        self.vehicle:setColorHSV(self.hsv[1], self.hsv[2], self.hsv[3])
        self.vehicle:transmitColorHSV()
    end

    -- Consume spraycan
    if self.spraycan then
        local maxUses = self.spraycan:getMaxUses()
        local before  = self.spraycan:getCurrentUses()

        local drainAmount = PV_isLargeVehicle(self.scriptName) and 1.0 or 0.5
        local drainUses   = math.floor(maxUses * drainAmount + 0.001)

        local after = math.max(0, before - drainUses)
        self.spraycan:setCurrentUses(after)

        if after <= 0 then
            self.character:getInventory():Remove(self.spraycan)
        end
    end

    -- Close context menus
    if ISContextMenu.instance then
        ISContextMenu.closeAll()
    end

    ISBaseTimedAction.perform(self)
end

function ISPaintVehicleAction:new(character, vehicle, hsv, spraycan, scriptName)
    local o = ISBaseTimedAction.new(self, character)
    o.character   = character
    o.vehicle     = vehicle
    o.hsv         = hsv
    o.spraycan    = spraycan
    o.scriptName  = scriptName

    -- 10 seconds (600 ticks)
    o.maxTime     = 600

    o.stopOnWalk  = true
    o.stopOnRun   = true
    o.useProgressBar = true
    return o
end