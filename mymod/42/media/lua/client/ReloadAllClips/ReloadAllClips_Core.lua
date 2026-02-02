-- media/lua/client/ReloadAllClips/ReloadAllClips_Core.lua

require "ReloadAllClips.ReloadAllClips_Util"

ReloadAllClips_Core = {}

local DEBUG = false

local function dbg(msg)
    if DEBUG then
        print("[ReloadAllClips:Core] " .. tostring(msg))
    end
end

---------------------------------------------------------
-- Tiny 1‑tick action to clear hands after all reloads
---------------------------------------------------------
local function queueClearHands(playerObj)
    local action = ISBaseTimedAction:new(playerObj)

    function action:isValid()
        return true
    end

    function action:update()
        -- nothing
    end

    function action:start()
        -- nothing
    end

    function action:stop()
        ISBaseTimedAction.stop(self)
    end

    function action:perform()
        ISBaseTimedAction.perform(self)
        self.character:setPrimaryHandItem(nil)
        self.character:setSecondaryHandItem(nil)
        dbg("Hands cleared after reload/unload chain.")
    end

    action.maxTime = 1
    ISTimedActionQueue.add(action)
end

---------------------------------------------------------
-- Any magazine needs ammo?
---------------------------------------------------------
function ReloadAllClips_Core.anyMagNeedsAmmo(mags)
    for _, mag in ipairs(mags) do
        if mag:getCurrentAmmoCount() < mag:getMaxAmmo() then
            return true
        end
    end
    return false
end

---------------------------------------------------------
-- Any magazine has ammo (for unloading)?
---------------------------------------------------------
function ReloadAllClips_Core.anyMagHasAmmo(mags)
    for _, mag in ipairs(mags) do
        if mag:getCurrentAmmoCount() > 0 then
            return true
        end
    end
    return false
end

---------------------------------------------------------
-- Reload all magazines for a given bullet type
---------------------------------------------------------
function ReloadAllClips_Core.doReloadAll(playerObj, group)
    local mags = group.mags
    local bulletType = group.bulletType

    dbg("ReloadAll for bulletType=" .. tostring(bulletType) ..
        " | magCount=" .. tostring(#mags))

    -- Sort by emptiness (most empty first)
    table.sort(mags, function(a, b)
        return (a:getMaxAmmo() - a:getCurrentAmmoCount()) >
               (b:getMaxAmmo() - b:getCurrentAmmoCount())
    end)

    for _, mag in ipairs(mags) do
        local missing = mag:getMaxAmmo() - mag:getCurrentAmmoCount()

        if missing > 0 then
            dbg("Queueing ISLoadBulletsInMagazine for " ..
                tostring(missing) .. " rounds on " .. tostring(mag))

            ISTimedActionQueue.add(
                ISLoadBulletsInMagazine:new(playerObj, mag, missing)
            )
        else
            dbg("Magazine already full, skipping.")
        end
    end

    -- Clear hands after the entire chain finishes
    queueClearHands(playerObj)
end

---------------------------------------------------------
-- Unload all magazines for a given bullet type
---------------------------------------------------------
function ReloadAllClips_Core.doUnloadAll(playerObj, group)
    local mags = group.mags
    local bulletType = group.bulletType

    dbg("UnloadAll for bulletType=" .. tostring(bulletType) ..
        " | magCount=" .. tostring(#mags))

    for _, mag in ipairs(mags) do
        local cur = mag:getCurrentAmmoCount()

        if cur > 0 then
            dbg("Queueing ISUnloadBulletsFromMagazine for mag with " ..
                tostring(cur) .. " rounds: " .. tostring(mag))

            ISTimedActionQueue.add(
                ISUnloadBulletsFromMagazine:new(playerObj, mag)
            )
        else
            dbg("Magazine empty, skipping.")
        end
    end

    -- Clear hands after the entire chain finishes
    queueClearHands(playerObj)
end