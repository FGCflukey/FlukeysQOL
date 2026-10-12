-- CRITICAL FIX (2026-10-11): a non-owner could open and loot another player's safe.
-- Two earlier attempts, both real bugs in their own right:
--
-- 1st attempt: patched ISObjectClickHandler.doClick directly at file-load time.
-- Broke client connect entirely ("attempted index: doClick of non-table: null").
-- Root cause turned out to be TIMING, not availability: our client/ file's top-level
-- code ran before vanilla's media/lua/server/ISObjectClickHandler.lua had executed
-- and defined the global, so capturing a reference to it at that point failed. (It
-- clearly DOES exist on a real connected client eventually -- container-opening
-- obviously works for real players -- our mistake was capturing too early.)
--
-- 2nd attempt: patched ISInventoryPage:setNewContainer instead, a function defined
-- later in the chain (inside doClick, after the real data fetch already happened).
-- That one loaded fine, but the Workshop mod CleanUI ships a COMPLETE, from-scratch
-- replacement of the entire client/ISUI/ISInventoryPage.lua file (not a wrapper --
-- confirmed by reading it, no call-through to any previous definition at all), so
-- whichever of us loads last completely erases the other's version. Confirmed live:
-- the "not owner" message fired correctly, but the loot panel still showed real
-- contents anyway -- CleanUI's own unaware setNewContainer had taken over.
--
-- This fix: go back to ISObjectClickHandler.doClick (confirmed NOT touched by
-- CleanUI or any other installed mod -- checked), but defer capturing/wrapping it
-- until Events.OnGameStart, well after every mod and vanilla file has definitely
-- loaded, instead of at this file's own top-level load time. doClick also runs
-- BEFORE the real item-fetch happens (container:requestServerItemsForContainer()),
-- so blocking here stops the request itself, not just the display of its result.

local Util = MPBS.Util

local function installClickGuard()
    if MPBS.clickGuardInstalled then return end
    if not ISObjectClickHandler or not ISObjectClickHandler.doClick then return end

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

    MPBS.clickGuardInstalled = true
end

Events.OnGameStart.Add(installClickGuard)

-- ---------------------------------------------------------------------------
-- 4th fix (2026-10-11): doClick only covers the DIRECT click-to-open path.
-- Vanilla's own base inventory UI separately auto-adds ANY nearby container as
-- a tab the moment a player simply opens their OWN inventory near it -- no
-- click required at all (ISInventoryPage.lua:1729-1758, confirmed by reading
-- it). That part lives in the same file CleanUI fully replaces, so it has the
-- same collision risk attempt 2 already hit -- but re-examining that failure:
-- attempt 2 patched setNewContainer at this file's own top-level load time,
-- NOT deferred to OnGameStart like doClick is here. That's almost certainly
-- the real reason it got silently overwritten -- the same premature-timing
-- mistake that broke doClick in attempt 1, not CleanUI "always winning"
-- regardless of Mods= order. Applying the same OnGameStart deferral here too.
--
-- Two functions, both confirmed real and both called for every container-tab
-- path (nearby floor objects, vehicle parts, worn containers alike):
--   - checkExplored: the function that actually triggers
--     container:requestServerItemsForContainer() (the real server fetch).
--     Blocking it here means a non-owner's client never even REQUESTS the
--     real contents, not just that they're not shown.
--   - addContainerButton: neutered to match vanilla's own native treatment of
--     an isLockedToCharacter object exactly (ISInventoryPage.lua:1744-1750 --
--     same textureOverride, same nulled click handlers), so a non-owner sees
--     a plain lock icon, consistent with how vanilla itself shows a locked
--     container.
-- ---------------------------------------------------------------------------
local function installContainerGuards()
    if MPBS.containerGuardInstalled then return end
    if not ISInventoryPage or not ISInventoryPage.checkExplored or not ISInventoryPage.addContainerButton then
        return
    end

    local realCheckExplored = ISInventoryPage.checkExplored
    function ISInventoryPage:checkExplored(container, playerObj)
        local obj = container and container.getParent and container:getParent() or nil
        if obj and Util.isSafe(obj) and playerObj and not Util.isOwner(obj, playerObj) then
            return -- never fetch real contents for a non-owner
        end
        return realCheckExplored(self, container, playerObj)
    end

    local realAddContainerButton = ISInventoryPage.addContainerButton
    function ISInventoryPage:addContainerButton(container, texture, name, tooltip)
        local button = realAddContainerButton(self, container, texture, name, tooltip)
        local obj = container and container.getParent and container:getParent() or nil
        if obj and Util.isSafe(obj) then
            local playerObj = getSpecificPlayer(self.player)
            if playerObj and not Util.isOwner(obj, playerObj) then
                button.onclick = nil
                button.onmousedown = nil
                button:setOnMouseOverFunction(nil)
                button:setOnMouseOutFunction(nil)
                button.textureOverride = getTexture("media/ui/lock.png")
            end
        end
        return button
    end

    MPBS.containerGuardInstalled = true
end

Events.OnGameStart.Add(installContainerGuards)
