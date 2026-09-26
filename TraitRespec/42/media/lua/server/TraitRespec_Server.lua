-- media/lua/server/TraitRespec_Server.lua
--
-- Server-authoritative refund/purchase handling. Client only ever
-- *requests*; this file re-validates everything itself before touching
-- points or the real trait list -- same client-requests/server-validates-
-- and-mutates pattern already used throughout this pack (CarPartRepair,
-- Vendor, ReloadAllClips).

require "TraitRespec_Util"

local DEBUG = false
local function dbg(msg)
    if DEBUG then
        print("[TraitRespec:Server] " .. tostring(msg))
    end
end

---------------------------------------------------------
-- Points are a single number in the player's own ModData -- no passive
-- income anywhere in this mod, the only way this value ever changes is a
-- refund (credit) or a purchase (debit) below.
---------------------------------------------------------
local function getPoints(player)
    local md = player:getModData()
    return md.TR_Points or 0
end

local function setPoints(player, value)
    local md = player:getModData()
    md.TR_Points = value
    player:transmitModData()
end

---------------------------------------------------------
-- Re-applies a trait's one-time creation-time effects. Without this, a
-- purchased trait's flag would be set but its starting-stat bonus (e.g. a
-- profession's starting skill levels) would silently never apply --
-- confirmed this is required by reading TraitsPurchaseSystem's own proven
-- onAddGoodTrait, which does exactly this.
---------------------------------------------------------
local function applyTraitCreationEffects(player, traitDefinition)
    local ok, err = pcall(function()
        local map = traitDefinition:getXpBoosts()
        map = transformIntoKahluaTable(map)
        for perk, value in pairs(map) do
            for i = 1, tonumber(tostring(value)) do
                if player:getPerkLevel(perk) == 10 then break end
                player:LevelPerk(perk)
                luautils.updatePerksXp(perk, player)
            end
        end
    end)
    if not ok then
        dbg("applyTraitCreationEffects: XP boost step failed: " .. tostring(err))
    end

    local ok2, err2 = pcall(function()
        if traitDefinition:hasGrantedRecipes() then
            local recipes = traitDefinition:getGrantedRecipes()
            for i = 0, recipes:size() - 1 do
                player:learnRecipe(recipes:get(i))
            end
        end
    end)
    if not ok2 then
        dbg("applyTraitCreationEffects: granted recipes step failed: " .. tostring(err2))
    end
end

---------------------------------------------------------
-- RefundTrait: player must currently have the trait. Removes it, credits
-- the point magnitude of its real creation-time cost regardless of sign
-- (refunding a positive trait gives back what it cost; refunding a
-- negative trait costs you back what it was giving you -- mirrors
-- TraitsPurchaseSystem's own proven "pay to remove a downside" behavior).
-- No claw-back of any XP boosts/recipes already granted from ever having
-- held the trait -- deliberately, see TraitRespec_Server.lua header /
-- the plan this was built from.
---------------------------------------------------------
local function handleRefundTrait(player, args)
    local traitTypeString = args and args.traitType
    if not traitTypeString then
        dbg("RefundTrait: missing traitType")
        return
    end

    local traitDefinition = TraitRespec_Util.findTraitDefinitionByTypeString(traitTypeString)
    if not traitDefinition then
        dbg("RefundTrait: unknown traitType " .. tostring(traitTypeString))
        return
    end
    local traitType = traitDefinition:getType()

    if not TraitRespec_Util.isTraitEligible(traitType) then
        dbg("RefundTrait: rejected, excluded trait: " .. tostring(traitTypeString))
        sendServerCommand(player, "TraitRespec", "RefundFail", { reason = "excluded" })
        return
    end

    if not player:hasTrait(traitType) then
        dbg("RefundTrait: rejected, player does not have trait: " .. tostring(traitTypeString))
        sendServerCommand(player, "TraitRespec", "RefundFail", { reason = "not_owned" })
        return
    end

    local refund = math.abs(TraitRespec_Util.getTraitCost(traitDefinition))

    player:getCharacterTraits():remove(traitType)
    setPoints(player, getPoints(player) + refund)

    dbg(player:getUsername() .. " refunded " .. tostring(traitTypeString) .. " for " .. refund .. " points")
    sendServerCommand(player, "TraitRespec", "RefundSuccess", {
        traitType = traitTypeString,
        refund = refund,
        points = getPoints(player),
    })
end

---------------------------------------------------------
-- PurchaseTrait: player must NOT currently have the trait, and must have
-- enough points. Adds it, debits the cost, replays creation-time effects.
---------------------------------------------------------
local function handlePurchaseTrait(player, args)
    local traitTypeString = args and args.traitType
    if not traitTypeString then
        dbg("PurchaseTrait: missing traitType")
        return
    end

    local traitDefinition = TraitRespec_Util.findTraitDefinitionByTypeString(traitTypeString)
    if not traitDefinition then
        dbg("PurchaseTrait: unknown traitType " .. tostring(traitTypeString))
        return
    end
    local traitType = traitDefinition:getType()

    if not TraitRespec_Util.isTraitEligible(traitType) then
        dbg("PurchaseTrait: rejected, excluded trait: " .. tostring(traitTypeString))
        sendServerCommand(player, "TraitRespec", "PurchaseFail", { reason = "excluded" })
        return
    end

    if player:hasTrait(traitType) then
        dbg("PurchaseTrait: rejected, player already has trait: " .. tostring(traitTypeString))
        sendServerCommand(player, "TraitRespec", "PurchaseFail", { reason = "already_owned" })
        return
    end

    local cost = TraitRespec_Util.getTraitCost(traitDefinition)
    local points = getPoints(player)
    if points < cost then
        dbg(player:getUsername() .. " has " .. points .. " points, needs " .. cost)
        sendServerCommand(player, "TraitRespec", "PurchaseFail", { reason = "points" })
        return
    end

    player:getCharacterTraits():add(traitType)
    applyTraitCreationEffects(player, traitDefinition)
    setPoints(player, points - cost)
    SyncXp(player)

    dbg(player:getUsername() .. " purchased " .. tostring(traitTypeString) .. " for " .. cost .. " points")
    sendServerCommand(player, "TraitRespec", "PurchaseSuccess", {
        traitType = traitTypeString,
        cost = cost,
        points = getPoints(player),
    })
end

---------------------------------------------------------
-- Client command handler
---------------------------------------------------------
local function OnClientCommand_TraitRespec(module, command, player, args)
    if module ~= "TraitRespec" then return end
    if not player then return end

    if command == "RefundTrait" then
        handleRefundTrait(player, args)
    elseif command == "PurchaseTrait" then
        handlePurchaseTrait(player, args)
    elseif command == "RequestPoints" then
        sendServerCommand(player, "TraitRespec", "PointsUpdate", { points = getPoints(player) })
    end
end
Events.OnClientCommand.Add(OnClientCommand_TraitRespec)
