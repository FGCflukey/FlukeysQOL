require "TimedActions/ISBaseTimedAction"
require "BoulderMining/BoulderMining_Defs"

-- Break a boulder with a pickaxe/sledgehammer.
-- Structure mirrors vanilla ISPickAxeGroundCoverItem: all the real work
-- (loot, removing the tiles, XP, tool wear) happens in complete(), which
-- runs on the server in MP. The client only plays the animation.

BoulderMiningAction = ISBaseTimedAction:derive("BoulderMiningAction")

local dbg = BoulderMining.dbg

function BoulderMiningAction:isValid()
    if not BoulderMining.isTool(self.character:getPrimaryHandItem()) then
        return false
    end
    -- Same as vanilla: once started on the client, the server decides.
    if isClient() and self.started then return true end
    if not self.boulder or self.boulder:getObjectIndex() == -1 then return false end
    if BoulderMining.getSpriteName(self.boulder) ~= self.spriteName then return false end
    return BoulderMining.isWithinReach(self.character, BoulderMining.collectParts(self.boulder))
end

function BoulderMiningAction:waitToStart()
    self.character:faceThisObject(self.boulder)
    return self.character:shouldBeTurning()
end

function BoulderMiningAction:update()
    self.character:faceThisObject(self.boulder)
    self.character:setMetabolicTarget(Metabolics.HeavyWork)
end

function BoulderMiningAction:start()
    self.tool = self.character:getPrimaryHandItem()
    self:setActionAnim("HammerOre")
    addSound(self.character, self.character:getX(), self.character:getY(), self.character:getZ(), 20, 10)
    self.started = true
end

function BoulderMiningAction:stop()
    ISBaseTimedAction.stop(self)
end

function BoulderMiningAction:perform()
    self.character:playSound("CraftMineralDepositRemove")
    ISBaseTimedAction.perform(self)
end

function BoulderMiningAction:animEvent(event, parameter)
    local tool = self.character:getPrimaryHandItem()
    if not tool then return end
    if event == "PlaySwingSound" then
        self.character:playSound(tool:getSwingSound())
    elseif event == "PlayHitSound" then
        self.character:addCombatMuscleStrain(tool)
        self.character:playSound("CraftMineralDepositHit")
    end
end

function BoulderMiningAction:complete()
    local boulder = self.boulder
    if not boulder or boulder:getObjectIndex() == -1 then
        dbg("complete: boulder already gone")
        return false
    end

    local def, name = BoulderMining.getDef(boulder)
    if not def or name ~= self.spriteName then
        dbg("complete: sprite mismatch " .. tostring(name))
        return false
    end

    local tool = self.character:getPrimaryHandItem()
    if not BoulderMining.isTool(tool) then
        dbg("complete: no valid tool in hand")
        return false
    end

    local parts = BoulderMining.collectParts(boulder)
    if not BoulderMining.isWithinReach(self.character, parts) then
        dbg("complete: out of reach")
        return false
    end

    local profile = BoulderMining.Profiles[def.profile]
    local dropSq = boulder:getSquare()

    -- Remove every tile of this boulder.
    for _, o in ipairs(parts) do
        local sq = o:getSquare()
        if sq and o:getObjectIndex() ~= -1 then
            sq:transmitRemoveItemFromSquare(o)
        end
    end

    -- Loot, rolled once for the whole boulder.
    for _, entry in ipairs(profile.loot) do
        local count = ZombRand(entry[2], entry[3] + 1)
        for _ = 1, count do
            dropSq:SpawnWorldInventoryItem(entry[1], ZombRandFloat(0.1, 0.9), ZombRandFloat(0.1, 0.9), 0.0)
        end
    end

    addXp(self.character, Perks.Masonry, profile.xp)
    addXp(self.character, Perks.Strength, profile.xp)
    addSound(self.character, self.character:getX(), self.character:getY(), self.character:getZ(), 20, 10)

    if not self.character:isBuildCheat() then
        tool:damageCheck(0, 2, false)
    end

    dbg("broke " .. name .. " (" .. def.profile .. ", " .. #parts .. " tiles)")
    return true
end

function BoulderMiningAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    local def = self.boulder and BoulderMining.getDef(self.boulder)
    local base = def and BoulderMining.Profiles[def.profile].time or 300
    local t = base - self.character:getPerkLevel(Perks.Strength) * (base / 20)
    return math.max(math.floor(base * 0.4), math.floor(t))
end

function BoulderMiningAction:new(character, boulder)
    local o = ISBaseTimedAction.new(self, character)
    o.boulder = boulder
    o.spriteName = BoulderMining.getSpriteName(boulder)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.caloriesModifier = 8
    o.maxTime = o:getDuration()
    return o
end
