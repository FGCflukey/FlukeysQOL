-- media/lua/shared/TraitRespec_Util.lua
--
-- Shared helpers: which traits are safe to refund/purchase, and the real
-- point-value lookup. Both client and server require this so neither side
-- can ever disagree about what's allowed -- the client only uses it to
-- decide what to show/offer; the server re-checks everything itself
-- before mutating anything (see TraitRespec_Server.lua).

TraitRespec_Util = {}

local DEBUG = false
local function dbg(msg)
    if DEBUG then
        print("[TraitRespec:Util] " .. tostring(msg))
    end
end

---------------------------------------------------------
-- Excluded traits: Weight/Fitness-derived (FIT/ATHLETIC/STOUT/STRONG/
-- EMACIATED/VERY_UNDERWEIGHT/UNDERWEIGHT/OVERWEIGHT/OBESE) -- same
-- category confirmed unsafe by the "TraitsPurchaseSystem" Workshop mod's
-- own "Unpurchasable Traits" list, since their effects are baked into
-- already-drifted derived stats with no clean value to revert to once
-- real play has moved them.
--
-- Every profession-granted trait (Ax-pert, Burglar, Desensitized,
-- Herbalist, Inventive Cook2/Mechanics2/etc.) is excluded separately
-- below, dynamically, by cost == 0 rather than hardcoded by name --
-- confirmed against vanilla's own character_traits.txt that every trait
-- flagged IsProfessionTrait=true (except the Weight ones above, which
-- carry a real nonzero cost too) prices at exactly 0, since these
-- normally come bundled free with a profession pick rather than being a
-- discretionary point-buy. Filtering by cost also means this never needs
-- updating for a modded 0-cost trait we don't know the name of.
---------------------------------------------------------
local EXCLUDED_TRAITS = {
    [CharacterTrait.EMACIATED]        = true,
    [CharacterTrait.VERY_UNDERWEIGHT] = true,
    [CharacterTrait.UNDERWEIGHT]      = true,
    [CharacterTrait.OVERWEIGHT]       = true,
    [CharacterTrait.OBESE]            = true,
    [CharacterTrait.FIT]              = true,
    [CharacterTrait.ATHLETIC]         = true,
    [CharacterTrait.STOUT]            = true,
    [CharacterTrait.STRONG]           = true,
}

---------------------------------------------------------
-- isTraitEligible(traitDefinition)
---------------------------------------------------------
function TraitRespec_Util.isTraitEligible(traitDefinition)
    if not traitDefinition then return false end
    local traitType = traitDefinition:getType()
    if EXCLUDED_TRAITS[traitType] then
        dbg("Excluded (weight/fitness): " .. tostring(traitType:toString()))
        return false
    end
    if TraitRespec_Util.getTraitCost(traitDefinition) == 0 then
        dbg("Excluded (profession, cost 0): " .. tostring(traitType:toString()))
        return false
    end
    return true
end

---------------------------------------------------------
-- getTraitCost(traitDefinition)
-- Real vanilla point value, straight from the trait's own definition --
-- no hand-maintained cost table, so this automatically covers every
-- trait from every mod, not just ones we know about.
---------------------------------------------------------
function TraitRespec_Util.getTraitCost(traitDefinition)
    if not traitDefinition then return 0 end
    return traitDefinition:getCost() or 0
end

---------------------------------------------------------
-- findTraitDefinitionByTypeString(traitTypeString)
-- Looks up a CharacterTraitDefinition by the string form of its type
-- (trait:getType():toString()) -- the exact same iterate-and-compare
-- pattern TraitsPurchaseSystem's own Server.lua uses, deliberately not
-- assuming CharacterTrait[string] indexing works, since that was never
-- confirmed against real data.
---------------------------------------------------------
function TraitRespec_Util.findTraitDefinitionByTypeString(traitTypeString)
    if not traitTypeString then return nil end
    local traitList = CharacterTraitDefinition.getTraits()
    for i = 0, traitList:size() - 1 do
        local traitDefinition = traitList:get(i)
        if traitDefinition:getType():toString() == traitTypeString then
            return traitDefinition
        end
    end
    return nil
end
