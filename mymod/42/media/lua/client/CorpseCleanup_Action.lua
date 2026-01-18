-- Corpse Cleanup - With Zombie Meat Harvesting

CorpseCleanupAction = ISBaseTimedAction:derive("CorpseCleanupAction")

-- 🔹 NEW: helper to drop corpse inventory
local function DropCorpseInventory(corpse)
    if not corpse then return end

    local square = corpse:getSquare()
    if not square then return end

    local container = corpse:getContainer()
    if not container then return end

    -- Copy items first to avoid iterator issues
    local items = {}
    for i = 0, container:getItems():size() - 1 do
        table.insert(items, container:getItems():get(i))
    end

    for _, item in ipairs(items) do
        container:Remove(item)
        square:AddWorldInventoryItem(item, 0, 0, 0)
    end
end

function CorpseCleanupAction:isValid()
    return self.corpse ~= nil and self.corpse:getSquare() ~= nil
end

function CorpseCleanupAction:update()
    self.character:faceThisObject(self.corpse)
end

function CorpseCleanupAction:start()
    self:setActionAnim("Dig")
    self.character:reportEvent("EventDig")
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

    local sq = self.corpse:getSquare()

    -- ⭐ NEW: Drop corpse items BEFORE removing corpse
    DropCorpseInventory(self.corpse)

    if sq then
        sq:removeCorpse(self.corpse, true)
    end

    self.character:addBlood(0.2)

    local inv = self.character:getInventory()
    local count = ZombRand(1, 11)
    inv:AddItems("Base.ZombieMeat", count)

    -- ⭐ RESTORE PRIMARY
    if self.originalPrimary
       and self.originalPrimary:getContainer() == inv
       and not self.originalPrimary:isBroken() then
        self.character:setPrimaryHandItem(self.originalPrimary)
    else
        self.character:setPrimaryHandItem(nil)
    end

    -- ⭐ RESTORE SECONDARY
    if self.originalSecondary
       and self.originalSecondary:getContainer() == inv
       and not self.originalSecondary:isBroken() then
        self.character:setSecondaryHandItem(self.originalSecondary)
    else
        self.character:setSecondaryHandItem(nil)
    end

    ISBaseTimedAction.perform(self)
end

function CorpseCleanupAction:new(character, corpse, tool, time, originalPrimary, originalSecondary)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.corpse = corpse
    o.tool = tool
    o.maxTime = time or 100
    o.originalPrimary = originalPrimary
    o.originalSecondary = originalSecondary
    return o
end