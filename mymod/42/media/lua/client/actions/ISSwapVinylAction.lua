ISSwapVinylAction = ISBaseTimedAction:derive("ISSwapVinylAction")

------------------------------------------------------------
-- Shared realism helpers (same as paint system)
------------------------------------------------------------

local function PV_isBadWeather()
    local climate = getClimateManager()

    if climate:getRainIntensity() > 0 then return true end
    if climate:getSnowIntensity() > 0 then return true end
    if climate:getFogIntensity() > 0 then return true end

    local storm = climate:getThunderStorm()
    if storm and storm.active then return true end

    return false
end

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

local function PV_hasVehicleKey(character, vehicle)
    local keyId = vehicle:getKeyId()
    if not keyId or keyId == -1 then return true end

    -- Same check vanilla uses (VehicleUtils.RequiredKeyNotFound) --
    -- a manual getFirstTypeEvalRecurse("Key", ...) search is fragile
    -- since it depends on the key item's exact getType() string.
    return character:getInventory():haveThisKeyId(keyId)
end

------------------------------------------------------------
-- isValid(): runs BEFORE the action starts
------------------------------------------------------------
function ISSwapVinylAction:isValid()
    if not self.vehicle then return false end
    local sq = self.vehicle:getSquare()
    if not sq then return false end

    -- Weather / Light / Cleanliness / ownership gating
    if PV_isBadWeather() then return false end
    if not PV_hasEnoughLight(self.character) then return false end
    if PV_vehicleIsBloody(self.vehicle) then return false end
    if not PV_hasVehicleKey(self.character, self.vehicle) then return false end

    -- Require SpraycanVinylCoat AND SandingBlock (main inventory only)
    local inv = self.character:getInventory()
    local hasSpray = inv:contains("SpraycanVinylCoat")
    local hasSanding = inv:contains("SandingBlock")

    -- Also require a valid target script
    if not self.newScript or type(self.newScript) ~= "string" or self.newScript == "" then
        print("[ISSwapVinylAction] Invalid newScript, aborting timed action")
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
    if PV_isBadWeather() then
        self.character:Say("The weather changed!")
        self:forceStop()
        return
    end

    if not PV_hasEnoughLight(self.character) then
        self.character:Say("It's too dark now!")
        self:forceStop()
        return
    end

    if PV_vehicleIsBloody(self.vehicle) then
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
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")

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
        print("[ISSwapVinylAction] perform() called with invalid newScript, aborting swap")
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
