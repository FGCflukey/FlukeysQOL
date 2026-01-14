-- Corpse Cleanup - With Zombie Meat Harvesting

CorpseCleanupAction = ISBaseTimedAction:derive("CorpseCleanupAction")

function CorpseCleanupAction:isValid()
    return self.corpse ~= nil and self.corpse:getSquare() ~= nil
end

function CorpseCleanupAction:update()
    self.character:faceThisObject(self.corpse)
end

function CorpseCleanupAction:start()
    -- Kneeling animation
    self:setActionAnim("Dig")
    self.character:reportEvent("EventDig")

    -- Play your custom cutting sound
    self.sound = self.character:getEmitter():playSound("DissectCorpseKnives")
end

function CorpseCleanupAction:stop()
    if self.sound then
        self.character:getEmitter():stopSound(self.sound)
    end
    ISBaseTimedAction.stop(self)
end

function CorpseCleanupAction:perform()
    if self.sound then
        self.character:getEmitter():stopSound(self.sound)
    end

    -- Remove the corpse
    local sq = self.corpse:getSquare()
    if sq then
        sq:removeCorpse(self.corpse, true)
    end

    -- Add a bit of blood to the player
    self.character:addBlood(0.2)

    -- ⭐ GIVE 1–10 ZOMBIE MEAT ⭐
    local inv = self.character:getInventory()
    local count = ZombRand(1, 11) -- 1 to 10 inclusive
    inv:AddItems("Base.ZombieMeat", count)

    ISBaseTimedAction.perform(self)
end

function CorpseCleanupAction:new(character, corpse, tool, time)
    local o = ISBaseTimedAction.new(self, character)
    o.corpse = corpse
    o.tool = tool
    o.maxTime = time or 100
    return o
end
