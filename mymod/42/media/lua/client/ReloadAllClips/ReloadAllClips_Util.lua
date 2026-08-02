-- media/lua/client/ReloadAllClips/ReloadAllClips_Util.lua

ReloadAllClips_Util = {}

local DEBUG = false

local function dbg(msg)
    if DEBUG then
        print("[ReloadAllClips:Util] " .. tostring(msg))
    end
end

---------------------------------------------------------
-- Check if an item behaves like a magazine
---------------------------------------------------------
function ReloadAllClips_Util.isMagazine(item)
    if not item then
        dbg("isMagazine: item is nil")
        return false
    end
    if not item.getCurrentAmmoCount then
        dbg("isMagazine: item has no getCurrentAmmoCount: " .. tostring(item))
        return false
    end
    if not item.getMaxAmmo then
        dbg("isMagazine: item has no getMaxAmmo: " .. tostring(item))
        return false
    end
    if not item.getAmmoType then
        dbg("isMagazine: item has no getAmmoType: " .. tostring(item))
        return false
    end

    local ammoType = item:getAmmoType()
    dbg("isMagazine: item=" .. tostring(item:getFullType()) ..
        " | ammoType=" .. tostring(ammoType) ..
        " | type=" .. tostring(type(ammoType)))

    if not ammoType then
        dbg("isMagazine: ammoType is nil for " .. tostring(item:getFullType()))
        return false
    end

    -- Build 42.19: ammoType may be a string OR an ItemType
    if type(ammoType) == "string" then
        local ok = ammoType ~= ""
        dbg("isMagazine: ammoType is string, non-empty=" .. tostring(ok))
        return ok
    end

    -- Legacy ItemType path
    if ammoType.getItemKey then
        local key = ammoType:getItemKey()
        dbg("isMagazine: ammoType ItemType key=" .. tostring(key))
        return key and key ~= ""
    end

    dbg("isMagazine: ammoType is unsupported type for " .. tostring(item:getFullType()))
    return false
end

---------------------------------------------------------
-- Get bullet item type from magazine
---------------------------------------------------------
function ReloadAllClips_Util.getBulletType(item)
    if not ReloadAllClips_Util.isMagazine(item) then
        dbg("getBulletType: item is not a magazine: " .. tostring(item and item:getFullType()))
        return nil
    end

    local ammoType = item:getAmmoType()
    dbg("getBulletType: raw ammoType=" .. tostring(ammoType) ..
        " | type=" .. tostring(type(ammoType)))

    if not ammoType then
        dbg("getBulletType: ammoType is nil for " .. tostring(item:getFullType()))
        return nil
    end

    local key = nil

    -- Build 42.19: ammoType may be a string (e.g. 'Base.Bullets9mm')
    if type(ammoType) == "string" then
        key = ammoType
        dbg("getBulletType: using string ammoType as key=" .. tostring(key))
    elseif ammoType.getItemKey then
        key = ammoType:getItemKey()
        dbg("getBulletType: using ItemType:getItemKey()=" .. tostring(key))
    else
        dbg("getBulletType: unsupported ammoType type for " .. tostring(item:getFullType()))
        return nil
    end

    if not key or key == "" then
        dbg("getBulletType: key is nil/empty for " .. tostring(item:getFullType()))
        return nil
    end

    -- IMPORTANT: we keep the full type (e.g. 'Base.Bullets9mm')
    -- so it matches inventory:getAllType(bulletType) and containsType(bulletType)
    dbg("getBulletType: final bulletType key=" .. tostring(key))
    return key
end

---------------------------------------------------------
-- Get pluralized display name for a magazine group
---------------------------------------------------------
local function pluralizeDisplayName(name)
    if not name or name == "" then
        return "Magazines"
    end

    -- Already plural
    if name:sub(-1) == "s" then
        return name
    end

    -- Ends with "Magazine"
    if name:sub(-8):lower() == "magazine" then
        return name .. "s"
    end

    -- Ends with "Mag"
    if name:sub(-3):lower() == "mag" then
        return name .. "s"
    end

    -- Ends with "Clip"
    if name:sub(-4):lower() == "clip" then
        return name .. "s"
    end

    -- Default: just add "s"
    return name .. "s"
end

function ReloadAllClips_Util.getPluralMagazineName(item)
    local name = item:getDisplayName() or "Magazine"
    local plural = pluralizeDisplayName(name)
    dbg("getPluralMagazineName: '" .. tostring(name) .. "' -> '" .. tostring(plural) .. "'")
    return plural
end

---------------------------------------------------------
-- Group magazines by bullet type
---------------------------------------------------------
function ReloadAllClips_Util.groupMagazinesByBulletType(items)
    dbg("groupMagazinesByBulletType: input count=" .. tostring(#items))
    local groups = {}

    for _, item in ipairs(items) do
        dbg("groupMagazinesByBulletType: considering item=" .. tostring(item:getFullType()))
        if ReloadAllClips_Util.isMagazine(item) then
            local bulletType = ReloadAllClips_Util.getBulletType(item)
            dbg("groupMagazinesByBulletType: item=" .. tostring(item:getFullType()) ..
                " | bulletType=" .. tostring(bulletType))
            if bulletType then
                if not groups[bulletType] then
                    dbg("groupMagazinesByBulletType: creating new group for bulletType=" .. tostring(bulletType))
                    groups[bulletType] = {
                        bulletType = bulletType,
                        mags = {},
                        sampleMag = item, -- for naming
                    }
                end
                dbg("groupMagazinesByBulletType: adding mag to group bulletType=" ..
                    tostring(bulletType) .. " | mag=" .. tostring(item:getFullType()))
                table.insert(groups[bulletType].mags, item)
            else
                dbg("groupMagazinesByBulletType: bulletType is nil for item=" ..
                    tostring(item:getFullType()))
            end
        else
            dbg("groupMagazinesByBulletType: item is not a magazine: " ..
                tostring(item:getFullType()))
        end
    end

    local groupCount = 0
    for bt, g in pairs(groups) do
        groupCount = groupCount + 1
        dbg("groupMagazinesByBulletType: group bulletType=" .. tostring(bt) ..
            " | magCount=" .. tostring(#g.mags))
    end
    dbg("groupMagazinesByBulletType: total groups=" .. tostring(groupCount))

    return groups
end
