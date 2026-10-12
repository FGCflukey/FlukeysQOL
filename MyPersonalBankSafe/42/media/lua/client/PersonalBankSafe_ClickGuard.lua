-- CRITICAL FIX (2026-10-11): a non-owner could open and loot another player's safe
-- by simply LEFT-CLICKING it -- a real, live exploit reported in-game.
--
-- Root cause: PersonalBankSafe_Context.lua only ever hooked the RIGHT-click context
-- menu (Events.OnFillWorldObjectContextMenu) to hide the "open container" option for
-- non-owners. But a normal single left-click on a container-bearing object never goes
-- through that code at all -- it calls ISObjectClickHandler.doClick directly
-- (confirmed from vanilla's own ISObjectClickHandler.lua:225-330, dispatched from
-- onObjectLeftMouseButtonUp at line 371-388). That function opens the loot panel
-- outright unless `instanceof(object, "IsoThumpable") and object:isLockedToCharacter
-- (playerObj)` is true (line 283) -- a vanilla lock flag we never engaged, since no
-- confirmed Lua setter for it exists anywhere in vanilla or any installed Workshop
-- mod (checked). Hiding the context menu text never touched this path at all.
--
-- Fix: wrap the real function at the one place every click-to-open interaction
-- actually funnels through, so it's closed regardless of how the container is
-- clicked. This is the same client-side trust model vanilla's own isLockedToCharacter
-- check already uses (that check also only runs client-side, same function) -- not a
-- weaker protection than vanilla's own real lock mechanism, just a custom one applied
-- the same way vanilla applies its own.

local Util = MPBS.Util

local realDoClick = ISObjectClickHandler.doClick

ISObjectClickHandler.doClick = function(object, x, y)
    if Util.isSafe(object) then
        local player = getSpecificPlayer(0)
        if player and not Util.isOwner(object, player) then
            player:Say(getText("IGUI_MPBS_ClickNotOwner"))
            return
        end
    end
    return realDoClick(object, x, y)
end
