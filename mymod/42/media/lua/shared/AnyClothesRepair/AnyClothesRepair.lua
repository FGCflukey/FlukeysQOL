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
-- CORRECTION (found via live testing 2026-09-24): originally this checked
-- instanceof(item, "Clothing") instead of the below -- that was wrong.
-- getAllItems() returns the static script-DEFINITION objects from
-- ScriptManager, not runtime item instances, and those definition objects
-- are not instanceof "Clothing" even for a real clothing item type --
-- instanceof(item, "Clothing") was false for literally every item in the
-- game, so the scan silently patched nothing at all (confirmed: "gave 0
-- clothing item(s)", no errors -- instanceof just never once passed).
--
-- The original "Repair Any Clothes" mod never used instanceof either --
-- it duck-types instead (`if item.getFabricType and type(item.getFabricType)
-- == "function"`), which is why IT could at least set FabricType on these
-- same definition objects. We keep that proven duck-type check, but swap
-- its OTHER check (getBloodClothingType -> BloodClothingType.
-- getCoveredPartCount(), the actual source of the KATTAJ1 bug) for
-- getBodyLocation() being non-empty instead -- confirmed present and
-- populated on KATTAJ1's own items directly from their item script
-- (BodyLocation = KATTAJ1:UpperArms, etc.), so it isn't exposed to the
-- same failure, while still only touching real wearable clothing.
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
        print("[AnyClothesRepair] getAllItems() returned nothing, aborting")
        return
    end

    -- pcall per item, not around the whole loop: this scans every item
    -- across every mod installed, and without this, a single item that
    -- throws on getFabricType/getBodyLocation/DoParam (a malformed
    -- modded item, for instance) would silently kill the loop right
    -- there -- everything after that point in the list would never get
    -- patched, with no error clearly pointing at why.
    local patched = 0
    local errors = 0
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local ok, err = pcall(function()
            if not item or not item.getFabricType or type(item.getFabricType) ~= "function" then
                return
            end
            if item:getFabricType() then
                return -- already set, leave it alone
            end

            -- getBodyLocation() gets its own inner pcall -- unlike
            -- getFabricType/DoParam (proven safe by the original mod's
            -- long track record with no crash protection at all), this
            -- one isn't proven safe on every item type, and a matching
            -- symptom already showed up on this exact class of native
            -- call for a different mod earlier this session (FlashGate).
            local hasBodyLocation = false
            if item.getBodyLocation and type(item.getBodyLocation) == "function" then
                local locOk, loc = pcall(function() return item:getBodyLocation() end)
                hasBodyLocation = locOk and loc ~= nil and loc ~= ""
            end
            if not hasBodyLocation then
                return -- not a real wearable item
            end

            item:DoParam("FabricType = " .. DEFAULT_FABRIC_TYPE)
            patched = patched + 1

            -- item:getFullType() turned out to be exactly what was
            -- throwing "tried to call nil" for a batch of items on the
            -- last test -- even though the FabricType assignment right
            -- above it had already succeeded. Its own pcall here means a
            -- bad getFullType() call only loses that one log line, never
            -- the count above or the rest of the scan.
            if DEBUG then
                local nameOk, name = pcall(function() return item:getFullType() end)
                dbg("Set FabricType=" .. DEFAULT_FABRIC_TYPE .. " on " .. tostring(nameOk and name or "<unknown item>"))
            end
        end)
        if not ok then
            errors = errors + 1
            -- DEBUG-gated, not always-on: with getFabricType/DoParam
            -- proven safe and getBodyLocation individually pcall'd above,
            -- anything still reaching here is a genuinely unusual item --
            -- worth seeing while actively testing, not worth spamming the
            -- log with by default given how many items this scans.
            if DEBUG then
                print("[AnyClothesRepair] error on item index " .. tostring(i) .. ": " .. tostring(err))
            end
        end
    end

    print("[AnyClothesRepair] Done -- gave " .. patched .. " clothing item(s) a FabricType so they can be mended" ..
        (errors > 0 and (" (" .. errors .. " item(s) threw and were skipped)") or ""))
end

Events.OnGameBoot.Add(AnyClothesRepair)
