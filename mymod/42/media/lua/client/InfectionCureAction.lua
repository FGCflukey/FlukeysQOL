print("[ZomInfection] CureAction LOADED")

require "TimedActions/ISBaseTimedAction"

ZomInfectionCureAction = ISBaseTimedAction:derive("ZomInfectionCureAction")


function ZomInfectionCureAction:isValid()
    return self.character and self.item and self.character:getInventory():contains(self.item)
end

function ZomInfectionCureAction:start()
    self.item:setJobType("Injecting Cure")
    self.item:setJobDelta(0.0)

    self:setOverrideHandModels(nil, self.item)
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
    self.character:playSound("Pills_A")
end

function ZomInfectionCureAction:update()
    self.item:setJobDelta(self:getJobDelta())
end

function ZomInfectionCureAction:stop()
    ISBaseTimedAction.stop(self)
    self.item:setJobDelta(0.0)
end

function ZomInfectionCureAction:perform()
    self.item:setJobDelta(0.0)

    sendClientCommand(self.character, "ZomInfection", "Cure", {})

    self.item:Use()

    ISBaseTimedAction.perform(self)
end

function ZomInfectionCureAction:new(character, item)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.character = character
    o.item = item
    o.maxTime = 120
    o.stopOnWalk = false
    o.stopOnRun = false

    return o
end
