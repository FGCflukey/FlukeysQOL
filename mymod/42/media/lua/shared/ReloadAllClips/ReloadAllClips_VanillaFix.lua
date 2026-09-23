-- media/lua/shared/ReloadAllClips/ReloadAllClips_VanillaFix.lua
--
-- Must live under shared/, not client/: ISLoadBulletsInMagazine's
-- serverStart() (used whenever a reload runs through the real MP server,
-- not just client-side prediction) calls this same setReloadSpeed()
-- function on the SERVER's own Lua VM, which never loads client-only
-- files at all. The first attempt at this fix lived in
-- client/ReloadAllClips/ReloadAllClips_Core.lua and only patched the
-- client's copy -- the server kept running vanilla's original, unpatched
-- version and hit the identical crash from serverStart() instead of
-- start().
--
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
-- guarded (gun.getMagazineType checked before calling it) -- everything
-- else here is unchanged vanilla logic.
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
