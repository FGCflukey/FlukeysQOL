-- media/lua/client/ReloadAllClips/ReloadAllClips_Util.lua

ReloadAllClips_Util = {}

local DEBUG = false


local function dbg(msg)
    if DEBUG then
        print("[ReloadAllClips:Core] " .. tostring(msg))
    end
end

---------------------------------------------------------
-- Check if an item behaves like a magazine
---------------------------------------------------------
function ReloadAllClips_Util.isMagazine(item)
    if not item then return false end
    if not item.getCurrentAmmoCount then return false end
    if not item.getMaxAmmo then return false end
    if not item.getAmmoType then return false end

    local ok, ammoType = pcall(function() return item:getAmmoType() end)
    if not ok or not ammoType then return false end

    local ok2, key = pcall(function() return ammoType:getItemKey() end)
    if not ok2 or not key or key == "" then return false end

    return true
end

---------------------------------------------------------
-- Get bullet item type from magazine
---------------------------------------------------------
function ReloadAllClips_Util.getBulletType(item)
    if not ReloadAllClips_Util.isMagazine(item) then return nil end

    local ammoType = item:getAmmoType()
    if not ammoType then return nil end

    local key = ammoType:getItemKey()
    if not key or key == "" then return nil end

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
    dbg("Pluralized '" .. name .. "' -> '" .. plural .. "'")
    return plural
end

---------------------------------------------------------
-- Group magazines by bullet type
---------------------------------------------------------
function ReloadAllClips_Util.groupMagazinesByBulletType(items)
    local groups = {}

    for _, item in ipairs(items) do
        if ReloadAllClips_Util.isMagazine(item) then
            local bulletType = ReloadAllClips_Util.getBulletType(item)
            if bulletType then
                groups[bulletType] = groups[bulletType] or {
                    bulletType = bulletType,
                    mags = {},
                    sampleMag = item, -- for naming
                }
                table.insert(groups[bulletType].mags, item)
            end
        end
    end

    return groups
end