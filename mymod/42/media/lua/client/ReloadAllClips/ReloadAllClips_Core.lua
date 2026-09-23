-- media/lua/client/ReloadAllClips/ReloadAllClips_Core.lua

-- require "ReloadAllClips_Util"
local Util = ReloadAllClips_Util

ReloadAllClips_Core = {}

---------------------------------------------------------
-- Vanilla bug fix: ISReloadWeaponAction.setReloadSpeed() checks
-- `gun:getAmmoType() == AmmoType.SHOTGUN_SHELLS`, and if that's false,
-- unconditionally calls `gun:getMagazineType()` next -- assuming anything
-- with an ammoType also has a magazineType. A magazine/clip item itself
-- has getAmmoType() (that's exactly how ReloadAllClips_Util.isMagazine
-- detects one) but has no getMagazineType() at all -- only real firearms
-- do. So whenever the character's primary hand holds anything that isn't
-- an actual gun (a magazine, nothing relevant, etc.) while reloading a
-- spare magazine from inventory, this throws "Object tried to call nil
-- in setReloadSpeed" and the reload action never starts.
--
-- Not specific to this feature -- vanilla's own single-magazine "Reload"
-- context option goes through this exact same function and would crash
-- identically any time a player reloads a spare mag while not holding
-- their firearm. Full copy of vanilla's function with that one line
-- guarded (gun.getMagazineType checked before calling it), rather than
-- pcall-swallowing the crash -- everything else here is unchanged vanilla
-- logic, so both paths benefit from the same real fix.
function ISReloadWeaponAction.setReloadSpeed(character, rack)
    local baseReloadSpeed = 0.8;
    if rack then
        baseReloadSpeed = baseReloadSpeed + (character:getPerkLevel(Perks.Reloading) * 0.04);
    else
        baseReloadSpeed = baseReloadSpeed + (character:getPerkLevel(Perks.Reloading) * 0.10);
        baseReloadSpeed = baseReloadSpeed - (character:getMoodles():getMoodleLevel(MoodleType.PANIC) * 0.05);
    end

    local gun = character:getPrimaryHandItem();
    local strap = character:getWornItem(ItemBodyLocation.AMMO_STRAP);
    local reloadFast = character:hasEquippedTag(ItemTag.RELOAD_FAST_SHELLS) or character:hasEquippedTag(ItemTag.RELOAD_FAST_BULLETS)
    local strapFound = false;
    if gun and gun.getMagazineType and (reloadFast or (strap and strap:getClothingItem())) then
        local shell = false;
        local magazine = false;
        if gun:getAmmoType() == AmmoType.SHOTGUN_SHELLS then
            shell = true;
        elseif gun:getMagazineType() then
            magazine = true;
        end
        if magazine and (character:hasEquippedTag(ItemTag.RELOAD_FAST_MAGAZINES) or character:hasWornTag(ItemTag.RELOAD_FAST_MAGAZINES)) then
            strapFound = true;
        elseif shell and (character:hasEquippedTag(ItemTag.RELOAD_FAST_SHELLS) or character:hasWornTag(ItemTag.RELOAD_FAST_SHELLS) or strap:getClothingItemName() == "AmmoStrap_Shells") then
            strapFound = true;
        elseif not shell and not magazine and (character:hasEquippedTag(ItemTag.RELOAD_FAST_BULLETS) or character:hasWornTag(ItemTag.RELOAD_FAST_BULLETS) or strap:getClothingItemName() == "AmmoStrap_Bullets") then
            strapFound = true;
        end
    end
    if strapFound then
        baseReloadSpeed = baseReloadSpeed * 1.15;
    end
    if character:getVehicle() and character:getVehicle():getDriver() == character then
        baseReloadSpeed = baseReloadSpeed * 0.8;
    end
    character:setVariable("ReloadSpeed", baseReloadSpeed);
end

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

            -- ISLoadBulletsInMagazine:isValid() only ever checks the
            -- player's TOP-LEVEL main inventory (containsID/contains,
            -- neither recursive) -- so a magazine sitting in an equipped
            -- bag, or bullets sitting anywhere but main inventory, makes
            -- the queued action silently invalid with no feedback at all.
            -- Vanilla's own single-magazine reload handler
            -- (ISInventoryPaneContextMenu.onLoadBulletsInMagazine) always
            -- transfers both into main inventory first for exactly this
            -- reason -- replicating that here, per magazine, since we're
            -- looping over several instead of vanilla's one-at-a-time UI.
            ISInventoryPaneContextMenu.transferIfNeeded(playerObj, mag)
            local itemKey = mag:getAmmoType():getItemKey()
            local bulletItems = inv:getSomeTypeRecurse(itemKey, missing)
            ISInventoryPaneContextMenu.transferIfNeeded(playerObj, bulletItems)

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

            -- Same fix as doReloadAll above: ISUnloadBulletsFromMagazine's
            -- own isValid() is top-level-only too, matching vanilla's own
            -- onUnloadBulletsFromMagazine handler's transferIfNeeded call.
            ISInventoryPaneContextMenu.transferIfNeeded(playerObj, mag)

            ISTimedActionQueue.add(
                ISUnloadBulletsFromMagazine:new(playerObj, mag)
            )
        else
            dbg("Magazine empty, skipping: " .. tostring(mag:getFullType()))
        end
    end
end
