require "Items/Distributions"
require "Items/ProceduralDistributions"

---------------------------------------------------------
-- DEBUG TOGGLE
---------------------------------------------------------
local QOL_DEBUG = false   -- set to true to enable debug logging

local function qolDebug(msg)
    if QOL_DEBUG then
        print("[QOL Loot Debug] " .. tostring(msg))
    end
end

---------------------------------------------------------
-- Helper: Safe Insert with Debug
---------------------------------------------------------
local function safeInsert(listName, tableToInsert)
    local dist = ProceduralDistributions.list[listName]
    if not dist or not dist.items then
        qolDebug("WARNING: Procedural container '" .. listName .. "' does not exist!")
        return
    end

    local target = dist.items
    local before = #target
    local added = #tableToInsert

    for i = 1, added do
        target[before + i] = tableToInsert[i]
    end

    qolDebug("Inserted into " .. listName .. ": +" .. added .. " entries")
end

---------------------------------------------------------
-- Item Tables
---------------------------------------------------------

-- Medical / Cure Items
local qolMedsDistribTable = {
    "Base.BoxedSyringes",      0.6,
    "Base.BoxedLabTestTubes",  0.6,
    "Base.EmptySyringe",       0.8,
    "Base.LabTestTube",        0.6,
}

-- Storage Items
local qolStorageDistribTable = {
    "Base.HCHanddolly",  0.5,
    "Base.HCToywagon",   0.6,
}

-- Weapons
local qolWeapDistribTable = {
    "Base.cfcombataxe",      0.4,
    "Base.cflongreachaxe",   0.4,
}

-- Car / Mechanics
local qolCarDistribTable = {
    "Base.BoxedEngineParts", 0.8,
}

-- Spray Cans
local qolSprayDistribTable = {
    "Base.SpraycanWhite",        0.4,
    "Base.SpraycanBlack",        0.4,
    "Base.SpraycanGray",         0.4,
    "Base.SpraycanDarkGray",     0.4,
    "Base.SpraycanRed",          0.4,
    "Base.SpraycanBlue",         0.4,
    "Base.SpraycanGreen",        0.4,
    "Base.SpraycanYellow",       0.4,
    "Base.SpraycanOrange",       0.4,
    "Base.SpraycanPurple",       0.4,
    "Base.SpraycanPastelBlue",   0.4,
    "Base.SpraycanPastelPink",   0.4,
    "Base.SpraycanPastelGreen",  0.4,
    "Base.SpraycanPastelYellow", 0.4,
    "Base.SpraycanMauve",        0.4,
    "Base.SpraycanBrown",        0.4,
    "Base.SpraycanTan",          0.4,
    "Base.SpraycanOlive",        0.4,
    "Base.SpraycanForestGreen",  0.4,
    "Base.SpraycanPink",         0.4,
    "Base.SpraycanCyan",         0.4,
}

---------------------------------------------------------
-- Procedural targets (only ones confirmed by your logs)
---------------------------------------------------------

local storageTargets = {
    "FireDeptLockers",
    "CrateTools",
    "CrateToolsOld",
    "GardenStoreTools",
    "GasStorageMechanics",
    "GigamartTools",
    "GroceryStorageCrate1",
    "GroceryStorageCrate2",
}

local medTargets = {
    "MedicalClinicDrugs",
    "MedicalStorageDrugs",
    "StoreShelfMedical",
    "BathroomCounter",
}

local weaponTargets = {
    "ArmyStorageGuns",
    "ArmyHangarTools",
    "ArmySurplusCases",
    "GunStoreKnives",
    "GunStoreGuns",
    "PoliceStorageGuns",
}

local carTargets = {
    "FireStorageMechanics",
    "CrateMechanics",
    "GarageMechanics",
    "GasStorageMechanics",
    "MechanicSpecial",
}

local sprayTargets = {
    "CrateMechanics",
    "GarageMechanics",
    "GasStorageMechanics",
    "GigamartTools",
    "FireStorageMechanics",
    "StoreShelfCombo",
    "ClosetShelfGeneric",
    "StoreShelfMechanics",
    "MechanicSpecial",
}

---------------------------------------------------------
-- Insertions
---------------------------------------------------------

for _, name in ipairs(storageTargets) do
    safeInsert(name, qolStorageDistribTable)
end

for _, name in ipairs(medTargets) do
    safeInsert(name, qolMedsDistribTable)
end

for _, name in ipairs(weaponTargets) do
    safeInsert(name, qolWeapDistribTable)
end

for _, name in ipairs(carTargets) do
    safeInsert(name, qolCarDistribTable)
end

for _, name in ipairs(sprayTargets) do
    safeInsert(name, qolSprayDistribTable)
end