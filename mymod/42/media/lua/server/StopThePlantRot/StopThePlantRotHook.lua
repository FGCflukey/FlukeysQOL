-- StopThePlantRot: fully grown crops stay harvestable instead of rotting -- forever, or for a set
-- number of in-game days. Our own build, inspired by the Workshop mod NoPlantRot (3779203470).
--
-- How vanilla rots a crop (server/Farming):
--   SFarmingSystem:checkPlant2 calls growPlant() whenever hoursElapsed >= plant.nextGrowing.
--   growPlant() runs farming_vegetableconf.grow() and then ALWAYS does nbOfGrow + 1.
--   At nbOfGrow == fullGrown, grow() marks it seed-bearing; the +1 then puts it on
--   fullGrown + 1 (vanilla's seed-bearing display stage) with nextGrowing = rotTime hours away.
--   The next growPlant() at nbOfGrow > fullGrown calls rottenThis().
--
-- We step in at growPlant(), BEFORE vanilla's rot step: for a living, harvestable crop past
-- fullGrown we don't call vanilla at all, so there is no rot and no +1 stage creep. The crop
-- just stays on its fullGrown + 1 seed-bearing stage, with its normal sprite and name. Watering,
-- health and disease are still checked every hour by vanilla's checkPlant2, so a neglected
-- crop can still die -- this only removes rotting from old age.

if isClient() then
    return
end

local DEBUG = false
local function dbg(msg) if DEBUG then print("[StopThePlantRot] " .. tostring(msg)) end end

StopThePlantRot = StopThePlantRot or {}

-- When rotting is fully off, re-check once an in-game day. That's cheap (one call per crop
-- per day) and means changing the sandbox setting mid-game takes effect within a day.
local NEVER_ROT_RECHECK_HOURS = 24

-- Sandbox: 0 = never rot (default); N = rot N in-game days after the crop's normal rot point
function StopThePlantRot.getDaysBeforeRot()
    local opts = SandboxVars and SandboxVars.StopThePlantRot
    local days = opts and tonumber(opts.DaysBeforeRot)
    if not days or days < 0 then return 0 end
    return math.floor(days)
end

-- Protected: alive, and has something to harvest or seeds to collect
function StopThePlantRot.isProtected(plant)
    if not plant or not plant:isAlive() then return false end
    return plant.hasVegetable or plant.hasSeed
end

-- Persist the rot deadline (in farming hoursElapsed) on the plant's modData
local originalToModData = SPlantGlobalObject.toModData
function SPlantGlobalObject:toModData(modData)
    originalToModData(self, modData)
    modData.stopThePlantRotDeadline = self.stopRotDeadline
end

local originalFromModData = SPlantGlobalObject.fromModData
function SPlantGlobalObject:fromModData(modData)
    originalFromModData(self, modData)
    self.stopRotDeadline = tonumber(modData.stopThePlantRotDeadline)
end

local originalGrowPlant = SFarmingSystem.growPlant

function SFarmingSystem:growPlant(plant, nextGrowing, updateNbOfGrow)
    local prop = plant and farming_vegetableconf.props[plant.typeOfSeed]

    -- Only the rot step concerns us; any other growth (including a brand new seed, or a
    -- regrowing crop like strawberries after harvest) starts a fresh cycle with no deadline.
    if not prop or not prop.fullGrown or plant.state ~= "seeded" or plant.nbOfGrow <= prop.fullGrown then
        if plant then plant.stopRotDeadline = nil end
        return originalGrowPlant(self, plant, nextGrowing, updateNbOfGrow)
    end

    if not StopThePlantRot.isProtected(plant) then
        dbg("not protected, vanilla rot: seed=" .. tostring(plant.typeOfSeed))
        return originalGrowPlant(self, plant, nextGrowing, updateNbOfGrow)
    end

    local now = self.hoursElapsed
    local days = StopThePlantRot.getDaysBeforeRot()

    if days > 0 then
        if not plant.stopRotDeadline then
            plant.stopRotDeadline = now + days * 24
            dbg("rot deadline set: seed=" .. tostring(plant.typeOfSeed) .. " in " .. days .. " days")
        end
        if now >= plant.stopRotDeadline then
            dbg("deadline reached, vanilla rot: seed=" .. tostring(plant.typeOfSeed))
            plant.stopRotDeadline = nil
            return originalGrowPlant(self, plant, nextGrowing, updateNbOfGrow)
        end
        -- Wake up exactly when the deadline arrives
        plant.nextGrowing = plant.stopRotDeadline
    else
        plant.stopRotDeadline = nil
        plant.nextGrowing = now + NEVER_ROT_RECHECK_HOURS
    end

    -- Hold on vanilla's seed-bearing display stage. Clamps any crop that an older version of
    -- this mod (or NoPlantRot's "keep as-is" option) let creep past it.
    plant.nbOfGrow = prop.fullGrown + 1
    dbg("holding ripe: seed=" .. tostring(plant.typeOfSeed) .. " nextCheck=" .. tostring(plant.nextGrowing))
    plant:saveData()
end
