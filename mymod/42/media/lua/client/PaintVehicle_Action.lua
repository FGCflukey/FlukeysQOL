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

    -- Must have spraycan
    if self.spraycan then
        if self.spraycan:getCurrentUses() <= 0 then return false end
        if not self.character:getInventory():contains(self.spraycan) then return false end
    end

    -- Must have sanding block
    if not self.character:getInventory():contains("SandingBlock") then
        return false
    end

    return true
end

function ISPaintVehicleAction:start()
    self.character:faceThisObject(self.vehicle)

    self:setActionAnim("Craft")
    self.character:SetVariable("CraftingType", "Spraycan")

    local emitter = self.character:getEmitter()
    if emitter then
        emitter:playSound("WaterPour")
        self.loopSound = emitter:playSound("PaintVehicleSpray")
    end
end

function ISPaintVehicleAction:update()
    self.character:faceThisObject(self.vehicle)

    local emitter = self.character:getEmitter()
    if emitter and self.loopSound and not emitter:isPlaying(self.loopSound) then
        self.loopSound = emitter:playSound("PaintVehicleSpray")
    end
end

function ISPaintVehicleAction:stop()
    local emitter = self.character:getEmitter()
    if emitter and self.loopSound then
        emitter:stopSound(self.loopSound)
    end

    ISBaseTimedAction.stop(self)
end

function ISPaintVehicleAction:perform()
    local emitter = self.character:getEmitter()
    if emitter and self.loopSound then
        emitter:stopSound(self.loopSound)
    end

    -- Apply color
    if self.hsv and self.vehicle then
        self.vehicle:setColorHSV(self.hsv[1], self.hsv[2], self.hsv[3])
        self.vehicle:transmitColorHSV()
    end

    -----------------------------------------------------
    -- CLEAN VEHICLE AFTER PAINTING (SERVER-SAFE VERSION)
    -----------------------------------------------------
    local v = self.vehicle
    if v and v:getId() then
        local sv = getVehicleById(v:getId())

        if sv then
            -- Blood
            if sv.setBloodIntensity and sv.getPartList then
                local parts = sv:getPartList()
                if parts then
                    for i = 0, parts:size() - 1 do
                        local part = parts:get(i)
                        if part and part:getId() then
                            sv:setBloodIntensity(part:getId(), 0)
                        end
                    end
                end
                if sv.transmitBlood then sv:transmitBlood() end
            end

            -- Dirt
            if sv.setDirt then
                sv:setDirt(0)
                if sv.transmitDirt then sv:transmitDirt() end
            end

            -- Rust
            if sv.setRust then
                sv:setRust(0)
                if sv.transmitRust then sv:transmitRust() end
            end
        end
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

    o.maxTime     = 600
    o.stopOnWalk  = true
    o.stopOnRun   = true
    o.useProgressBar = true
    return o
end