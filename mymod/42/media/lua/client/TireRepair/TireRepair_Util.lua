-- media/lua/client/TireRepair/TireRepair_Util.lua

TireRepair_Util = {}

local DEBUG = false
local function dbg(msg) if DEBUG then print("[TireRepair:Util] " .. tostring(msg)) end end

---------------------------------------------------------
-- Is this item a tire?
---------------------------------------------------------
function TireRepair_Util.isTire(item)
    if not item or not item.getFullType then
        dbg("isTire: invalid item")
        return false
    end

    local ft = item:getFullType()
    dbg("isTire: fullType=" .. ft)

    if ft:find("Tire") then
        dbg("isTire: matched 'Tire'")
        return true
    end

    return false
end

---------------------------------------------------------
-- Find tire in inventory context selection
---------------------------------------------------------
function TireRepair_Util.findTireInContext(items, player)
    dbg("findTireInContext: itemsCount=" .. #items)

    for idx, v in ipairs(items) do
        if v.items then
            dbg("stack idx=" .. idx .. " count=" .. #v.items)
            for i = 1, #v.items do
                local item = v.items[i]
                dbg("  stack item[" .. i .. "]=" .. item:getFullType())
                if TireRepair_Util.isTire(item) then
                    dbg("  -> returning stacked tire")
                    return item
                end
            end
        else
            local item = v
            dbg("single item idx=" .. idx .. " fullType=" .. item:getFullType())
            if TireRepair_Util.isTire(item) then
                dbg("  -> returning single tire")
                return item
            end
        end
    end

    dbg("no tire in inventory selection")

    -- Check floor
    local sq = player:getSquare()
    if not sq then
        dbg("no player square")
        return nil
    end

    local worldObjs = sq:getWorldObjects()
    dbg("checking floor objects count=" .. worldObjs:size())

    for i = 0, worldObjs:size() - 1 do
        local obj = worldObjs:get(i)
        if obj and obj:getItem() then
            local item = obj:getItem()
            dbg("floor item=" .. item:getFullType())
            if TireRepair_Util.isTire(item) then
                dbg("-> returning floor tire")
                return item
            end
        end
    end

    dbg("no tire found on floor")
    return nil
end

---------------------------------------------------------
-- Check if player can repair given tire
---------------------------------------------------------
function TireRepair_Util.canRepairTire(player, tire)
    dbg("canRepairTire: tire=" .. tire:getFullType())

    local inv = player:getInventory()

    local hasScrewdriver = inv:contains("Base.Screwdriver")
    local hasPump        = inv:contains("Base.TirePump")
    local hasTirePiece   = inv:containsType("Base.TirePiece")
    local repairKit      = inv:getFirstTypeRecurse("Base.TireRepairKit")

    dbg("hasScrewdriver=" .. tostring(hasScrewdriver))
    dbg("hasPump=" .. tostring(hasPump))
    dbg("hasTirePiece=" .. tostring(hasTirePiece))
    dbg("repairKit=" .. tostring(repairKit))

    if not hasScrewdriver then return false, "Missing screwdriver" end
    if not hasPump then return false, "Missing tire pump" end
    if not hasTirePiece then return false, "Missing tire piece" end
    if not repairKit then return false, "Missing repair kit" end

    if not repairKit.getCurrentUses or not repairKit.getMaxUses then
        dbg("repairKit missing getCurrentUses/getMaxUses")
        return false, "Repair kit invalid"
    end

    local uses = repairKit:getCurrentUses()
    local max  = repairKit:getMaxUses()

    dbg("repairKit uses=" .. uses .. " max=" .. max)

    if uses <= 0 then
        return false, "Repair kit empty"
    end

    -- NEW: Mechanics-based cap check
    local lvl = player:getPerkLevel(Perks.Mechanics)
    local maxRepair = (lvl <= 4) and 40 or (lvl <= 8) and 75 or 100

    if tire:getCondition() >= maxRepair then
        return false, "Tire condition cannot be improved further"
    end

    dbg("canRepairTire: OK")
    return true, nil
end

