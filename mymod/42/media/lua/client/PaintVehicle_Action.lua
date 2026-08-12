-- PaintVehicle_Action.lua
-- Timed action for spraycan-based vehicle repainting

require "TimedActions/ISBaseTimedAction"

-----------------------------------------------------
-- WEATHER CHECK
-----------------------------------------------------
local function PV_isBadWeather()
    local climate = getClimateManager()

    if climate:getRainIntensity() > 0 then return true end
    if climate:getSnowIntensity() > 0 then return true end
    if climate:getFogIntensity() > 0 then return true end

    -- Thunderstorm detection (compatible with your build)
    local storm = climate:getThunderStorm()
    if storm and storm.active then return true end

    return false
end

-----------------------------------------------------
-- LIGHTING CHECK
-----------------------------------------------------
local function PV_hasEnoughLight(character)
    local square = character:getSquare()
    if not square then return false end

    local playerIndex = character:getPlayerNum()

    -- Indoors: must have some light
    if not square:isOutside() then
        return square:getLightLevel(playerIndex) > 0.3
    end

    -- Outdoors
    local climate = getClimateManager()
    local isNight = climate:getNightStrength() > 0.5

    -- Daytime outdoors always OK
    if not isNight then
        return true
    end

    -- Night outdoors: must have strong artificial light
    return square:getLightLevel(playerIndex) > 0.6
end

-----------------------------------------------------
-- CLIMATE DEBUG
-----------------------------------------------------
local function PV_debugClimate()
    local c = getClimateManager()
    print("---- Climate Debug ----")
    print("Rain:", c:getRainIntensity())
    print("Snow:", c:getSnowIntensity())
    print("Fog:", c:getFogIntensity())
    print("Storm:", c:getThunderStorm())
    print("NightStrength:", c:getNightStrength())
    print("------------------------")
end

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
-- BLOOD CLEANLINESS CHECK
-----------------------------------------------------
local function PV_vehicleIsBloody(vehicle)
    if not vehicle or not vehicle.getBloodIntensity then
        return false
    end

    if vehicle:getBloodIntensity("Front") > 0 then return true end
    if vehicle:getBloodIntensity("Rear") > 0 then return true end
    if vehicle:getBloodIntensity("Left") > 0 then return true end
    if vehicle:getBloodIntensity("Right") > 0 then return true end

    return false
end

-----------------------------------------------------
-- TIMED ACTION CLASS
-----------------------------------------------------
ISPaintVehicleAction = ISBaseTimedAction:derive("ISPaintVehicleAction")

function ISPaintVehicleAction:isValid()
    if not self.vehicle or self.vehicle:isRemovedFromWorld() then return false end
    if not self.character or self.character:isDead() then return false end

    -----------------------------------------------------
    -- REQUIRED ITEMS FIRST
    -----------------------------------------------------
    if self.spraycan then
        if self.spraycan:getCurrentUses() <= 0 then return false end
        if not self.character:getInventory():contains(self.spraycan) then return false end
    end

    if not self.character:getInventory():contains("SandingBlock") then
        return false
    end

    -----------------------------------------------------
    -- WEATHER BLOCK
    -----------------------------------------------------

    -- PV_debugClimate()  -- DEBUG PRINT

    if PV_isBadWeather() then
        self.character:Say("The weather is too bad to paint.")
        return false
    end

    -----------------------------------------------------
    -- LIGHT BLOCK
    -----------------------------------------------------
    if not PV_hasEnoughLight(self.character) then
        self.character:Say("I need more light to paint.")
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

    if PV_vehicleIsBloody(self.vehicle) then
        self.character:Say("I think I should wash it first.")
        self:forceStop()
        return
    end

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

    if self.hsv and self.vehicle then
        self.vehicle:setColorHSV(self.hsv[1], self.hsv[2], self.hsv[3])
        self.vehicle:transmitColorHSV()
    end

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
