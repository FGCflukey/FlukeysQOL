-- StopThePlantRot: mature crops don't rot (or rot only after N postponed checks).

if isClient() then
    return
end

local DEBUG = false
local function dbg(msg) if DEBUG then print("[StopThePlantRot] " .. tostring(msg)) end end

StopThePlantRot = StopThePlantRot or {}

-- Sandbox setting: true = reset growth each time rot is postponed (default); false = leave the plant as-is
function StopThePlantRot.getResetOnRot()
    if SandboxVars.StopThePlantRot and SandboxVars.StopThePlantRot.ResetGrowthOnRot ~= nil then
        return SandboxVars.StopThePlantRot.ResetGrowthOnRot
    end
    return true
end

-- Sandbox setting: 0 = postpone forever (never rot); N = really rot after N postponed rot checks
function StopThePlantRot.getRotDelay()
    if SandboxVars.StopThePlantRot and SandboxVars.StopThePlantRot.RotDelay ~= nil then
        return SandboxVars.StopThePlantRot.RotDelay
    end
    return 0
end

-- Protected if alive and either mature (harvestable) or seed-bearing (seeds collectable)
function StopThePlantRot.isProtected(plant)
    if not plant or not plant:isAlive() then
        return false
    end
    return plant.hasVegetable or plant.hasSeed
end

function StopThePlantRot.resetToSeedBearing(plant)
    local prop = farming_vegetableconf.props[plant.typeOfSeed]
    if not prop then
        -- Unknown crop type (e.g. its mod was removed): nothing to reset to, just save
        dbg("resetToSeedBearing: no crop props for seed=" .. tostring(plant.typeOfSeed))
        plant:saveData()
        return
    end
    if prop.fullGrown then
        plant.nbOfGrow = prop.fullGrown
    end
    plant.state = "seeded"
    local rotTime = prop.rotTime or math.floor((prop.timeToGrow or 1) / 2)
    plant.nextGrowing = calcNextGrowing(nil, rotTime)
    plant:saveData()
end

-- Postpone rot once: reset growth or leave as-is per the sandbox setting, and save the decremented counter
function StopThePlantRot.postponeRot(plant)
    if StopThePlantRot.getResetOnRot() then
        StopThePlantRot.resetToSeedBearing(plant) -- calls saveData internally
    else
        plant:saveData()
    end
end

-- Persist each plant's remaining rot-delay count
local originalToModData = SPlantGlobalObject.toModData
function SPlantGlobalObject:toModData(modData)
    originalToModData(self, modData)
    modData.stopThePlantRotDelay = self.rotDelayLeft
end

local originalFromModData = SPlantGlobalObject.fromModData
function SPlantGlobalObject:fromModData(modData)
    originalFromModData(self, modData)
    self.rotDelayLeft = modData.stopThePlantRotDelay
end

-- A new crop starts with a fresh rot-delay count, so a replanted plot never inherits
-- the previous crop's used-up counter. Cleared before vanilla seed() runs its own saveData().
local originalSeed = SPlantGlobalObject.seed
function SPlantGlobalObject:seed(typeOfSeed, skill)
    self.rotDelayLeft = nil
    return originalSeed(self, typeOfSeed, skill)
end

local originalRottenThis = SPlantGlobalObject.rottenThis

function SPlantGlobalObject.rottenThis(self)
    dbg("rottenThis: seed=" .. tostring(self.typeOfSeed) .. " protected=" ..
        tostring(StopThePlantRot.isProtected(self)) .. " rotDelayLeft=" .. tostring(self.rotDelayLeft))
    if StopThePlantRot.isProtected(self) then
        local delay = StopThePlantRot.getRotDelay()
        if delay > 0 then
            if self.rotDelayLeft == nil then
                self.rotDelayLeft = delay
            end
            if self.rotDelayLeft > 0 then
                -- Postpone once and decrement the remaining count
                self.rotDelayLeft = self.rotDelayLeft - 1
                dbg("postpone rot: seed=" .. tostring(self.typeOfSeed) .. " remaining=" ..
                    tostring(self.rotDelayLeft))
                StopThePlantRot.postponeRot(self)
                return
            end
            -- Delay used up, fall through to vanilla rot
            dbg("delay exhausted, vanilla rot: seed=" .. tostring(self.typeOfSeed))
        else
            -- 0 = infinite delay, never rot
            dbg("infinite delay, never rot: seed=" .. tostring(self.typeOfSeed))
            StopThePlantRot.postponeRot(self)
            return
        end
    end
    dbg("not protected, vanilla rot: seed=" .. tostring(self.typeOfSeed))
    return originalRottenThis(self)
end
