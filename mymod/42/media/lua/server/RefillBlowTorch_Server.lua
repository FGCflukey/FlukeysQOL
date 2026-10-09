-- Overrides vanilla's RefillBlowTorch recipe (same name, see base_fixed.txt).
--
-- Vanilla's own version runs a pure-Java OnCreate (RecipeCodeOnCreate.refillBlowTorch)
-- with no documented transfer ratio anywhere, and its inputs gate on flags[NotFull;
-- ItemCount]/[NotEmpty;ItemCount] -- a flag combo with a confirmed 42.20 engine bug
-- where a torch at EXACTLY 0 charge isn't recognized as valid input unless a 2nd
-- empty torch is also present. base_fixed.txt's override drops those flags entirely
-- (inputs just require presence, mode:keep, nothing destroyed/created) so this file
-- decides everything in readable Lua instead of trusting the buggy native check.
--
-- Math: a FULL tank fully refills TORCHES_PER_FULL_TANK completely-empty torches.
-- Cost scales with maxUses read live off both items (via their real UseDelta), not
-- hardcoded numbers, so this stays correct if UseDelta is ever changed again.

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

function RefillBlowTorch_OnCreate(_item, player)
    if not player then return end
    local inv = player:getInventory()

    -- Found by scanning the player's own inventory rather than trusting the
    -- OnCreate item parameter -- this recipe destroys/creates nothing, so
    -- there's no proven, unambiguous "the relevant item" to pass through it.
    local torch = findFirstOfType(inv, "Base.BlowTorch")
    local tank = findFirstOfType(inv, "Base.PropaneTank")
    if not torch or not tank then
        dbg("missing torch or tank in inventory")
        return
    end

    local torchMax = torch:getMaxUses()
    local torchCur = torch:getCurrentUses()
    local tankMax = tank:getMaxUses()
    local tankCur = tank:getCurrentUses()
    if not torchMax or not tankMax or torchMax <= 0 or tankMax <= 0 then
        dbg("bad maxUses on torch/tank")
        return
    end

    local missing = torchMax - torchCur
    if missing <= 0 then
        player:Say(getText("IGUI_RefillBlowTorch_AlreadyFull"))
        return
    end
    if tankCur <= 0 then
        player:Say(getText("IGUI_RefillBlowTorch_TankEmpty"))
        return
    end

    -- Full refill of a completely-empty torch costs tankMax/TORCHES_PER_FULL_TANK;
    -- a partially-full torch costs proportionally less.
    local costForFullRefill = tankMax / TORCHES_PER_FULL_TANK
    local cost = costForFullRefill * (missing / torchMax)

    if tankCur >= cost then
        torch:setCurrentUses(torchMax)
        tank:setCurrentUses(tankCur - cost)
        dbg("full refill: torch -> " .. tostring(torchMax) .. ", tank -> " .. tostring(tankCur - cost))
    else
        -- Not enough propane left for a full refill -- give what the tank has,
        -- proportionally, rather than refusing outright.
        local fraction = tankCur / cost
        local granted = missing * fraction
        torch:setCurrentUses(torchCur + granted)
        tank:setCurrentUses(0)
        dbg("partial refill: granted " .. tostring(granted) .. " uses, tank drained to 0")
    end

    torch:syncItemFields()
    tank:syncItemFields()
end
