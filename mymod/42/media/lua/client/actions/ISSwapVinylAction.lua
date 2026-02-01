ISSwapVinylAction = ISBaseTimedAction:derive("ISSwapVinylAction")

function ISSwapVinylAction:isValid()
    if not self.vehicle then return false end
    local sq = self.vehicle:getSquare()
    if not sq then return false end
    return true
end

function ISSwapVinylAction:update()
    self.character:faceThisObject(self.vehicle)
end

function ISSwapVinylAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
end

function ISSwapVinylAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISSwapVinylAction:perform()
    SwapVehicle_Client.SendSwapRequest(self.character, self.vehicle, self.newScript)
    ISBaseTimedAction.perform(self)
end

function ISSwapVinylAction:new(character, vehicle, newScript, time)
    local o = ISBaseTimedAction.new(self, character)
    o.vehicle = vehicle
    o.newScript = newScript
    o.maxTime = time or 600
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
    return o
end