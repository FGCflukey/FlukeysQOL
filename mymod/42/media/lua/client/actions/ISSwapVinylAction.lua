ISSwapVinylAction = ISBaseTimedAction:derive("ISSwapVinylAction")

function ISSwapVinylAction:isValid()
    if not self.vehicle then
--        print("DEBUG: isValid() → vehicle is NIL")
        return false
    end

    local sq = self.vehicle:getSquare()
    if not sq then
--        print("DEBUG: isValid() → vehicle:getSquare() is NIL for vehicle ID:", self.vehicle:getId())
        return false
    end

--    print("DEBUG: isValid() → VALID for vehicle ID:", self.vehicle:getId())
    return true
end

function ISSwapVinylAction:update()
    self.character:faceThisObject(self.vehicle)
end

function ISSwapVinylAction:start()
--    print("DEBUG: start() called for vehicle ID:", self.vehicle and self.vehicle:getId())
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
end

function ISSwapVinylAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISSwapVinylAction:perform()
    -- Correct function call for your mod
    SwapVehicle_Client.SendSwapRequest(self.character, self.vehicle, self.newScript)

    ISBaseTimedAction.perform(self)
end

function ISSwapVinylAction:new(character, vehicle, newScript, time)
--    print("DEBUG: new() → vehicle:", vehicle, "script:", newScript)
    local o = ISBaseTimedAction.new(self, character)
    o.vehicle = vehicle
    o.newScript = newScript
    o.maxTime = time or 600
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
    return o
end