-- media/lua/shared/CarPartRepair/CarPartRepair_Util.lua
-- IMPORTANT: this file now needs to live under media/lua/shared/ (not client/)
-- so both the client context menu AND the server command handler can require it.
-- Using one shared copy avoids the rules ever drifting between client/server.

CarPartRepair_Util = {}

local DEBUG = true
local function dbg(msg) if DEBUG then print("[CarPartRepair:Util] " .. tostring(msg)) end end

---------------------------------------------------------
-- Repair rules for each part group
-- "matches" is a list of keywords checked with a word-boundary
-- pattern, so "Hood" will NOT match "Hoodie", "Door" will NOT
-- match some unrelated "DoorKnob" clothing/deco item, etc.
---------------------------------------------------------
local RepairRules = {
    Suspension = {
        matches = { "Suspension" },
        required = {
            tool = "Base.BlowTorch",
            material = "Base.ScrapMetal",
            kit = "Base.SuspensionKit",
        },
        repairAmount = 20,
        skillCaps = {40, 70, 100},
        toolConsumesUses = true,
        toolUsesPerRepair = 2,
    },

    Brakes = {
        matches = { "Brake" },
        required = {
            tool = "Base.BlowTorch",
            material = "Base.ScrapMetal",
            kit = "Base.BrakeKit",
        },
        repairAmount = 15,
        skillCaps = {50, 80, 100},
        toolConsumesUses = true,
        toolUsesPerRepair = 2,
    },

    Muffler = {
        matches = { "Muffler" },
        required = {
            tool = "Base.BlowTorch",
            material = "Base.ScrapMetal",
            kit = "Base.MufflerPatchKit",
        },
        repairAmount = 10,
        skillCaps = {30, 60, 100},
        toolConsumesUses = true,
        toolUsesPerRepair = 2,
    },

    GasTank = {
        matches = { "GasTank" },
        required = {
            tool = "Base.BlowTorch",
            material = "Base.ScrapMetal",
            kit = "Base.GasTankRepairKit",
        },
        repairAmount = 10,
        skillCaps = {30, 60, 100},
        toolConsumesUses = true,
        toolUsesPerRepair = 2,
    },

    -- Hood / Door / TrunkLid / EngineDoor (M998-family hoods) share one group.
    BodyParts = {
        matches = { "Hood", "Door", "TrunkLid", "EngineDoor" },
        required = {
            tool = "Base.BlowTorch",
            material = "Base.SheetMetal",
            kit = "Base.BodyRepairKit",
        },
        repairAmount = 20,
        skillCaps = {30, 65, 100},
        toolConsumesUses = true,
        toolUsesPerRepair = 2,
    },

    -- Merged in from the standalone Tire mod. "Tire" alone would also
    -- match TirePump/TireRepairKit/TirePiece (all legitimately contain
    -- "Tire" as a camelCase word), so "excludes" rules those back out.
    -- tool2 (TirePump) is checked for presence only, never consumed --
    -- same as the original mod's behavior. alsoInflatesTire tells
    -- Server.lua to also restore air pressure, not just condition.
    Tire = {
        matches = { "Tire" },
        excludes = { "Pump", "Kit", "Piece" },
        required = {
            tool = "Base.Screwdriver",
            tool2 = "Base.TirePump",
            material = "Base.TirePiece",
            kit = "Base.TireRepairKit",
        },
        repairAmount = 25,
        skillCaps = {40, 75, 100},
        alsoInflatesTire = true,
    },
}

CarPartRepair_Util.Rules = RepairRules

---------------------------------------------------------
-- Find an item by its network ID inside a given ItemContainer.
-- We deliberately do NOT rely on a single "getItemFromID"-style
-- method, since that wasn't confirmed to exist in this build and
-- threw "tried to call nil" on the server. getItems()/getID() is
-- long-established, documented base-game behavior, so we use that
-- directly instead of trusting a guessed shortcut.
---------------------------------------------------------
function CarPartRepair_Util.findItemByID(inv, id)
    if not inv or not id then return nil end

    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it and it:getID() == id then
            return it
        end
    end

    return nil
end

---------------------------------------------------------
-- Check whether an inventory contains an item of the given
-- fullType (e.g. "Base.SheetMetal"). We use one hand-rolled
-- check everywhere instead of mixing inv:contains() and
-- inv:containsType() -- those are two different built-in
-- methods and we hit a real bug from them apparently expecting
-- different string formats (contains() worked with "Base.X",
-- containsType() did not, even with a confirmed-correct item
-- in inventory). This is slower but predictable and gives us
-- one thing to trust.
---------------------------------------------------------
function CarPartRepair_Util.containsFullType(inv, fullType)
    if not inv or not fullType then return false end

    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it and it:getFullType() == fullType then
            return true
        end
    end

    return false
end

---------------------------------------------------------
-- Keyword boundary check for PascalCase item fullTypes.
-- PZ item names concatenate words directly with no separator
-- (e.g. "FrontDoor2", "TailgateWI"), so we can't require a
-- boundary BEFORE the keyword -- any uppercase letter legally
-- starts a new word. We only guard the END: reject a match if
-- the very next character is lowercase, since that means we're
-- mid-word (e.g. "Hood" inside "Hoodie"). Verified against:
-- FrontDoor2, EngineDoor, TailgateWI, HoodOffroad -> all match;
-- Hoodie, Hoodlum -> correctly rejected.
---------------------------------------------------------
local function keywordMatches(fullType, keyword)
    return fullType:find(keyword .. "%f[^%l]") ~= nil
end

---------------------------------------------------------
-- Identify which part group this item belongs to.
-- Rules can optionally set "excludes" -- a list of keywords that,
-- if ALSO present, disqualify an otherwise-matching item. This is
-- needed for Tire specifically: "Base.TirePump", "Base.TireRepairKit"
-- and "Base.TirePiece" all legitimately contain "Tire" as a valid
-- camelCase word (same reasoning that lets "FrontDoor" match "Door"),
-- so a positive keyword alone can't tell an actual tire apart from
-- its own accessory items. No other rule currently needs this.
---------------------------------------------------------
function CarPartRepair_Util.identifyPart(item)
    local ft = item:getFullType()
    dbg("identifyPart: " .. ft)

    for partName, rule in pairs(RepairRules) do
        local matched = false
        for _, keyword in ipairs(rule.matches) do
            if keywordMatches(ft, keyword) then
                matched = true
                break
            end
        end

        if matched and rule.excludes then
            for _, ex in ipairs(rule.excludes) do
                if keywordMatches(ft, ex) then
                    dbg("Excluded from " .. partName .. " via " .. ex)
                    matched = false
                    break
                end
            end
        end

        if matched then
            dbg("Matched part: " .. partName)
            return partName, rule
        end
    end

    return nil, nil
end

---------------------------------------------------------
-- Can repair this part? Used on BOTH client (for menu/tooltip)
-- and server (for real validation — never trust the client's word).
---------------------------------------------------------
function CarPartRepair_Util.canRepairPart(player, item, rule)
    dbg("canRepairPart: checking " .. item:getFullType())

    local inv = player:getInventory()

    if not CarPartRepair_Util.containsFullType(inv, rule.required.tool) then
        return false, "Missing tool"
    end

    -- Optional second required tool. Only Tire uses this right now
    -- (TirePump) -- checked for presence like any tool, never consumed.
    if rule.required.tool2 and not CarPartRepair_Util.containsFullType(inv, rule.required.tool2) then
        return false, "Missing second tool"
    end

    if not CarPartRepair_Util.containsFullType(inv, rule.required.material) then
        return false, "Missing material"
    end

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