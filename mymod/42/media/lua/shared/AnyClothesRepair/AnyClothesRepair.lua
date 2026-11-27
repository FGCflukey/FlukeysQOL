-- media/lua/shared/AnyClothesRepair/AnyClothesRepair.lua
--
-- Makes every wearable clothing item mendable. Vanilla's "Patch Hole" /
-- "Add Padding" options (ISGarmentUI.lua) only need item:getFabricType()
-- to be set, so at boot this gives a default FabricType to every item
-- definition that has a BodyLocation and no FabricType yet.
--
-- Notes:
--   * getAllItems() returns script DEFINITIONS, not item instances, so
--     instanceof(item, "Clothing") is false for all of them. We check for
--     the methods instead.
--   * BodyLocation is used to detect clothing because it's set on modded
--     clothing too (custom BodyLocations included). BloodClothingType's
--     covered-part count returns 0 for custom locations, so it misses them.
--   * Lives in shared/: DoParam changes the ScriptManager definition, which
--     both client and server need to agree on.
--   * Items that already have a FabricType are left alone.

local DEBUG = false
local function dbg(msg)
    if DEBUG then
        print("[AnyClothesRepair] " .. tostring(msg))
    end
end

-- Flat default for every item this touches. A generic scan can't reliably
-- tell cotton from denim per item, so one default beats guessing wrong.
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

            -- getBodyLocation() gets its own pcall: it can throw on some
            -- modded item types.
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
