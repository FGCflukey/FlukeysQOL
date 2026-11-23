-- ===================================================================
--  Transfer Amount: "Grab amount..." / "Put amount..." / "Drop amount..."
-- ===================================================================
--  Our own build of a choose-how-many transfer, informed by reading the
--  Workshop "TakeAnyAmount" mod (3820203426). Differences from that mod:
--   * Adds options AFTER vanilla builds the menu (OnFillInventoryObject-
--     ContextMenu) instead of replacing vanilla's whole doGrabMenu, so
--     vanilla updates to the grab menu are kept.
--   * No shared MAX/AMOUNT globals: each option carries its own item
--     list, so the max can't be overwritten by another menu.
--   * Numbers-only box, OK greyed out unless 1..max, Enter = OK.
--   * Skips favourited and equipped/worn/attached items (so "put 5"
--     never takes the knife out of your hand), and re-checks every item
--     is still where it was when you click OK.
--  The actual moves are vanilla ISInventoryTransferAction / dropItem,
--  which are already server-validated in MP; nothing here changes items
--  directly.
-- ===================================================================

require "ISUI/ISInventoryPaneContextMenu"
require "ISUI/ISTextBox"
require "TimedActions/ISInventoryTransferUtil"

local DEBUG = false
local function dbg(msg)
    if DEBUG then print("[TransferAmount] " .. tostring(msg)) end
end

local MIN_STACK = 2 -- only offer "amount" when there are at least this many

-------------------------------------------------
-- Helpers
-------------------------------------------------

local function isEquippedSomehow(playerObj, item)
    if playerObj:isEquipped(item) then return true end
    if item.getAttachedSlot and item:getAttachedSlot() > -1 then return true end
    return false
end

-- Every real InventoryItem in the selection (stack entries' items[1] is a
-- display duplicate, real ones start at 2).
local function collectRealItems(items)
    local out = {}
    for _, k in ipairs(items) do
        if instanceof(k, "InventoryItem") then
            table.insert(out, k)
        elseif k.items then
            for i = 2, #k.items do
                table.insert(out, k.items[i])
            end
        end
    end
    return out
end

local function walkTo(container, player)
    return luautils.walkToContainer(container, player)
end

-------------------------------------------------
-- Moving
-------------------------------------------------

local function doGrab(playerNum, list, count)
    local playerObj = getSpecificPlayer(playerNum)
    local playerInv = getPlayerInventory(playerNum).inventory
    local walked, moved = false, 0
    for _, e in ipairs(list) do
        if moved >= count then break end
        local item = e.item
        -- still in the container it was in when the menu opened?
        if item:getContainer() == e.from and e.from ~= playerInv then
            if not walked then
                if not walkTo(e.from, playerNum) then return end
                walked = true
            end
            ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(playerObj, item, e.from, playerInv))
            moved = moved + 1
        end
    end
    dbg("grab queued " .. moved .. "/" .. count)
end

local function doPut(playerNum, list, count, dest)
    local playerObj = getSpecificPlayer(playerNum)
    local walked, moved = false, 0
    for _, e in ipairs(list) do
        if moved >= count then break end
        local item = e.item
        if item:getContainer() == e.from and not item:isFavorite()
                and not isEquippedSomehow(playerObj, item) and dest:isItemAllowed(item) then
            if not walked then
                if not walkTo(dest, playerNum) then return end
                walked = true
            end
            ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(playerObj, item, e.from, dest))
            moved = moved + 1
        end
    end
    dbg("put queued " .. moved .. "/" .. count)
end

local function doDrop(playerNum, list, count)
    local playerObj = getSpecificPlayer(playerNum)
    local moved = 0
    for _, e in ipairs(list) do
        if moved >= count then break end
        local item = e.item
        if item:getContainer() == e.from and not item:isFavorite()
                and not isEquippedSomehow(playerObj, item) then
            ISInventoryPaneContextMenu.dropItem(item, playerNum)
            moved = moved + 1
        end
    end
    dbg("drop queued " .. moved .. "/" .. count)
end

-------------------------------------------------
-- Amount box
-------------------------------------------------

local function parseAmount(text, max)
    local n = tonumber(text)
    if not n then return nil end
    n = math.floor(n)
    if n < 1 or n > max then return nil end
    return n
end

local function validate(max, text)
    return parseAmount(text, max) ~= nil
end

local function onAmountClick(data, button)
    if button.internal ~= "OK" then return end
    local n = parseAmount(button.parent.entry:getText(), data.max)
    if not n then return end
    data.run(n)
end

local function openAmountBox(title, playerNum, max, run)
    local data = { max = max, run = run }
    local modal = ISTextBox:new(0, 0, 280, 180, title .. " (1 - " .. max .. ")", tostring(max),
        data, onAmountClick, playerNum)
    modal:initialise()
    modal:addToUIManager()
    modal:setOnlyNumbers(true)
    modal:setValidateFunction(max, validate)
    modal:setValidateTooltipText("Enter a number from 1 to " .. max)
    modal.entry.onCommandEntered = function()
        if modal.yes and modal.yes:isEnabled() then modal:onClick(modal.yes) end
    end
    modal.entry:focus()
    modal.entry:selectAll()
    if JoypadState.players[playerNum + 1] then
        setJoypadFocus(playerNum, modal)
    end
end

-------------------------------------------------
-- Context menu
-------------------------------------------------

local function addGrabAmount(playerNum, context, real, playerObj, playerInv)
    local list = {}
    for _, item in ipairs(real) do
        local from = item:getContainer()
        if from and from ~= playerInv and not isForceDropHeavyItem(item)
                and playerInv:isItemAllowed(item) and not item:isHumanCorpse() then
            table.insert(list, { item = item, from = from })
        end
    end
    if #list < MIN_STACK then return end
    local max = #list
    local label = "Grab amount..."
    local run = function(n) doGrab(playerNum, list, n) end
    local open = function() openAmountBox("Grab amount", playerNum, max, run) end
    if context:getOptionFromName(getText("ContextMenu_Grab_half")) then
        context:insertOptionAfter(getText("ContextMenu_Grab_half"), label, nil, open)
    elseif context:getOptionFromName(getText("ContextMenu_Grab_all")) then
        context:insertOptionBefore(getText("ContextMenu_Grab_all"), label, nil, open)
    else
        context:insertOptionAfter(getText("ContextMenu_Grab"), label, nil, open)
    end
end

local function addPutAndDropAmount(playerNum, context, real, playerObj)
    local list = {}
    for _, item in ipairs(real) do
        local from = item:getContainer()
        if from and from:isInCharacterInventory(playerObj) and not item:isFavorite()
                and not isEquippedSomehow(playerObj, item) then
            table.insert(list, { item = item, from = from })
        end
    end
    if #list < MIN_STACK then return end

    -- Put amount (into the open loot container; vanilla doesn't offer Put for the floor)
    local loot = getPlayerLoot(playerNum)
    local dest = loot and loot.inventory
    if dest and dest:getType() ~= "floor" and not dest:isInCharacterInventory(playerObj) then
        local allowed = {}
        for _, e in ipairs(list) do
            if dest:isItemAllowed(e.item) then table.insert(allowed, e) end
        end
        if #allowed >= MIN_STACK then
            local max = #allowed
            local title = loot.title or "Container"
            local run = function(n) doPut(playerNum, allowed, n, dest) end
            context:addOption("Put amount... (" .. title .. ")", nil, function()
                openAmountBox("Put in " .. title, playerNum, max, run)
            end)
        end
    end

    -- Drop amount (not from inside a vehicle; vanilla's drop has its own vehicle rules)
    if not playerObj:getVehicle() then
        local max = #list
        local run = function(n) doDrop(playerNum, list, n) end
        local open = function() openAmountBox("Drop amount", playerNum, max, run) end
        if context:getOptionFromName(getText("ContextMenu_Drop")) then
            context:insertOptionAfter(getText("ContextMenu_Drop"), "Drop amount...", nil, open)
        else
            context:addOption("Drop amount...", nil, open)
        end
    end
end

local function onFillInventoryObjectContextMenu(playerNum, context, items)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or playerObj:getJoypadBind() ~= -1 then return end -- typing box is mouse/keyboard only
    if getCore():isTutorial() then return end

    local real = collectRealItems(items)
    if #real < MIN_STACK then return end

    local playerInv = getPlayerInventory(playerNum).inventory
    local first = real[1]
    local firstCont = first and first:getContainer()
    if not firstCont then return end

    if firstCont:isInCharacterInventory(playerObj) then
        addPutAndDropAmount(playerNum, context, real, playerObj)
    else
        addGrabAmount(playerNum, context, real, playerObj, playerInv)
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)
