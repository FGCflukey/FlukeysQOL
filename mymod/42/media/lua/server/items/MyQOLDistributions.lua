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

local qolWeapDistribTable = {
    "Base.cfcombataxe", 0.2,
    "Base.cflongreachaxe", 0.2,
}


local function insertTable(t1, t2)
    local n = #t1
    for i = 1, #t2 do
        t1[n + i] = t2[i]
    end
end

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
