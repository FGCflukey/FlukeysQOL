ISSwapVinylAction = ISBaseTimedAction:derive("ISSwapVinylAction")

function ISSwapVinylAction:isValid()
    if not self.vehicle then return false end
    local sq = self.vehicle:getSquare()
    if not sq then return false end

    -- Require SpraycanVinylCoat AND SandingBlock
    local inv = self.character:getInventory()
    local hasSpray = inv:contains("SpraycanVinylCoat")
    local hasSanding = inv:contains("SandingBlock")

    return hasSpray and hasSanding
end

function ISSwapVinylAction:update()
    self.character:faceThisObject(self.vehicle)

    -- Keep sound looping during the action
    local emitter = self.character:getEmitter()
    if emitter and self.sound and not emitter:isPlaying(self.sound) then
        self.sound = emitter:playSound("Sewing")
    end
end

function ISSwapVinylAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")

    -- Start sound
    local emitter = self.character:getEmitter()
    if emitter then
        self.sound = emitter:playSound("Sewing")
    end
end

function ISSwapVinylAction:stop()
    -- Stop sound if still playing
    local emitter = self.character:getEmitter()
    if emitter and self.sound then
        emitter:stopSound(self.sound)
    end

    ISBaseTimedAction.stop(self)
end

function ISSwapVinylAction:perform()
    -- Stop sound if still playing
    local emitter = self.character:getEmitter()
    if emitter and self.sound then
        emitter:stopSound(self.sound)
    end

    -- Consume SpraycanVinylCoat
    local inv = self.character:getInventory()
    local spray = inv:getFirstType("SpraycanVinylCoat")
    if spray then
        inv:Remove(spray)
    end

    -- Use (but do not destroy) SandingBlock
    local sanding = inv:getFirstType("SandingBlock")
    if sanding then
        local condition = sanding:getCondition()
        if condition > 1 then
            sanding:setCondition(condition - 1)
        else
            -- If it hits 0, it breaks naturally
            inv:Remove(sanding)
        end
    end

    -- Perform the actual vinyl swap
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