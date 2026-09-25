-- media/lua/shared/AnyClothesRepair/AnyClothesRepair.lua
--
-- Makes every real clothing item mendable (vanilla's own "Patch Hole" /
-- "Add Padding" options in ISGarmentUI.lua are gated entirely behind
-- item:getFabricType() being set -- nothing else), instead of relying on
-- either third-party mod's approach:
--
--   - "Repair Any Clothes" (Workshop 2142622992) scans getAllItems() at
--     boot too, but decides what counts as "clothing" via
--     item:getBloodClothingType() -> BloodClothingType.getCoveredPartCount()
--     -- confirmed (via live testing on KATTAJ1 Military Pack items) that
--     this silently returns 0 for clothing using a custom BodyLocation, so
--     those items never get patched at all. That's why a separate compat
--     mod had to exist just to hardcode KATTAJ1's item list back in.
--   - "Repair Any Clothes New Version" (Workshop 2984301200) sidesteps that
--     bug by not detecting anything at all -- it's a ~400-line hardcoded
--     list of exact item names across specific popular Workshop mods.
--     Fixes KATTAJ1 specifically (it's in the list) but isn't actually
--     "any clothes" -- anything not explicitly typed into that file,
--     including this pack's own clothing, gets nothing.
--
-- This version checks instanceof(item, "Clothing") instead -- the same
-- real vanilla class check used throughout vanilla's own lua (see
-- ISWashClothing.lua, ISWringClothing.lua, Tutorial1.lua, etc.) -- which
-- has nothing to do with blood-coverage detection at all, so it isn't
-- exposed to that bug, and it needs no per-item or per-mod list: it
-- covers every clothing item in the game, vanilla or modded, present now
-- or added later, automatically.
--
-- Lives in shared/, not client/: item scripts are identical data on both
-- sides and DoParam mutates the shared ScriptManager item definition
-- itself, not per-character state -- but after getting burned once this
-- session by a client-only fix leaving the server's copy of a function
-- unpatched (see the ReloadAllClips setReloadSpeed fix), defaulting to
-- shared/ for anything touching ScriptManager rather than assuming
-- client-only is safe.
--
-- Doesn't touch items that already have a FabricType set -- vanilla or
-- another mod's own deliberate choice is left alone either way.

local DEBUG = false
local function dbg(msg)
    if DEBUG then
        print("[AnyClothesRepair] " .. tostring(msg))
    end
end

-- Flat default for every item this touches. A real per-item material
-- guess (Cotton for cloth-looking items, Denim for jeans/work gear, etc.)
-- would need per-item judgment calls the same way both source mods make
-- them by hand -- not something a generic scan can infer reliably, so
-- this picks one sensible default (matching the original "Repair Any
-- Clothes" mod's own choice) rather than guessing wrong per item.
local DEFAULT_FABRIC_TYPE = "Leather"

local function AnyClothesRepair()
    local items = getAllItems()
    if not items then
        dbg("getAllItems() returned nothing, aborting")
        return
    end

    local patched = 0
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and instanceof(item, "Clothing") and not item:getFabricType() then
            item:DoParam("FabricType = " .. DEFAULT_FABRIC_TYPE)
            patched = patched + 1
            dbg("Set FabricType=" .. DEFAULT_FABRIC_TYPE .. " on " .. tostring(item:getFullType()))
        end
    end

    dbg("Done -- gave " .. patched .. " clothing item(s) a FabricType so they can be mended")
end

Events.OnGameBoot.Add(AnyClothesRepair)
