-- media/lua/client/CarPartRepair/CarPartRepair_Util.lua

CarPartRepair_Util = {}

local DEBUG = false
local function dbg(msg) if DEBUG then print("[CarPartRepair:Util] " .. tostring(msg)) end end

---------------------------------------------------------
-- Repair rules for each part
---------------------------------------------------------
local RepairRules = {
    Suspension = {
        match = "Suspension",
        required = {
            tool = "Base.Wrench",
            material = "Base.ScrapMetal",
            kit = "Base.SuspensionKit",
        },
        repairAmount = 20,
        skillCaps = {40, 70, 100},
    },

    Brakes = {
        match = "Brake",
        required = {
            tool = "Base.Wrench",
            material = "Base.ScrapMetal",
            kit = "Base.BrakeKit",
        },
        repairAmount = 15,
        skillCaps = {50, 80, 100},
    },

    Muffler = {
        match = "Muffler",
        required = {
            tool = "Base.Wrench",
            material = "Base.ScrapMetal",
            kit = "Base.MufflerPatchKit",
        },
        repairAmount = 10,
        skillCaps = {30, 60, 100},
    },
}

CarPartRepair_Util.Rules = RepairRules

---------------------------------------------------------
-- Identify which part type this item is
---------------------------------------------------------
function CarPartRepair_Util.identifyPart(item)
    local ft = item:getFullType()
    dbg("identifyPart: " .. ft)

    for partName, rule in pairs(RepairRules) do
        if ft:find(rule.match) then
            dbg("Matched part: " .. partName)
            return partName, rule
        end
    end

    return nil, nil
end

---------------------------------------------------------
-- Can repair this part?
---------------------------------------------------------
function CarPartRepair_Util.canRepairPart(player, item, rule)
    dbg("canRepairPart: checking " .. item:getFullType())

    local inv = player:getInventory()

    -- Required tool
    if not inv:contains(rule.required.tool) then
        return false, "Missing tool"
    end

    -- Required material
    if not inv:containsType(rule.required.material) then
        return false, "Missing material"
    end

    -- Required kit
    local kit = inv:getFirstTypeRecurse(rule.required.kit)
    if not kit then
        return false, "Missing repair kit"
    end

    if not kit.getCurrentUses or not kit.getMaxUses then
        return false, "Repair kit invalid"
    end

    if kit:getCurrentUses() <= 0 then
        return false, "Repair kit empty"
    end

    -- Skill caps
    local lvl = player:getPerkLevel(Perks.Mechanics)
    local maxRepair =
        (lvl <= 4) and rule.skillCaps[1] or
        (lvl <= 8) and rule.skillCaps[2] or
        rule.skillCaps[3]

    if item:getCondition() >= maxRepair then
        return false, "Part condition cannot be improved further"
    end

    return true, nil
end
