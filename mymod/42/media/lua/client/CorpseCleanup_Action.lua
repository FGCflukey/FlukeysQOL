-- Corpse Cleanup - With Zombie Meat Harvesting

CorpseCleanupAction = ISBaseTimedAction:derive("CorpseCleanupAction")

local function DropCorpseInventory(corpse)
    if not corpse then return end

    local square = corpse:getSquare()
    if not square then return end

    local container = corpse:getContainer()
    if not container then return end

    local items = {}
    for i = 0, container:getItems():size() - 1 do
        table.insert(items, container:getItems():get(i))
    end

    for _, item in ipairs(items) do
        container:Remove(item)
        square:AddWorldInventoryItem(item, 0, 0, 0)
    end
end

-- Skill‑based zombie meat yield
local function getZombieMeatYield(character)
    local perk = character:getPerkLevel(Perks.Butchering)

    if perk < 2 then
        return ZombRand(1, 3)      -- 1–2
    elseif perk < 4 then
        return ZombRand(1, 4)      -- 1–3
    elseif perk < 6 then
        return ZombRand(3, 6)      -- 3–5
    else
        return ZombRand(5, 11)     -- 5–10
    end
end

function CorpseCleanupAction:isValid()
    return self.corpse ~= nil and self.corpse:getSquare() ~= nil
end

function CorpseCleanupAction:update()
    self.character:faceThisObject(self.corpse)
end

function CorpseCleanupAction:start()
    -- Butchering skill requirement (safety check)
    local requiredLevel = 2
    if self.character:getPerkLevel(Perks.Butchering) < requiredLevel then
        self.character:Say("I don't know how to butcher a corpse yet.")
        self:forceStop()
        return
    end

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

    -- Drop corpse inventory
    DropCorpseInventory(self.corpse)

    -- Remove corpse cleanly
    if sq then
        sq:removeCorpse(self.corpse, true)
    end

    -- Blood effect (42.14+ clothing system)
    local function AddBloodToClothes(character, amount)
        local worn = character:getWornItems()
        if not worn then return end

        for i = 0, worn:size() - 1 do
            local item = worn:getItemByIndex(i)
            if item and item.setBloodLevel and item.getBloodLevel then
                local current = item:getBloodLevel()
                item:setBloodLevel(math.min(1, current + amount))
            end
        end
    end

    AddBloodToClothes(self.character, 0.2)

    -- Inventory + skill‑based meat yield
    local inv = self.character:getInventory()
    local count = getZombieMeatYield(self.character)
    inv:AddItems("Base.ZombieMeat", count)

    -- Restore original hand items
    if self.originalPrimary
       and self.originalPrimary:getContainer() == inv
       and not self.originalPrimary:isBroken() then
        self.character:setPrimaryHandItem(self.originalPrimary)
    else
        self.character:setPrimaryHandItem(nil)
    end

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
    o.maxTime = 200
    o.originalPrimary = originalPrimary
    o.originalSecondary = originalSecondary
    return o
end