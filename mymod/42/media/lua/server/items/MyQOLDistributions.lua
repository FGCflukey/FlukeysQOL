require "Items/Distributions"
require "Items/ProceduralDistributions"

---------------------------------------------------------
-- DEBUG TOGGLE
---------------------------------------------------------
local QOL_DEBUG = true   -- set to true to enable debug logging

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
    "Base.BoxedSyringes",      8.0,
    "Base.BoxedLabTestTubes",  8.0,
    "Base.EmptySyringe",       12.0,
    "Base.LabTestTube",        9.0,
}

-- Storage Items
local qolStorageDistribTable = {
    "Base.HCHanddolly",  3.0,
    "Base.HCToywagon",   4.0,
}

-- Weapons
local qolWeapDistribTable = {
    "Base.cfcombataxe",      8.5,
    "Base.cflongreachaxe",   8.5,
}

-- Car / Mechanics
local qolCarDistribTable = {
    "Base.BoxedEngineParts", 9.0,
}

-- Spray Cans
local qolSprayDistribTable = {
    "Base.SpraycanWhite",        4.0,
    "Base.SpraycanBlack",        4.0,
    "Base.SpraycanGray",         4.0,
    "Base.SpraycanDarkGray",     4.0,
    "Base.SpraycanRed",          4.0,
    "Base.SpraycanBlue",         4.0,
    "Base.SpraycanGreen",        4.0,
    "Base.SpraycanYellow",       4.0,
    "Base.SpraycanOrange",       4.0,
    "Base.SpraycanPurple",       4.0,
    "Base.SpraycanPastelBlue",   4.0,
    "Base.SpraycanPastelPink",   4.0,
    "Base.SpraycanPastelGreen",  4.0,
    "Base.SpraycanPastelYellow", 4.0,
    "Base.SpraycanMauve",        4.0,
    "Base.SpraycanBrown",        4.0,
    "Base.SpraycanTan",          4.0,
    "Base.SpraycanOlive",        4.0,
    "Base.SpraycanForestGreen",  4.0,
    "Base.SpraycanPink",         4.0,
    "Base.SpraycanCyan",         4.0,
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
    "PawnShopTools",
}

local medTargets = {
    "MedicalClinicDrugs",
    "MedicalStorageDrugs",
    "StoreShelfMedical",
    "BathroomCounter",
    "ArmyStorageMedical",
}

local weaponTargets = {
    "ArmyStorageGuns",
    "ArmyHangarTools",
    "ArmySurplusCases",
    "GunStoreKnives",
    "GunStorePistols",
    "GunStoreRifles",
    "GunStoreGuns",
    "PoliceStorageGuns",
    "FiremanTools",
}

local carTargets = {
    "FireStorageMechanics",
    "CrateMechanics",
    "GarageMechanics",
    "GasStorageMechanics",
    "MechanicSpecial",
    "ArmySurplusMisc",
    "FireDeptLockers",
    "ToolCabinetMechanics",
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
    "FireStorageTools",
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