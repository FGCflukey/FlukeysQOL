-- PaintVehicle_Action.lua
-- Timed action for spraycan-based vehicle repainting.
-- The color + spraycan use are applied by the server (PaintVehicle_Server.lua).

require "TimedActions/ISBaseTimedAction"
require "PaintVehicle_Shared"

local DEBUG = false
local function dbg(msg) if DEBUG then print("[PaintVehicle:Action] " .. tostring(msg)) end end

ISPaintVehicleAction = ISBaseTimedAction:derive("ISPaintVehicleAction")

-- The menu moves the spraycan + sanding block out of any bag before queueing this
-- (ISInventoryPaneContextMenu.transferIfNeeded), so a top-level contains() is correct here.
function ISPaintVehicleAction:isValid()
    if not self.vehicle or self.vehicle:isRemovedFromWorld() then return false end
    if not self.character or self.character:isDead() then return false end

    local inv = self.character:getInventory()
    if not self.spraycan or not inv:contains(self.spraycan) then return false end
    if not inv:containsTypeRecurse(PaintVehicle.SANDING_BLOCK) then return false end

    if not PaintVehicle.hasVehicleKey(self.character, self.vehicle) then
        self.character:Say("I don't have the key to this car.")
        return false
    end
    if PaintVehicle.isBadWeather() then
        self.character:Say("The weather is too bad to paint.")
        return false
    end
    if not PaintVehicle.hasEnoughLight(self.character) then
        self.character:Say("I need more light to paint.")
        return false
    end
    return true
end

-- Attracts zombies, like any loud work
function ISPaintVehicleAction:makeNoise()
    local c = self.character
    addSound(c, c:getX(), c:getY(), c:getZ(), PaintVehicle.NOISE_RADIUS, PaintVehicle.NOISE_VOLUME)
    self.lastNoise = getTimestampMs()
end

function ISPaintVehicleAction:start()
    self.character:faceThisObject(self.vehicle)

    -- Vanilla's wall-painting animation (same as PaintMyW900), but with the can in hand
    self:setActionAnim(CharacterActionAnims.Paint)
    self:setOverrideHandModels(self.spraycan, nil)

    local emitter = self.character:getEmitter()
    if emitter then
        emitter:playSound("WaterPour")
        self.loopSound = emitter:playSound("PaintVehicleSpray")
    end

    self:makeNoise()
    dbg("start: " .. tostring(self.spraycan:getFullType()) .. " maxTime=" .. tostring(self.maxTime))
end

function ISPaintVehicleAction:update()
    self.character:faceThisObject(self.vehicle)

    if PaintVehicle.isBloody(self.vehicle) then
        self.character:Say("I think I should wash it first.")
        self:forceStop()
        return
    end

    local emitter = self.character:getEmitter()
    if emitter and self.loopSound and not emitter:isPlaying(self.loopSound) then
        self.loopSound = emitter:playSound("PaintVehicleSpray")
    end

    if getTimestampMs() - (self.lastNoise or 0) >= PaintVehicle.NOISE_EVERY_MS then
        self:makeNoise()
    end
end

function ISPaintVehicleAction:stopSound()
    local emitter = self.character:getEmitter()
    if emitter and self.loopSound then
        emitter:stopSound(self.loopSound)
    end
end

function ISPaintVehicleAction:stop()
    self:stopSound()
    ISBaseTimedAction.stop(self)
end

function ISPaintVehicleAction:perform()
    self:stopSound()

    if isClient() then
        -- MP: the server applies the color and uses up the spraycan on its own
        -- authoritative copies so both actually persist. The server works out the
        -- color from the spraycan itself; the client only says which can.
        sendClientCommand(self.character, "PaintVehicle", "paint", {
            vehicleID  = self.vehicle:getId(),
            spraycanID = self.spraycan:getID(),
        })
    else
        -- Solo / hosting as the server: safe to change directly.
        local color = PaintVehicle.COLORS[PaintVehicle.BY_ITEM[self.spraycan:getFullType()] or ""]
        if color then
            self.vehicle:setColorHSV(color.hsv[1], color.hsv[2], color.hsv[3])
            self.vehicle:transmitColorHSV()
        end
        -- One can per repaint, regardless of vehicle size (same rule as the vinyl swap system)
        local container = self.spraycan:getContainer() or self.character:getInventory()
        container:Remove(self.spraycan)
    end

    if ISContextMenu.instance then
        ISContextMenu.closeAll()
    end

    ISBaseTimedAction.perform(self)
end

function ISPaintVehicleAction:new(character, vehicle, spraycan)
    local o = ISBaseTimedAction.new(self, character)
    o.character      = character
    o.vehicle        = vehicle
    o.spraycan       = spraycan
    o.maxTime        = PaintVehicle.getPaintTime(vehicle)
    o.stopOnWalk     = true
    o.stopOnRun      = true
    o.useProgressBar = true
    return o
end
