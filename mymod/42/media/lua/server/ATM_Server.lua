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

local DEBUG = false
local function dbg(msg) if DEBUG then print("[ATM_Server] " .. tostring(msg)) end end

-----------------------------------------------------
-- PAYOUT TUNING
-- Success chance and payout are built from a base value plus
-- modifiers, so each factor is easy to adjust on its own.
-----------------------------------------------------
local BASE_SUCCESS     = 70   -- % chance a card pays out at all
local MIN_PAYOUT       = 25   -- a success always pays something
local MAX_PAYOUT       = 500
local MAX_FAILS_IN_ROW = 2    -- after this many declines in a row, the next card always pays

-- More Traits (Lucky/Unlucky) -- optional mod, so look it up safely
local LUCKY_SUCCESS    = 15   -- +% success
local LUCKY_PAY_MULT   = 1.25
local UNLUCKY_SUCCESS  = -15
local UNLUCKY_PAY_MULT = 0.8

-- Lucky/Unlucky come from the optional More Traits mod; never error if it isn't loaded
local function hasModTrait(player, key)
    local reg = ToadTraitsRegistries and ToadTraitsRegistries[key]
    if not reg then return false end
    local ok, result = pcall(function() return player:hasTrait(reg) end)
    return ok and result == true
end

-- Declines in a row per player (in memory; resets on server restart)
local failStreak = {}

local function rollPayout(player)
    local who = player:getUsername()
    local chance = BASE_SUCCESS
    local mult = 1.0

    if hasModTrait(player, "lucky") then
        chance = chance + LUCKY_SUCCESS
        mult = mult * LUCKY_PAY_MULT
    elseif hasModTrait(player, "unlucky") then
        chance = chance + UNLUCKY_SUCCESS
        mult = mult * UNLUCKY_PAY_MULT
    end

    local streak = failStreak[who] or 0
    local success = streak >= MAX_FAILS_IN_ROW or ZombRand(100) < chance

    if not success then
        failStreak[who] = streak + 1
        dbg(who .. " declined (chance " .. chance .. "%, streak " .. failStreak[who] .. ")")
        return 0
    end
    failStreak[who] = 0

    -- Average of two rolls leans toward the middle, so fewer tiny payouts
    local roll = (ZombRand(MIN_PAYOUT, MAX_PAYOUT + 1) + ZombRand(MIN_PAYOUT, MAX_PAYOUT + 1)) / 2
    local payout = math.floor(roll * mult)
    dbg(who .. " paid $" .. payout .. " (chance " .. chance .. "%, mult " .. mult .. ")")
    return payout
end

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
    local payout = rollPayout(player)

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