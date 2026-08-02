-- media/lua/client/TireRepair/TireRepair_Action.lua

TireRepair_Action = {}

local DEBUG = false
local function dbg(msg) if DEBUG then print("[TireRepair:Action] " .. tostring(msg)) end end

ISRepairTireAction = ISBaseTimedAction:derive("ISRepairTireAction")

function ISRepairTireAction:isValid()
    local valid = self.tire ~= nil
    dbg("isValid=" .. tostring(valid))
    return valid
end

function ISRepairTireAction:update()
    -- No facing logic here; avoid IsoObject type issues

    local emitter = self.character:getEmitter()
    if emitter and self.sound and not emitter:isPlaying(self.sound) then
        self.sound = emitter:playSound("Sewing")
    end
end

function ISRepairTireAction:start()
    dbg("start()")

    self.originalPrimary = self.character:getPrimaryHandItem()

    if self.screwdriver then
        dbg("equipping screwdriver")
        self.character:setPrimaryHandItem(self.screwdriver)
    end

    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")

    local emitter = self.character:getEmitter()
    if emitter then
        self.sound = emitter:playSound("Sewing")
    end
end

function ISRepairTireAction:stop()
    dbg("stop()")

    local emitter = self.character:getEmitter()
    if emitter and self.sound then
        emitter:stopSound(self.sound)
    end

    ISBaseTimedAction.stop(self)
end

function ISRepairTireAction:perform()
    dbg("perform()")

    local emitter = self.character:getEmitter()
    if emitter and self.sound then
        emitter:stopSound(self.sound)
    end

    self.character:setPrimaryHandItem(self.originalPrimary)

    local lvl = self.character:getPerkLevel(Perks.Mechanics)
    local maxRepair = (lvl <= 4) and 40 or (lvl <= 8) and 75 or 100

    local oldCond = self.tire:getCondition()
    local repairAmount = 25
    local targetCond = math.min(maxRepair, oldCond + repairAmount)

    dbg("oldCond=" .. oldCond .. " targetCond=" .. targetCond)
    self.tire:setCondition(targetCond)

    if self.tire.getAirPressureMax then
        local maxAir = self.tire:getAirPressureMax()
        dbg("inflating to " .. maxAir)
        self.tire:setAirPressure(maxAir)
    end

    if self.repairKit and self.repairKit.getCurrentUses then
        local uses = self.repairKit:getCurrentUses()
        dbg("repairKit uses before=" .. uses)
        self.repairKit:setCurrentUses(math.max(0, uses - 1))
        dbg("repairKit uses after=" .. self.repairKit:getCurrentUses())
    end

    if self.tirePiece then
        dbg("removing TirePiece")
        self.character:getInventory():Remove(self.tirePiece)
    end

    ISBaseTimedAction.perform(self)
end

function TireRepair_Action.startRepair(player, tire)
    dbg("startRepair tire=" .. tire:getFullType())

    local inv = player:getInventory()

    local screwdriver = inv:getFirstTypeRecurse("Base.Screwdriver")
    local repairKit  = inv:getFirstTypeRecurse("Base.TireRepairKit")
    local tirePiece  = inv:getFirstTypeRecurse("Base.TirePiece")
    local pump       = inv:getFirstTypeRecurse("Base.TirePump")

    dbg("screwdriver=" .. tostring(screwdriver))
    dbg("repairKit=" .. tostring(repairKit))
    dbg("tirePiece=" .. tostring(tirePiece))
    dbg("pump=" .. tostring(pump))

    local action = ISRepairTireAction:new(player, tire, screwdriver, repairKit, tirePiece, pump)
    ISTimedActionQueue.add(action)
end

function ISRepairTireAction:new(character, tire, screwdriver, repairKit, tirePiece, pump)
    local o = ISBaseTimedAction.new(self, character)
    o.character   = character
    o.tire        = tire
    o.screwdriver = screwdriver
    o.repairKit   = repairKit
    o.tirePiece   = tirePiece
    o.pump        = pump

    local lvl = character:getPerkLevel(Perks.Mechanics)
    o.maxTime = 1200 - (lvl * 100)

    o.stopOnWalk = true
    o.stopOnRun  = true
    o.stopOnAim  = true
    o.forceProgressBar = true

    dbg("new action created")
    return o
end
