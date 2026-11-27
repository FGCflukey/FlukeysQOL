-- Access control for placed safes, client side. Hiding the right-click option
-- isn't enough: a plain left-click opens containers through
-- ISObjectClickHandler.doClick, which runs before the item fetch, so blocking it
-- stops the request itself. Wrapped on OnGameStart because the global doesn't
-- exist yet when this file loads.

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
-- Container-tab guards: opening your OWN inventory near a safe adds it as a tab
-- with no click at all (ISInventoryPage).
--   - checkExplored triggers the real server fetch
--     (requestServerItemsForContainer), so a non-owner never requests contents.
--   - addContainerButton shows a non-owner the same lock icon and dead button
--     vanilla uses for an isLockedToCharacter container.
-- Installed on OnGameStart so any mod that replaces ISInventoryPage has loaded
-- first and we wrap its version instead of being overwritten by it.
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

-- ---------------------------------------------------------------------------
-- Transfer guard: the real security boundary. Every item move (drag-and-drop,
-- quick-move, "take" option) goes through ISInventoryTransferAction, whatever
-- UI started it, so even if a safe's contents get shown through some path the
-- guards above miss, nothing can be taken out or put in. ISEquipHeavyItem
-- (grabbing heavy items straight into hands) skips that action, so it's
-- guarded separately.
-- ---------------------------------------------------------------------------
local function isForeignSafeContainer(cont, character)
    if not cont or not cont.getType then return false end
    local ok, res = pcall(function()
        if cont:getType() ~= "personalbanksafe" then return false end
        local obj = cont.getParent and cont:getParent() or nil
        if not obj or not Util.isSafe(obj) then return false end
        return not Util.isOwner(obj, character)
    end)
    return ok and res == true
end

local function installTransferGuard()
    if MPBS.transferGuardInstalled then return end

    if ISInventoryTransferAction and not ISInventoryTransferAction._mpbsTransferGuard then
        ISInventoryTransferAction._mpbsTransferGuard = true
        local origIsValid = ISInventoryTransferAction.isValid
        function ISInventoryTransferAction:isValid()
            if isForeignSafeContainer(self.srcContainer, self.character)
                or isForeignSafeContainer(self.destContainer, self.character) then
                return false
            end
            return origIsValid(self)
        end
    end

    if ISEquipHeavyItem and not ISEquipHeavyItem._mpbsHeavyGuard then
        ISEquipHeavyItem._mpbsHeavyGuard = true
        local origHeavy = ISEquipHeavyItem.isValid
        if origHeavy then
            function ISEquipHeavyItem:isValid()
                local item = self.item
                local cont = item and item.getContainer and item:getContainer() or nil
                if isForeignSafeContainer(cont, self.character) then
                    return false
                end
                return origHeavy(self)
            end
        end
    end

    MPBS.transferGuardInstalled = true
end

Events.OnGameStart.Add(installTransferGuard)
