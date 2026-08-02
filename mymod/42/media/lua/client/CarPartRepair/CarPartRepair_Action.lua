-- media/lua/client/CarPartRepair/CarPartRepair_Action.lua

CarPartRepair_Action = {}

local DEBUG = false
local function dbg(msg) if DEBUG then print("[CarPartRepair:Action] " .. tostring(msg)) end end

ISRepairCarPartAction = ISBaseTimedAction:derive("ISRepairCarPartAction")

function ISRepairCarPartAction:isValid()
    return self.item ~= nil
end

function ISRepairCarPartAction:update()
    -- Loop sound
    local emitter = self.character:getEmitter()
    if emitter and self.sound and not emitter:isPlaying(self.sound) then
        self.sound = emitter:playSound("Sewing")
    end
end

function ISRepairCarPartAction:start()
    dbg("start()")

    self.originalPrimary = self.character:getPrimaryHandItem()

    if self.tool then
        self.character:setPrimaryHandItem(self.tool)
    end

    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")

    local emitter = self.character:getEmitter()
    if emitter then
        self.sound = emitter:playSound("Sewing")
    end
end

function ISRepairCarPartAction:stop()
    local emitter = self.character:getEmitter()
    if emitter and self.sound then
        emitter:stopSound(self.sound)
    end

    ISBaseTimedAction.stop(self)
end

function ISRepairCarPartAction:perform()
    dbg("perform()")

    local emitter = self.character:getEmitter()
    if emitter and self.sound then
        emitter:stopSound(self.sound)
    end

    self.character:setPrimaryHandItem(self.originalPrimary)

    -- Skill cap
    local lvl = self.character:getPerkLevel(Perks.Mechanics)
    local caps = self.rule.skillCaps
    local maxRepair =
        (lvl <= 4) and caps[1] or
        (lvl <= 8) and caps[2] or
        caps[3]

    local oldCond = self.item:getCondition()
    local targetCond = math.min(maxRepair, oldCond + self.rule.repairAmount)

    dbg("oldCond=" .. oldCond .. " targetCond=" .. targetCond)
    self.item:setCondition(targetCond)

    -- Consume kit
    if self.kit and self.kit.getCurrentUses then
        self.kit:setCurrentUses(self.kit:getCurrentUses() - 1)
    end

    -- Consume material
    if self.material then
        self.character:getInventory():Remove(self.material)
    end

    ISBaseTimedAction.perform(self)
end

function CarPartRepair_Action.startRepair(player, item, rule)
    dbg("startRepair: " .. item:getFullType())

    local inv = player:getInventory()

    local tool     = inv:getFirstTypeRecurse(rule.required.tool)
    local material = inv:getFirstTypeRecurse(rule.required.material)
    local kit      = inv:getFirstTypeRecurse(rule.required.kit)

    local action = ISRepairCarPartAction:new(player, item, tool, material, kit, rule)
    ISTimedActionQueue.add(action)
end

function ISRepairCarPartAction:new(character, item, tool, material, kit, rule)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.item      = item
    o.tool      = tool
    o.material  = material
    o.kit       = kit
    o.rule      = rule

    local lvl = character:getPerkLevel(Perks.Mechanics)
    o.maxTime = 1200 - (lvl * 100)

    o.stopOnWalk = true
    o.stopOnRun  = true
    o.stopOnAim  = true
    o.forceProgressBar = true

    return o
end
