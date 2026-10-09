-- Overrides vanilla's RefillBlowTorch recipe (same name, see base_fixed.txt).
--
-- Vanilla's own version runs a pure-Java OnCreate (RecipeCodeOnCreate.refillBlowTorch)
-- with no documented transfer ratio anywhere. This replaces only the OnCreate logic;
-- the recipe's destroy/output structure stays exactly vanilla's own (confirmed in-game
-- 2026-10-09: a recipe with nothing destroyed/created is never offered as craftable at
-- all, regardless of flags -- that ruled out the mode:keep/empty-outputs version tried
-- first).
--
-- Math: a FULL tank fully refills TORCHES_PER_FULL_TANK completely-empty torches, flat
-- cost per refill (not proportional to the old torch's charge) -- the recipe's own
-- NotFull flag already means "offered" implies "meaningfully not full", and the OLD
-- torch's exact charge is gone by the time OnCreate runs anyway (mode:destroy already
-- consumed it). Cost is read live off both items' real getMaxUses(), not a hardcoded
-- number, so this stays correct if UseDelta is ever changed again.

if isClient() then return end

local DEBUG = false
local function dbg(msg)
    if DEBUG then
        print("[RefillBlowTorch] " .. tostring(msg))
    end
end

local TORCHES_PER_FULL_TANK = 10

local function findFirstOfType(inv, fullType)
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it:getFullType() == fullType then
            return it
        end
    end
    return nil
end

function RefillBlowTorch_OnCreate(item, player)
    if not player or not item then return end

    -- `item` is the freshly-created output torch (vanilla's own recipe shape:
    -- the depleted one is destroyed, a new one takes its place). Make sure it's
    -- actually full -- a freshly crafted drainable's default charge isn't
    -- something we've independently verified, so set it explicitly rather than
    -- assume.
    local torchMax = item:getMaxUses()
    if torchMax and torchMax > 0 then
        item:setCurrentUses(torchMax)
        item:syncItemFields()
    end

    local tank = findFirstOfType(player:getInventory(), "Base.PropaneTank")
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
        player:Say(getText("IGUI_RefillBlowTorch_TankEmpty"))
        return
    end

    local cost = tankMax / TORCHES_PER_FULL_TANK
    local newTankUses = math.max(0, tankCur - cost)
    tank:setCurrentUses(newTankUses)
    tank:syncItemFields()
    dbg("refilled torch, tank " .. tostring(tankCur) .. " -> " .. tostring(newTankUses))
end
