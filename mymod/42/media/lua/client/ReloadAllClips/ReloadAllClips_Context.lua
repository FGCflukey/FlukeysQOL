-- media/lua/client/ReloadAllClips/ReloadAllClips_Context.lua

require "ReloadAllClips.ReloadAllClips_Util"
require "ReloadAllClips.ReloadAllClips_Core"

local DEBUG = false

local function dbg(msg)
    if DEBUG then
        print("[ReloadAllClips:Core] " .. tostring(msg))
    end
end

---------------------------------------------------------
-- Flatten context items into actual inventory items
---------------------------------------------------------
local function collectItemsFromContext(items)
    local result = {}

    for _, v in ipairs(items) do
        if v.items then
            -- Stacked items
            dbg("Expanding stacked items: count=" .. tostring(#v.items))
            for i = 1, #v.items do
                local item = v.items[i]
                if item and item.getFullType then
                    table.insert(result, item)
                end
            end
        else
            local item = v
            if item and item.getFullType then
                table.insert(result, item)
            end
        end
    end

    return result
end

---------------------------------------------------------
-- Context menu hook
---------------------------------------------------------
local function OnFillInventoryObjectContextMenu(playerIndex, context, items)
    local playerObj = getSpecificPlayer(playerIndex)
    if not playerObj then return end

    dbg("Context menu triggered.")

    local flatItems = collectItemsFromContext(items)

    -- Filter to magazines only
    local mags = {}
    for _, item in ipairs(flatItems) do
        if ReloadAllClips_Util.isMagazine(item) then
            dbg("Detected magazine: " .. item:getFullType())
            table.insert(mags, item)
        end
    end

    if #mags == 0 then
        dbg("No magazines detected in selection.")
        return
    end

    -- Group by bullet type
    local groups = ReloadAllClips_Util.groupMagazinesByBulletType(mags)

    for bulletType, group in pairs(groups) do
        dbg("Processing group for bulletType=" .. bulletType ..
            " | magCount=" .. tostring(#group.mags))

        local inv = playerObj:getInventory()
        local bulletList = inv:getAllType(bulletType)
        local bulletCount = bulletList:size()

        local pluralName = ReloadAllClips_Util.getPluralMagazineName(group.sampleMag)

        -------------------------------------------------
        -- Reload option
        -------------------------------------------------
        if bulletCount > 0 and ReloadAllClips_Core.anyMagNeedsAmmo(group.mags) then
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
            dbg("No reload option: either no bullets or all mags full.")
        end

        -------------------------------------------------
        -- Unload option
        -------------------------------------------------
        if ReloadAllClips_Core.anyMagHasAmmo(group.mags) then
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