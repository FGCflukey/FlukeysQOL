require "TimedActions/ISBaseTimedAction"
require "PaintVehicle_Shared"   -- shared weather/light/blood/key checks

local DEBUG = false
local function dbg(msg) if DEBUG then print("[SwapVehicle:Action] " .. tostring(msg)) end end

ISSwapVinylAction = ISBaseTimedAction:derive("ISSwapVinylAction")

------------------------------------------------------------
-- isValid(): runs BEFORE the action starts
------------------------------------------------------------
function ISSwapVinylAction:isValid()
    if not self.vehicle then return false end
    local sq = self.vehicle:getSquare()
    if not sq then return false end

    -- Weather / Light / Cleanliness / ownership gating
    if PaintVehicle.isBadWeather() then return false end
    if not PaintVehicle.hasEnoughLight(self.character) then return false end
    if PaintVehicle.isBloody(self.vehicle) then return false end
    if not PaintVehicle.hasVehicleKey(self.character, self.vehicle) then return false end

    -- Require SpraycanVinylCoat AND SandingBlock, anywhere in the inventory incl. bags
    -- (the server finds and uses them wherever they are)
    local inv = self.character:getInventory()
    local hasSpray = inv:containsTypeRecurse("Base.SpraycanVinylCoat")
    local hasSanding = inv:containsTypeRecurse("Base.SandingBlock")

    -- Also require a valid target script
    if not self.newScript or type(self.newScript) ~= "string" or self.newScript == "" then
        dbg("invalid newScript, aborting timed action")
        return false
    end

    return hasSpray and hasSanding
end

------------------------------------------------------------
-- update(): runs EVERY TICK during the action
------------------------------------------------------------
function ISSwapVinylAction:update()
    self.character:faceThisObject(self.vehicle)

    -- Mid‑action realism checks
    if PaintVehicle.isBadWeather() then
        self.character:Say("The weather changed!")
        self:forceStop()
        return
    end

    if not PaintVehicle.hasEnoughLight(self.character) then
        self.character:Say("It's too dark now!")
        self:forceStop()
        return
    end

    if PaintVehicle.isBloody(self.vehicle) then
        self.character:Say("I need to wash it first.")
        self:forceStop()
        return
    end

    -- Keep sound looping during the action
    local emitter = self.character:getEmitter()
    if emitter and self.sound and not emitter:isPlaying(self.sound) then
        self.sound = emitter:playSound("Sewing")
    end
end

------------------------------------------------------------
-- start(): animation + sound
------------------------------------------------------------
function ISSwapVinylAction:start()
    self.character:faceThisObject(self.vehicle)

    -- Vanilla's wall-painting animation (same as PaintMyW900), with the vinyl can in hand
    self:setActionAnim(CharacterActionAnims.Paint)
    local can = self.character:getInventory():getFirstTypeRecurse("Base.SpraycanVinylCoat")
    self:setOverrideHandModels(can, nil)

    -- Start sound
    local emitter = self.character:getEmitter()
    if emitter then
        self.sound = emitter:playSound("Sewing")
    end
end

------------------------------------------------------------
-- stop(): user cancelled or forcedStop()
------------------------------------------------------------
function ISSwapVinylAction:stop()
    local emitter = self.character:getEmitter()
    if emitter and self.sound then
        emitter:stopSound(self.sound)
    end

    ISBaseTimedAction.stop(self)
end

------------------------------------------------------------
-- perform(): action completes successfully
------------------------------------------------------------
function ISSwapVinylAction:perform()
    local emitter = self.character:getEmitter()
    if emitter and self.sound then
        emitter:stopSound(self.sound)
    end

    -- Safety: do not attempt swap if newScript is invalid
    if not self.newScript or type(self.newScript) ~= "string" or self.newScript == "" then
        dbg("perform() called with invalid newScript, aborting swap")
        ISBaseTimedAction.perform(self)
        return
    end

    -- Materials are consumed server-side in SwapVehicle_Server_Handle
    -- once it re-validates the request, so the cost can't be skipped
    -- by a client that sends the "Swap" command directly.

    -- Perform the actual vinyl swap
    SwapVehicle_Client.SendSwapRequest(self.character, self.vehicle, self.newScript)

    ISBaseTimedAction.perform(self)
end

------------------------------------------------------------
-- new()
------------------------------------------------------------
function ISSwapVinylAction:new(character, vehicle, newScript, time)
    local o = ISBaseTimedAction.new(self, character)
    o.vehicle   = vehicle
    o.newScript = newScript
    o.maxTime   = time or 600
    o.stopOnWalk = true
    o.stopOnRun  = true
    o.stopOnAim  = true
    return o
end
