require "Items/Distributions"
require "Items/ProceduralDistributions"

local i;

-- QOL Loot Distribution Stuff

local qolMedsDistribTable = {
    "Base.BoxedSyringes", 0.2,
    "Base.BoxedLabTestTubes", 0.2,
    "Base.EmptySyringe", 0.3,
    "Base.LabTestTube", 0.2,
}

local qolStorageDistribTable = {
    "Base.HCHanddolly", 0.2,
    "Base.HCToywagon", 0.3,
}

local qolWeapDistribTable = {
    "Base.cfcombataxe", 0.2,
    "Base.cflongreachaxe", 0.2,
}

local qolCarDistribTable = {
    "Base.BoxedEngineParts", 0.4,
}

local qolSprayDistribTable = {
    "Base.SpraycanWhite", 0.5,
    "Base.SpraycanBlack", 0.5,
    "Base.SpraycanGray", 0.5,
    "Base.SpraycanDarkGray", 0.5,
    "Base.SpraycanRed", 0.5,
    "Base.SpraycanBlue", 0.5,
    "Base.SpraycanGreen", 0.5,
    "Base.SpraycanYellow", 0.5,
    "Base.SpraycanOrange", 0.5,
    "Base.SpraycanPurple", 0.5,
    "Base.SpraycanPastelBlue", 0.5,
    "Base.SpraycanPastelPink", 0.5,
    "Base.SpraycanPastelGreen", 0.5,
    "Base.SpraycanPastelYellow", 0.5,
    "Base.SpraycanMauve", 0.5,
    "Base.SpraycanBrown", 0.5,
    "Base.SpraycanTan", 0.5,
    "Base.SpraycanOlive", 0.5,
    "Base.SpraycanForestGreen", 0.5,
    "Base.SpraycanPink", 0.5,
    "Base.SpraycanCyan", 0.5,
}

local function insertTable(t1, t2)
    local n = #t1
    for i = 1, #t2 do
        t1[n + i] = t2[i]
    end
end

-- Dolly and Toywagon
insertTable(ProceduralDistributions["list"]["FireDeptLockers"].items, qolStorageDistribTable)
insertTable(ProceduralDistributions["list"]["CrateTools"].items, qolStorageDistribTable)
insertTable(ProceduralDistributions["list"]["CrateToolsOld"].items, qolStorageDistribTable)
insertTable(ProceduralDistributions["list"]["GardenStoreTools"].items, qolStorageDistribTable)
insertTable(ProceduralDistributions["list"]["GasStorageMechanics"].items, qolStorageDistribTable)
insertTable(ProceduralDistributions["list"]["GigamartTools"].items, qolStorageDistribTable)
insertTable(ProceduralDistributions["list"]["GroceryStorageCrate1"].items, qolStorageDistribTable)
insertTable(ProceduralDistributions["list"]["GroceryStorageCrate2"].items, qolStorageDistribTable)

-- Zombie Cure Items
insertTable(ProceduralDistributions["list"]["MedicalClinicDrugs"].items, qolMedsDistribTable)
insertTable(ProceduralDistributions["list"]["MedicalStorageDrugs"].items, qolMedsDistribTable)
insertTable(ProceduralDistributions["list"]["StoreShelfMedical"].items, qolMedsDistribTable)
insertTable(ProceduralDistributions["list"]["BathroomCounter"].items, qolMedsDistribTable)

-- Weapon Items
insertTable(ProceduralDistributions["list"]["ArmyStorageGuns"].items, qolWeapDistribTable)
insertTable(ProceduralDistributions["list"]["ArmyHangarTools"].items, qolWeapDistribTable)
insertTable(ProceduralDistributions["list"]["ArmySurplusCases"].items, qolWeapDistribTable)
insertTable(ProceduralDistributions["list"]["GunStoreKnives"].items, qolWeapDistribTable)
insertTable(ProceduralDistributions["list"]["GunStoreGuns"].items, qolWeapDistribTable)
insertTable(ProceduralDistributions["list"]["PoliceStorageGuns"].items, qolWeapDistribTable)

-- Other Stuff
insertTable(ProceduralDistributions["list"]["FireStorageMechanics"].items, qolCarDistribTable)
insertTable(ProceduralDistributions["list"]["CrateMechanics"].items, qolCarDistribTable)
insertTable(ProceduralDistributions["list"]["GarageMechanics"].items, qolCarDistribTable)
insertTable(ProceduralDistributions["list"]["GasStorageMechanics"].items, qolCarDistribTable)

-- Spray Cans
insertTable(ProceduralDistributions["list"]["GasStorageMechanics"].items, qolSprayDistribTable)
insertTable(ProceduralDistributions["list"]["CrateMechanics"].items, qolSprayDistribTable)
insertTable(ProceduralDistributions["list"]["GarageMechanics"].items, qolSprayDistribTable)
insertTable(ProceduralDistributions["list"]["GasStorageMechanics"].items, qolSprayDistribTable)
insertTable(ProceduralDistributions["list"]["GigamartTools"].items, qolSprayDistribTable)
insertTable(ProceduralDistributions["list"]["FireStorageMechanics"].items, qolSprayDistribTable)
insertTable(ProceduralDistributions["list"]["StoreShelfCombo"].items, qolSprayDistribTable)
insertTable(ProceduralDistributions["list"]["ClosetShelfGeneric"].items, qolSprayDistribTable)
insertTable(ProceduralDistributions["list"]["StoreShelfMechanics"].items, qolSprayDistribTable)
insertTable(ProceduralDistributions["list"]["MechanicSpecial"].items, qolSprayDistribTable)



