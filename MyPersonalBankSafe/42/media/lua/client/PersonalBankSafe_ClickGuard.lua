-- CRITICAL FIX (2026-10-11): a non-owner could open and loot another player's safe
-- by simply left-clicking it -- a real, live exploit reported in-game.
--
-- First attempt patched ISObjectClickHandler.doClick (media/lua/server/ISObjectClickHandler.lua),
-- which turned out to be a real bug of its own: that global is NOT reliably defined
-- when a real connected client loads this file (confirmed live -- "attempted index:
-- doClick of non-table: null" on connecting to the server). No installed mod on this
-- server actually patches that function at runtime either (checked) -- only comments
-- reference it, never live code, which should have been the tell.
--
-- Real fix: patch ISInventoryPage:setNewContainer instead (confirmed defined in
-- client/ISUI/ISInventoryPage.lua:1122, genuinely client-loaded, no load-order risk).
-- This is the actual function vanilla's own doClick calls to display a container's
-- contents in the loot panel (panel2:setNewContainer(container)) -- the real choke
-- point every "show me this container's contents" path funnels through, regardless
-- of how the open was triggered.

local Util = MPBS.Util

local realSetNewContainer = ISInventoryPage.setNewContainer

function ISInventoryPage:setNewContainer(inventory)
    local obj = inventory and inventory.getParent and inventory:getParent() or nil
    if obj and Util.isSafe(obj) then
        local player = getSpecificPlayer(self.player)
        if player and not Util.isOwner(obj, player) then
            if player then
                player:Say(getText("IGUI_MPBS_ClickNotOwner"))
            end
            return
        end
    end
    return realSetNewContainer(self, inventory)
end
