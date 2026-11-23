-- media/lua/shared/CarPartRepair/CarPartRepair_Util.lua
-- IMPORTANT: this file now needs to live under media/lua/shared/ (not client/)
-- so both the client context menu AND the server command handler can require it.
-- Using one shared copy avoids the rules ever drifting between client/server.

CarPartRepair_Util = {}

local DEBUG = false
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

    -- HUMMER H3 (Workshop 3832058760) add-on parts. Matched by EXACT
    -- fullType only (never keywords -- "Armor"/"Bumper" would catch other
    -- mods' clothing etc.). Vanilla can't repair these once broken (no
    -- repairMechanic on the H3 parts, and the inventory Repair menu hides
    -- broken items), so this is their only repair path. If the H3 mod is
    -- removed these types just never exist, so nothing to disable here.
    H3Armor = {
        label = "H3 Armor",
        exactTypes = {
            "Base.PibeH3ArmorBullbar2",
            "Base.PibeH3ArmorPlow2",
            "Base.PibeH3ArmorRamFront2",
            "Base.PibeH3RamRearBumper2",
            "Base.PibeH3RearBumper2",
            "Base.PibeH3ArmorWindshield2",
            "Base.PibeH3ArmorWindowFront2",
            "Base.PibeH3ArmorWindowRear2",
            "Base.PibeH3ArmorRearWindow2",
            "Base.PibeH3RollBar2",
            "Base.PibeH3RoofRack2",
            "Base.PibeH3Snorkel2",
            "Base.PibeH3GloveBox2",
        },
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
}

-- Build exact-type lookup sets once.
for _, rule in pairs(RepairRules) do
    if rule.exactTypes then
        rule.exactSet = {}
        for _, ft in ipairs(rule.exactTypes) do rule.exactSet[ft] = true end
    end
end

CarPartRepair_Util.Rules = RepairRules

---------------------------------------------------------
-- Find an item by its network ID inside a given ItemContainer.
-- We deliberately do NOT rely on a single "getItemFromID"-style
-- method, since that wasn't confirmed to exist in this build and
-- threw "tried to call nil" on the server. getItems()/getID() is
-- long-established, documented base-game behavior, so we use that
-- directly instead of trusting a guessed shortcut.
--
-- Recurses into nested containers (e.g. a worn backpack or the
-- dolly) -- same proven pattern already used in
-- CarPartDismantle_Server.lua. A part item that isn't in top-level
-- main inventory used to come back "not found" server-side even
-- though the client's canRepairPart() check passed, since that
-- check (now recursive itself) doesn't guarantee the part ITEM
-- being repaired is at the top level too.
---------------------------------------------------------
function CarPartRepair_Util.findItemByID(inv, id)
    if not inv or not id then return nil end

    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it and it:getID() == id then
            return it
        end

        if instanceof(it, "InventoryContainer") then
            local nested = CarPartRepair_Util.findItemByID(it:getInventory(), id)
            if nested then return nested end
        end
    end

    return nil
end

---------------------------------------------------------
-- Find an item by ID anywhere the player can reach: their own
-- inventory (worn backpack/dolly included, via findItemByID above),
-- OR a nearby world container -- a crate, wardrobe, vehicle trunk,
-- etc. -- that a right-click on an item in its open loot panel can
-- also reach via OnFillInventoryObjectContextMenu, but which is a
-- completely separate ItemContainer tree, never nested inside the
-- player's own inventory.
--
-- containerX/Y/Z is the square the client reports the item's
-- container sitting on (captured client-side from
-- item:getContainer():getParent():getSquare() at the moment the
-- repair action was queued). It's just a hint, never trusted blindly
-- -- re-validated here against the player's actual current distance
-- to that square before searching it, same reachability margin
-- vanilla's own luautils.walkToContainer() uses for containers.
---------------------------------------------------------
function CarPartRepair_Util.findItemNearby(player, id, containerX, containerY, containerZ)
    local inv = player:getInventory()
    local found = CarPartRepair_Util.findItemByID(inv, id)
    if found then return found end

    if not containerX or not containerY or not containerZ then return nil end

    local square = getSquare(containerX, containerY, containerZ)
    if not square then return nil end

    local playerSquare = player:getSquare()
    if not playerSquare or playerSquare:DistToProper(square) > 2 then
        return nil
    end

    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and obj.getContainer then
            local ok, container = pcall(obj.getContainer, obj)
            if ok and container then
                found = CarPartRepair_Util.findItemByID(container, id)
                if found then return found end
            end
        end
    end

    return nil
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

    -- Exact-type rules win over keyword rules.
    for partName, rule in pairs(RepairRules) do
        if rule.exactSet and rule.exactSet[ft] then
            dbg("Exact match: " .. partName)
            return partName, rule
        end
    end

    for partName, rule in pairs(RepairRules) do
        local matched = false
        for _, keyword in ipairs(rule.matches or {}) do
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
---------------------------------------------------------
-- Highest condition one repair can reach. skillCaps are PERCENTAGES
-- of the part's own ConditionMax (not absolute numbers), so parts with
-- a max above 100 -- e.g. the H3 chained tire (ConditionMax 140) --
-- can still be repaired to full at high skill. For normal 100-max
-- parts this gives exactly the same numbers as before.
---------------------------------------------------------
function CarPartRepair_Util.getMaxRepair(player, item, rule)
    local lvl = player:getPerkLevel(Perks.Mechanics)
    local capPct =
        (lvl <= 4) and rule.skillCaps[1] or
        (lvl <= 8) and rule.skillCaps[2] or
        rule.skillCaps[3]

    local condMax = (item.getConditionMax and item:getConditionMax()) or 100
    if not condMax or condMax <= 0 then condMax = 100 end

    return math.floor(condMax * capPct / 100)
end

-- Finds the tool to use for this rule (recursive: backpack/dolly count).
-- For a fuel-consuming tool (BlowTorch) it must have at least
-- toolUsesPerRepair uses left -- picking "the first torch found" used to
-- grab an empty one, and the server then drained it 2 uses past zero
-- (torches are KeepOnDeplete, so they never disappear to stop the loop),
-- leaving a torch at a negative charge that the refill recipe rejects.
-- Returns: tool (or nil), anyPresent (true if one exists but lacks fuel).
function CarPartRepair_Util.findTool(inv, rule)
    local toolType = rule.required.tool
    if not rule.toolConsumesUses then
        local t = inv:getFirstTypeRecurse(toolType)
        return t, t ~= nil
    end
    local need = rule.toolUsesPerRepair or 1
    local all = inv:getAllTypeRecurse(toolType)
    local best = nil
    for i = 0, all:size() - 1 do
        local t = all:get(i)
        local uses = t.getCurrentUses and t:getCurrentUses() or 0
        -- use the emptiest torch that still has enough, so fuller ones are saved
        if uses >= need and (not best or uses < best:getCurrentUses()) then
            best = t
        end
    end
    return best, all:size() > 0
end

function CarPartRepair_Util.canRepairPart(player, item, rule)
    dbg("canRepairPart: checking " .. item:getFullType())

    local inv = player:getInventory()

    -- Tool/material presence is checked recursively (getFirstTypeRecurse,
    -- same call already used below for the kit) so a tool or material
    -- sitting in a worn backpack or dolly counts -- not just the top-level
    -- main inventory. containsFullType() only ever walked getItems() at
    -- the top level, which is why these used to report "Missing" for
    -- anything not dragged into main inventory first.
    local tool, anyTool = CarPartRepair_Util.findTool(inv, rule)
    if not tool then
        return false, anyTool and "Not enough fuel in tool" or "Missing tool"
    end

    -- Optional second required tool. Only Tire uses this right now
    -- (TirePump) -- checked for presence like any tool, never consumed.
    if rule.required.tool2 then
        local tool2 = inv:getFirstTypeRecurse(rule.required.tool2)
        if not tool2 then
            return false, "Missing second tool"
        end
    end

    local material = inv:getFirstTypeRecurse(rule.required.material)
    if not material then
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

    local maxRepair = CarPartRepair_Util.getMaxRepair(player, item, rule)

    if item:getCondition() >= maxRepair then
        return false, "Part condition cannot be improved further"
    end

    return true, nil
end