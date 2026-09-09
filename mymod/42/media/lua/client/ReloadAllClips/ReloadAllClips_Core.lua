-- media/lua/client/ReloadAllClips/ReloadAllClips_Core.lua

-- require "ReloadAllClips_Util"
local Util = ReloadAllClips_Util

ReloadAllClips_Core = {}

local DEBUG = false

local function dbg(msg)
    if DEBUG then
        print("[ReloadAllClips:Core] " .. tostring(msg))
    end
end

---------------------------------------------------------
-- Any magazine needs ammo?
---------------------------------------------------------
function ReloadAllClips_Core.anyMagNeedsAmmo(mags)
    dbg("anyMagNeedsAmmo: checking " .. tostring(#mags) .. " magazines")
    for _, mag in ipairs(mags) do
        local cur = mag:getCurrentAmmoCount()
        local max = mag:getMaxAmmo()
        dbg("  mag=" .. tostring(mag:getFullType()) ..
            " | cur=" .. tostring(cur) ..
            " | max=" .. tostring(max))
        if cur < max then
            dbg("  -> this mag needs ammo")
            return true
        end
    end
    dbg("anyMagNeedsAmmo: no mags need ammo")
    return false
end

---------------------------------------------------------
-- Any magazine has ammo (for unloading)?
---------------------------------------------------------
function ReloadAllClips_Core.anyMagHasAmmo(mags)
    dbg("anyMagHasAmmo: checking " .. tostring(#mags) .. " magazines")
    for _, mag in ipairs(mags) do
        local cur = mag:getCurrentAmmoCount()
        dbg("  mag=" .. tostring(mag:getFullType()) ..
            " | cur=" .. tostring(cur))
        if cur > 0 then
            dbg("  -> this mag has ammo")
            return true
        end
    end
    dbg("anyMagHasAmmo: no mags have ammo")
    return false
end

---------------------------------------------------------
-- Reload all magazines for a given bullet type
---------------------------------------------------------
function ReloadAllClips_Core.doReloadAll(playerObj, group)
    local mags = group.mags
    local bulletType = group.bulletType

    dbg("doReloadAll: bulletType=" .. tostring(bulletType) ..
        " | magCount=" .. tostring(#mags))

    ---------------------------------------------------------
    -- Safety check: ensure player actually has this bullet type
    ---------------------------------------------------------
    local inv = playerObj:getInventory()
    local hasBullets = inv:containsType(bulletType)
    dbg("doReloadAll: inventory containsType(" .. tostring(bulletType) ..
        ") = " .. tostring(hasBullets))

    if not hasBullets then
        dbg("doReloadAll: No matching bullets found for type " .. tostring(bulletType) .. " - aborting.")
        return
    end

    ---------------------------------------------------------
    -- Sort magazines by emptiness (most empty first)
    ---------------------------------------------------------
    dbg("doReloadAll: sorting magazines by emptiness")
    table.sort(mags, function(a, b)
        local aMissing = a:getMaxAmmo() - a:getCurrentAmmoCount()
        local bMissing = b:getMaxAmmo() - b:getCurrentAmmoCount()
        dbg("  sort compare: a=" .. tostring(a:getFullType()) ..
            " missing=" .. tostring(aMissing) ..
            " | b=" .. tostring(b:getFullType()) ..
            " missing=" .. tostring(bMissing))
        return aMissing > bMissing
    end)

    ---------------------------------------------------------
    -- Queue reload actions
    ---------------------------------------------------------
    for _, mag in ipairs(mags) do
        local cur = mag:getCurrentAmmoCount()
        local max = mag:getMaxAmmo()
        local missing = max - cur

        dbg("doReloadAll: mag=" .. tostring(mag:getFullType()) ..
            " | cur=" .. tostring(cur) ..
            " | max=" .. tostring(max) ..
            " | missing=" .. tostring(missing))

        if missing > 0 then
            dbg("Queueing ISLoadBulletsInMagazine for " ..
                tostring(missing) .. " rounds on " .. tostring(mag:getFullType()))

            ISTimedActionQueue.add(
                ISLoadBulletsInMagazine:new(playerObj, mag, missing)
            )
        else
            dbg("Magazine already full, skipping: " .. tostring(mag:getFullType()))
        end
    end
end

---------------------------------------------------------
-- Unload all magazines for a given bullet type
---------------------------------------------------------
function ReloadAllClips_Core.doUnloadAll(playerObj, group)
    local mags = group.mags
    local bulletType = group.bulletType

    dbg("doUnloadAll: bulletType=" .. tostring(bulletType) ..
        " | magCount=" .. tostring(#mags))

    for _, mag in ipairs(mags) do
        local cur = mag:getCurrentAmmoCount()

        dbg("doUnloadAll: mag=" .. tostring(mag:getFullType()) ..
            " | cur=" .. tostring(cur))

        if cur > 0 then
            dbg("Queueing ISUnloadBulletsFromMagazine for mag with " ..
                tostring(cur) .. " rounds: " .. tostring(mag:getFullType()))

            ISTimedActionQueue.add(
                ISUnloadBulletsFromMagazine:new(playerObj, mag)
            )
        else
            dbg("Magazine empty, skipping: " .. tostring(mag:getFullType()))
        end
    end
end
