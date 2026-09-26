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
-- Excluded traits: same category confirmed unsafe by the
-- "TraitsPurchaseSystem" Workshop mod's own "Unpurchasable Traits" list
-- (Weight/Fitness-derived -- their effects are baked into already-drifted
-- derived stats with no clean value to revert to once real play has moved
-- them), plus the profession "tier 2" traits (BLACKSMITH2/COOK2/
-- MECHANICS2/NUTRITIONIST2), which that mod only supports via a
-- prerequisite-checking system we're deliberately not building here --
-- excluded rather than risking an inconsistent state without it.
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
    [CharacterTrait.BLACKSMITH2]      = true,
    [CharacterTrait.COOK2]            = true,
    [CharacterTrait.MECHANICS2]       = true,
    [CharacterTrait.NUTRITIONIST2]    = true,
}

---------------------------------------------------------
-- isTraitEligible(traitType)
-- traitType is the raw CharacterTrait enum value (what
-- trait:getType() returns), not the CharacterTraitDefinition object.
---------------------------------------------------------
function TraitRespec_Util.isTraitEligible(traitType)
    if not traitType then return false end
    if EXCLUDED_TRAITS[traitType] then
        dbg("Excluded: " .. tostring(traitType:toString()))
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
