-- ATM_Server.lua
-- Server-authoritative handling of ATM cash-out.
--
-- IMPORTANT: this must live under media/lua/server/ so it only
-- loads on the server (and on the local host in singleplayer,
-- which runs its own internal server thread).
--
-- Card removal and money granting happen HERE, authoritatively.
-- The key fix (found by comparing against EZPZ Banking, a mod
-- confirmed working in B42.20 MP): sendAddItemToContainer() and
-- sendRemoveItemFromContainer() are the real engine functions
-- for pushing an item add/remove to a specific client's UI.
-- setDrawDirty() alone does NOT reliably do this, and
-- sendItemListNet() is for the player-trading system and is NOT
-- safe to use here (it corrupted the packet stream in testing).

-- print("[ATM_Server] File loaded successfully")

-----------------------------------------------------
-- RECURSIVE CREDIT CARD SEARCH (server-side copy)
-----------------------------------------------------
local function findCreditCardRecursive(container)
    if not container then return nil end

    local normal = container:getAllType("CreditCard")
    if normal and not normal:isEmpty() then
        return normal:get(0)
    end

    local stolen = container:getAllType("CreditCard_Stolen")
    if stolen and not stolen:isEmpty() then
        return stolen:get(0)
    end

    local items = container:getItems()
    if items then
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item and item:IsInventoryContainer() then
                local found = findCreditCardRecursive(item:getItemContainer())
                if found then return found end
            end
        end
    end

    return nil
end

-----------------------------------------------------
-- COMMAND HANDLER
-----------------------------------------------------
local function OnClientCommand(module, command, player, args)
--    print("[ATM_Server] OnClientCommand fired: module=" .. tostring(module) .. " command=" .. tostring(command))
    if module ~= "ATM" or command ~= "cashOut" then return end
    if not player then return end

    local inv = player:getInventory()
    local card = findCreditCardRecursive(inv)

    if not card then
        sendServerCommand(player, "ATM", "result", { reason = "noCard" })
        return
    end

    -- Remove from whichever container actually holds it, then
    -- explicitly sync the removal to this client.
    local cardContainer = card:getContainer()
    if cardContainer then
        cardContainer:Remove(card)
        sendRemoveItemFromContainer(cardContainer, card)
    else
        inv:Remove(card)
        sendRemoveItemFromContainer(inv, card)
    end

    -----------------------------------------------------
    -- DETERMINE PAYOUT
    -----------------------------------------------------
    local payout = 0
    if ZombRand(100) >= 45 then
        payout = ZombRand(0, 501) -- 0-500
    end

    -----------------------------------------------------
    -- GIVE MONEY -- create via instanceItem, add, then
    -- explicitly sync each new item to this client.
    -----------------------------------------------------
    if payout > 0 then
        local bundles = math.floor(payout / 100)
        local remainder = payout % 100

        for i = 1, bundles do
            local item = instanceItem("Base.MoneyBundle")
            inv:AddItem(item)
            sendAddItemToContainer(inv, item)
        end

        for i = 1, remainder do
            local item = instanceItem("Base.Money")
            inv:AddItem(item)
            sendAddItemToContainer(inv, item)
        end
    end

    -- Tell the owning client the outcome, so it can Say() it locally
    sendServerCommand(player, "ATM", "result", { payout = payout })
end
Events.OnClientCommand.Add(OnClientCommand)