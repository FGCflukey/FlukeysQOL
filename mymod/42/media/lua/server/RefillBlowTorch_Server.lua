-- Overrides vanilla's RefillBlowTorch recipe (same name, see base_fixed.txt).
--
-- Vanilla's own version runs a pure-Java OnCreate (RecipeCodeOnCreate.refillBlowTorch)
-- with no documented transfer ratio anywhere. This replaces only the OnCreate logic;
-- the recipe's destroy/output structure stays exactly vanilla's own (confirmed in-game
-- 2026-10-09: a recipe with nothing destroyed/created is never offered as craftable at
-- all, regardless of flags -- that ruled out the mode:keep/empty-outputs version tried
-- first).
--
-- CONFIRMED (2026-10-09): a craftRecipe's OnCreate first argument is craftRecipeData,
-- NOT the produced item -- same as every other OnCreate already proven working in this
-- pack (GiveBack_CarSeatStuff etc. in VehiclePart_Recycle.lua all ignore it and just
-- use `character`). The earlier (item, player) version called item:getMaxUses() on that
-- craftRecipeData object, which silently failed and skipped the rest of the function --
-- the torch still came out full because the recipe's own output item is full by default
-- regardless of OnCreate, which is why only the propane deduction looked broken.
--
-- Math: a FULL tank fully refills TORCHES_PER_FULL_TANK completely-empty torches, flat
-- cost per refill. Cost is read live off the tank's real getMaxUses(), not a hardcoded
-- number, so this stays correct if UseDelta is ever changed again.

if isClient() then return end

local DEBUG = false
local function dbg(msg)
    if DEBUG then
        print("[RefillBlowTorch] " .. tostring(msg))
    end
end

local TORCHES_PER_FULL_TANK = 10

function RefillBlowTorch_OnCreate(_craftRecipeData, character)
    if not character then return end

    local tank = character:getInventory():getFirstTypeRecurse("Base.PropaneTank")
    if not tank then
        dbg("no propane tank found to charge")
        return
    end

    local tankMax = tank:getMaxUses()
    local tankCur = tank:getCurrentUses()
    if not tankMax or tankMax <= 0 then
        dbg("bad maxUses on tank")
        return
    end
    if tankCur <= 0 then
        -- Shouldn't normally happen (NotEmpty already gates this), kept as a
        -- defensive backstop.
        character:Say(getText("IGUI_RefillBlowTorch_TankEmpty"))
        return
    end

    local cost = tankMax / TORCHES_PER_FULL_TANK
    local newTankUses = math.max(0, tankCur - cost)
    tank:setCurrentUses(newTankUses)
    tank:syncItemFields()
    dbg("refilled torch, tank " .. tostring(tankCur) .. " -> " .. tostring(newTankUses))
end
