-- media/lua/client/ReloadAllClips/ReloadAllClips_Context.lua

-- require "ReloadAllClips_Util"
-- require "ReloadAllClips_Core"
local Util = ReloadAllClips_Util
local Core = ReloadAllClips_Core

local DEBUG = false

local function dbg(msg)
    if DEBUG then
        print("[ReloadAllClips:Context] " .. tostring(msg))
    end
end

---------------------------------------------------------
-- Flatten context items into actual inventory items
---------------------------------------------------------
local function collectItemsFromContext(items)
    local result = {}

    dbg("collectItemsFromContext: raw items count=" .. tostring(#items))

    for idx, v in ipairs(items) do
        if v.items then
            -- Stacked items
            dbg("Expanding stacked items at index=" .. tostring(idx) ..
                " | stackCount=" .. tostring(#v.items))
            for i = 1, #v.items do
                local item = v.items[i]
                if item and item.getFullType then
                    dbg("  -> stacked item[" .. tostring(i) .. "] fullType=" ..
                        tostring(item:getFullType()))
                    table.insert(result, item)
                else
                    dbg("  -> stacked item[" .. tostring(i) .. "] is invalid or has no getFullType")
                end
            end
        else
            local item = v
            if item and item.getFullType then
                dbg("Single item at index=" .. tostring(idx) ..
                    " fullType=" .. tostring(item:getFullType()))
                table.insert(result, item)
            else
                dbg("Single item at index=" .. tostring(idx) ..
                    " is invalid or has no getFullType")
            end
        end
    end

    dbg("collectItemsFromContext: flattened count=" .. tostring(#result))
    return result
end

---------------------------------------------------------
-- Context menu hook
---------------------------------------------------------
local function OnFillInventoryObjectContextMenu(playerIndex, context, items)
    local playerObj = getSpecificPlayer(playerIndex)
    if not playerObj then
        dbg("OnFillInventoryObjectContextMenu: no playerObj for index=" .. tostring(playerIndex))
        return
    end

    dbg("Context menu triggered for playerIndex=" .. tostring(playerIndex))

    local flatItems = collectItemsFromContext(items)

    -- Filter to magazines only
    local mags = {}
    for _, item in ipairs(flatItems) do
        local isMag = ReloadAllClips_Util.isMagazine(item)
        dbg("Checking item fullType=" .. tostring(item:getFullType()) ..
            " | isMagazine=" .. tostring(isMag))
        if isMag then
            dbg("Detected magazine: " .. tostring(item:getFullType()))
            table.insert(mags, item)
        end
    end

    dbg("Total magazines detected=" .. tostring(#mags))

    if #mags == 0 then
        dbg("No magazines detected in selection.")
        return
    end

    -- Group by bullet type
    local groups = ReloadAllClips_Util.groupMagazinesByBulletType(mags)

    local groupCount = 0
    for _ in pairs(groups) do groupCount = groupCount + 1 end
    dbg("Total groups by bulletType=" .. tostring(groupCount))

    for bulletType, group in pairs(groups) do
        dbg("Processing group for bulletType=" .. tostring(bulletType) ..
            " | magCount=" .. tostring(#group.mags))

        local inv = playerObj:getInventory()
        local bulletList = inv:getAllType(bulletType)
        local bulletCount = bulletList and bulletList:size() or 0

        dbg("Inventory bullet lookup: bulletType=" .. tostring(bulletType) ..
            " | bulletCount=" .. tostring(bulletCount))

        local pluralName = ReloadAllClips_Util.getPluralMagazineName(group.sampleMag)

        -------------------------------------------------
        -- Reload option
        -------------------------------------------------
        local needsAmmo = ReloadAllClips_Core.anyMagNeedsAmmo(group.mags)
        dbg("Group needs ammo? " .. tostring(needsAmmo))

        if bulletCount > 0 and needsAmmo then
            local label = "Reload All " .. pluralName
            dbg("Adding reload option: " .. label ..
                " | bullets=" .. tostring(bulletCount))
            context:addOption(
                label,
                playerObj,
                ReloadAllClips_Core.doReloadAll,
                group
            )
        else
            dbg("No reload option: either no bullets or all mags full. " ..
                "bulletCount=" .. tostring(bulletCount) ..
                " | needsAmmo=" .. tostring(needsAmmo))
        end

        -------------------------------------------------
        -- Unload option
        -------------------------------------------------
        local hasAmmo = ReloadAllClips_Core.anyMagHasAmmo(group.mags)
        dbg("Group has ammo? " .. tostring(hasAmmo))

        if hasAmmo then
            local label = "Unload All " .. pluralName
            dbg("Adding unload option: " .. label)
            context:addOption(
                label,
                playerObj,
                ReloadAllClips_Core.doUnloadAll,
                group
            )
        else
            dbg("No unload option: all mags empty.")
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(OnFillInventoryObjectContextMenu)
