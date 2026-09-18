require "Items/Distributions"
require "Items/ProceduralDistributions"

-----------------------------------------------------
-- Same safe-insert pattern MyQOLDistributions.lua
-- already uses -- guards against a distribution list
-- name not existing instead of hard-crashing.
-----------------------------------------------------
local function safeInsert(listName, tableToInsert)
    local dist = ProceduralDistributions.list[listName]
    if not dist or not dist.items then
        print("[Automaker Loot] WARNING: Procedural container '" .. listName .. "' does not exist!")
        return
    end

    local target = dist.items
    local before = #target
    local added = #tableToInsert

    for i = 1, added do
        target[before + i] = tableToInsert[i]
    end
end

local automakerMagsTable = {
    "Base.AutomakerMag1", 2,
    "Base.AutomakerMag2", 2,
    "Base.AutomakerMag3", 2,
}

safeInsert("BookstoreMisc", automakerMagsTable)
safeInsert("CrateMagazines", automakerMagsTable)
safeInsert("CrateMechanics", automakerMagsTable)
safeInsert("MechanicShelfBooks", automakerMagsTable)
