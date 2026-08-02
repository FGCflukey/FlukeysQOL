-- media/lua/client/TireRepair/TireRepair_Context.lua

-- require "TireRepair.TireRepair_Util"   -- REMOVE
-- require "TireRepair.TireRepair_Action" -- REMOVE

local Util = TireRepair_Util
local Action = TireRepair_Action

local DEBUG = false
local function dbg(msg) if DEBUG then print("[TireRepair:Context] " .. tostring(msg)) end end

local function OnFillInventoryObjectContextMenu(playerIndex, context, items)
    local player = getSpecificPlayer(playerIndex)
    if not player then
        dbg("no player")
        return
    end

    dbg("context triggered itemsCount=" .. #items)

    local tire = TireRepair_Util.findTireInContext(items, player)
    if not tire then
        dbg("no tire found")
        return
    end

    dbg("found tire=" .. tire:getFullType())

    local ok, reason = TireRepair_Util.canRepairTire(player, tire)
    dbg("canRepairTire ok=" .. tostring(ok) .. " reason=" .. tostring(reason))

    -- NEW: Show message when tire cannot be improved further
    if not ok then
        if reason == "Tire condition cannot be improved further" then
            player:Say("I can't repair this tire any further.")
        end
        dbg("not adding option: " .. reason)
        return
    end

    dbg("adding Repair Tire option")
    context:addOption("Repair Tire", player, TireRepair_Action.startRepair, tire)
end

Events.OnFillInventoryObjectContextMenu.Add(OnFillInventoryObjectContextMenu)
