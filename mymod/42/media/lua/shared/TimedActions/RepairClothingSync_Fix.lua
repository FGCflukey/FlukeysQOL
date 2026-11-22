-- ===================================================================
--  Clothing patch sync fix (vanilla MP bug)
-- ===================================================================
--  Vanilla ISRepairClothing:complete() only calls syncItemFields() when
--  the garment is NOT being worn. For worn clothing it relies on the
--  SyncClothing/SyncVisuals packets that Java's Clothing.addPatch()
--  sends. But addPatch() has an early-return "fully restore" branch
--  (Tailoring 8+, patch fabric matches the garment's FabricType, part
--  has a hole) that removes the hole and adds condition, then returns
--  BEFORE that sync. So the server fixes the hole and the client is
--  never told:
--    1st patch: "does nothing" (the client still shows the hole)
--    2nd patch: the server now sees no hole, adds a plain patch and
--               syncs, so the hole finally shows as patched
--    remove patch: the client finally gets the real condition, which
--               the 1st patch had already fully restored (100%)
--  Same idea as vanilla ISWashClothing: always syncItemFields +
--  syncVisuals after changing a garment, worn or not.
-- ===================================================================

require "TimedActions/ISRepairClothing"
require "TimedActions/ISRemovePatch"

local DEBUG = false
local function dbg(msg)
    if DEBUG then print("[RepairClothingSync] " .. tostring(msg)) end
end

local function syncWorn(character, clothing)
    if not isServer() or not character or not clothing then return end
    if not character:isEquippedClothing(clothing) then return end -- vanilla already synced it
    syncItemFields(character, clothing)
    syncVisuals(character)
    dbg("synced worn " .. tostring(clothing:getType()) .. " cond=" .. tostring(clothing:getCondition()))
end

if ISRepairClothing and type(ISRepairClothing.complete) == "function" and not ISRepairClothing.__qolSyncFix then
    ISRepairClothing.__qolSyncFix = true
    local orig = ISRepairClothing.complete
    function ISRepairClothing:complete()
        local result = orig(self)
        if result then syncWorn(self.character, self.clothing) end
        return result
    end
end

if ISRemovePatch and type(ISRemovePatch.complete) == "function" and not ISRemovePatch.__qolSyncFix then
    ISRemovePatch.__qolSyncFix = true
    local orig = ISRemovePatch.complete
    function ISRemovePatch:complete()
        local result = orig(self)
        if result then syncWorn(self.character, self.clothing) end
        return result
    end
end
