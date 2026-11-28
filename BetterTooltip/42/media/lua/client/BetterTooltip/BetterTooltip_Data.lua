-- Better Tooltip: turns an item into a plain "card model" the renderer draws.
--
-- A model is:
--   { title, icon, chips = {str...}, weight = str,
--     bar = { label, text, frac, color, textColor },
--     sections = { { title, rows = {row...} | tiles = {tile...} | list = {entry...} } },
--     more = {row...}   -- shown only while Shift is held
--     desc = str }
--   row   = { label, value, color?, delta?, deltaColor? }
--   tile  = { value, label }
--   entry = { name, count }
--
-- build() returns nil for item types we don't handle yet, and the caller
-- then draws the vanilla tooltip instead -- never a blank or broken card.

require "BetterTooltip/BetterTooltip_Core"

local BT = BetterTooltip
local call, num, T, fmt, signed, pct = BT.call, BT.num, BT.T, BT.fmt, BT.signed, BT.pct
local C = BT.C

BT.Data = {}

---------------------------------------------------------
-- Small builders
---------------------------------------------------------
local function row(label, value, color)
    return { label = label, value = value, color = color }
end

local function addRow(rows, label, value, color)
    if value ~= nil and value ~= "" then table.insert(rows, row(label, value, color)) end
end

-- Numeric row that is skipped when zero/missing.
local function addNonZero(rows, label, v, text, color)
    v = num(v)
    if v and math.abs(v) > 0.0001 then table.insert(rows, row(label, text or fmt(v, 1), color)) end
end

-- Effect where a positive change is bad (hunger, unhappiness...): green if negative.
local function effectColor(v, positiveIsGood)
    if not v or v == 0 then return nil end
    if (v > 0) == (positiveIsGood == true) then return C.good end
    return C.bad
end

local function section(title, rows)
    if rows and #rows > 0 then return { title = title, rows = rows } end
    return nil
end

local function addSection(model, s)
    if s then table.insert(model.sections, s) end
end

local function conditionBar(item)
    local cond, condMax = num(call(item, "getCondition")), num(call(item, "getConditionMax"))
    if not cond or not condMax or condMax <= 0 then return nil end
    local frac = math.max(0, math.min(1, cond / condMax))
    return { label = T("UI_BTT_Condition", "Condition"), text = fmt(cond, 0) .. " / " .. fmt(condMax, 0),
             frac = frac, color = BT.barColor(frac) }
end

-- Display name for an item type. Accepts a fullType ("Base.9mmClip"), a B42
-- registry key ("base:bullets9mm"), or an object with getItemKey() (what
-- HandWeapon:getAmmoType() returns). Uses ScriptManager:FindItem like
-- vanilla's reload menu does (ISInventoryPaneContextMenu.doBulletMenu) --
-- never getItemNameFromFullType, which THROWS on registry keys; even inside
-- pcall PZ logs a full stack trace for that every frame the tooltip draws.
local function itemName(key)
    if key ~= nil and type(key) ~= "string" then
        key = call(key, "getItemKey")
    end
    if type(key) ~= "string" or key == "" then return nil end
    local sm = getScriptManager()
    local script = sm and call(sm, "FindItem", key)
    local name = script and call(script, "getDisplayName")
    if type(name) == "string" and name ~= "" then return name end
    return BT.pretty((key:gsub("^.*[%.:]", "")))
end

local function description(item)
    local tip = call(item, "getTooltip")
    if type(tip) ~= "string" or tip == "" then return nil end
    local s = getText(tip)
    if s == nil or s == "" or s == tip and tip:find("^Tooltip_") then return nil end
    -- vanilla tooltips can carry rich-text tags; strip them for plain drawing
    s = s:gsub("<[^>]*>", " "):gsub("%s+", " ")
    return s
end

local function categoryChip(item)
    local cat = call(item, "getDisplayCategory")
    if type(cat) ~= "string" or cat == "" then return nil end
    local s = getText("IGUI_ItemCat_" .. cat)
    if s == nil or s == "IGUI_ItemCat_" .. cat then s = BT.pretty(cat) end
    return s
end

local function baseModel(item)
    local w = num(call(item, "getActualWeight")) or num(call(item, "getWeight"))
    return {
        title = call(item, "getDisplayName") or call(item, "getName") or "?",
        icon = call(item, "getTex") or call(item, "getTexture"),
        chips = {},
        weight = w and fmt(w, 2) or nil,
        sections = {},
        more = {},
        desc = description(item),
    }
end

---------------------------------------------------------
-- Weapons
---------------------------------------------------------
local SKILLS = {
    { "AXE", "Axe" }, { "BLUNT", "Blunt" }, { "SPEAR", "Spear" },
    { "LONG_BLADE", "LongBlade" }, { "SMALL_BLADE", "SmallBlade" }, { "SMALL_BLUNT", "SmallBlunt" },
}

-- Same check vanilla's XP code uses (server/XpSystem/XpUpdate.lua).
local function weaponPerk(item)
    if call(item, "isRanged") then return Perks.Aiming end
    local script = call(item, "getScriptItem")
    if not script or not WeaponCategory then return nil end
    for _, s in ipairs(SKILLS) do
        local cat = WeaponCategory[s[1]]
        if cat and call(script, "containsWeaponCategory", cat) then return Perks[s[2]] end
    end
    return nil
end

local function perkName(perk)
    local ok, name = pcall(PerkFactory.getPerkName, perk)
    if ok and name then return name end
    return tostring(perk)
end

-- Delta vs. the equipped weapon (same kind: melee vs melee, gun vs gun).
local function compareWith(item, player)
    if not BT.compareOn() or not player then return nil end
    local eq = call(player, "getPrimaryHandItem")
    if not eq or eq == item or not instanceof(eq, "HandWeapon") then return nil end
    if (call(eq, "isRanged") == true) ~= (call(item, "isRanged") == true) then return nil end
    return eq
end

local function withDelta(r, mine, theirs, dec, higherIsBetter)
    mine, theirs = num(mine), num(theirs)
    if not mine or not theirs then return r end
    local d = mine - theirs
    if math.abs(d) < 0.005 then return r end
    r.delta = signed(d, dec)
    if (d > 0) == (higherIsBetter ~= false) then r.deltaColor = C.good else r.deltaColor = C.bad end
    return r
end

local function buildWeapon(item, player, model)
    local ranged = call(item, "isRanged") == true
    table.insert(model.chips, ranged and T("UI_BTT_Chip_Firearm", "Firearm") or T("UI_BTT_Chip_Weapon", "Weapon"))
    if call(item, "isTwoHandWeapon") or call(item, "isRequiresEquippedBothHands") then
        table.insert(model.chips, T("UI_BTT_Chip_TwoHanded", "Two-handed"))
    end
    model.bar = conditionBar(item)

    local eq = compareWith(item, player)
    local minD, maxD = num(call(item, "getMinDamage")), num(call(item, "getMaxDamage"))
    local rows = {}

    if minD and maxD then
        local r = row(T("UI_BTT_Damage", "Damage"), fmt(minD, 1) .. " - " .. fmt(maxD, 1))
        if eq then withDelta(r, maxD, call(eq, "getMaxDamage"), 1) end
        table.insert(rows, r)
    end

    if ranged then
        local range = num(call(item, "getMaxRange"))
        if range then
            local r = row(T("UI_BTT_Range", "Range"), fmt(range, 1))
            if eq then withDelta(r, range, call(eq, "getMaxRange"), 1) end
            table.insert(rows, r)
        end
        local hit = num(call(item, "getHitChance"))
        if hit then
            local r = row(T("UI_BTT_HitChance", "Hit chance"), fmt(hit, 0) .. "%")
            if eq then withDelta(r, hit, call(eq, "getHitChance"), 0) end
            table.insert(rows, r)
        end
        local cur, max = num(call(item, "getCurrentAmmoCount")), num(call(item, "getMaxAmmo"))
        if cur and max and max > 0 then
            local loaded = fmt(cur, 0) .. " / " .. fmt(max, 0)
            if call(item, "isRoundChambered") then loaded = loaded .. " +1" end
            addRow(rows, T("UI_BTT_Ammo", "Loaded"), loaded)
        end
        local ammo = call(item, "getAmmoType")
        if ammo ~= nil then addRow(rows, T("UI_BTT_AmmoType", "Ammo"), itemName(ammo)) end
        local mag = call(item, "getMagazineType")
        if mag ~= nil and mag ~= "" then addRow(rows, T("UI_BTT_Magazine", "Magazine"), itemName(mag)) end
        if call(item, "isJammed") then addRow(rows, T("UI_BTT_Jammed", "Jammed"), T("UI_BTT_Yes", "Yes"), C.bad) end
    else
        local crit = num(call(item, "getCriticalChance"))
        if crit then
            local r = row(T("UI_BTT_Crit", "Critical chance"), fmt(crit, 0) .. "%")
            if eq then withDelta(r, crit, call(eq, "getCriticalChance"), 0) end
            table.insert(rows, r)
        end
        local reach = num(call(item, "getMaxRange"))
        if reach then
            local r = row(T("UI_BTT_Reach", "Reach"), fmt(reach, 2))
            if eq then withDelta(r, reach, call(eq, "getMaxRange"), 2) end
            table.insert(rows, r)
        end
        local hits = num(call(item, "getMaxHitCount"))
        if hits and hits > 0 then
            local r = row(T("UI_BTT_MaxTargets", "Max targets"), fmt(hits, 0))
            if eq then withDelta(r, hits, call(eq, "getMaxHitCount"), 0) end
            table.insert(rows, r)
        end
    end
    addSection(model, section(ranged and T("UI_BTT_Sec_Firearm", "FIREARM") or T("UI_BTT_Sec_Combat", "COMBAT"), rows))

    -- YOU: the player's skill for this weapon type
    local perk = weaponPerk(item)
    if perk and player then
        local lvl = num(call(player, "getPerkLevel", perk))
        if lvl then
            addSection(model, section(T("UI_BTT_Sec_You", "YOU"), {
                row(T("UI_BTT_Skill", "%1 skill", perkName(perk)), T("UI_BTT_Level", "Level %1", fmt(lvl, 0))),
            }))
        end
    end

    -- Shift: the less-used numbers
    local more = model.more
    if ranged then
        addNonZero(more, T("UI_BTT_Crit", "Critical chance"), call(item, "getCriticalChance"), fmt(num(call(item, "getCriticalChance")), 0) .. "%")
        addNonZero(more, T("UI_BTT_AimTime", "Aiming time"), call(item, "getAimingTime"))
        addNonZero(more, T("UI_BTT_ReloadTime", "Reload time"), call(item, "getReloadTime"))
        addNonZero(more, T("UI_BTT_Recoil", "Recoil delay"), call(item, "getRecoilDelay"))
        addNonZero(more, T("UI_BTT_Noise", "Noise radius"), call(item, "getSoundRadius"))
        local fm = call(item, "getFireMode")
        if type(fm) == "string" and fm ~= "" then addRow(more, T("UI_BTT_FireMode", "Fire mode"), fm) end
    else
        addNonZero(more, T("UI_BTT_MinReach", "Minimum reach"), call(item, "getMinRange"), fmt(num(call(item, "getMinRange")), 2))
        if call(item, "hasSharpness") then
            local sh = pct(call(item, "getSharpness"))
            if sh then addRow(more, T("UI_BTT_Sharpness", "Sharpness"), fmt(sh, 0) .. "%") end
        end
    end
    local lower = num(call(item, "getConditionLowerChance"))
    if lower and lower > 0 then addRow(more, T("UI_BTT_LowerChance", "Wear chance per hit"), T("UI_BTT_OneIn", "1 in %1", fmt(lower, 0))) end
    addNonZero(more, T("UI_BTT_Endurance", "Stamina use"), call(item, "getEnduranceMod"), "x" .. fmt(num(call(item, "getEnduranceMod")), 2))
    addNonZero(more, T("UI_BTT_Repaired", "Times repaired"), call(item, "getHaveBeenRepaired"), fmt(num(call(item, "getHaveBeenRepaired")), 0))
    return model
end

---------------------------------------------------------
-- Food
---------------------------------------------------------
local NEVER_ROTS = 100000 -- vanilla non-perishables use huge OffAge values

local function freshnessBar(item)
    if call(item, "isRotten") then
        return { label = T("UI_BTT_Freshness", "Freshness"), text = T("UI_BTT_Rotten", "Rotten"),
                 frac = 0, color = C.barBad, textColor = C.bad }
    end
    local age, offAge, offMax = num(call(item, "getAge")), num(call(item, "getOffAge")), num(call(item, "getOffAgeMax"))
    if not age or not offAge or offAge >= NEVER_ROTS then return nil end
    if call(item, "isFrozen") then
        return { label = T("UI_BTT_Freshness", "Freshness"), text = T("UI_BTT_FrozenPaused", "Frozen (not spoiling)"),
                 frac = math.max(0, 1 - age / math.max(offAge, 0.01)), color = C.barFluid }
    end
    local function left(days)
        if days < 1 then return T("UI_BTT_HoursLeft", "%1 hours left", fmt(math.max(1, days * 24), 0)) end
        return T("UI_BTT_DaysLeft", "%1 days left", fmt(days, days < 10 and 1 or 0))
    end
    if age < offAge then
        local frac = math.max(0, 1 - age / math.max(offAge, 0.01))
        return { label = T("UI_BTT_Freshness", "Freshness"), text = T("UI_BTT_Fresh", "Fresh") .. " - " .. left(offAge - age),
                 frac = frac, color = C.barGood, textColor = C.good }
    end
    local text = T("UI_BTT_Stale", "Stale")
    local frac = 0.15
    if offMax and offMax > offAge and offMax < NEVER_ROTS then
        text = text .. " - " .. T("UI_BTT_UntilRotten", "rots in %1 days", fmt(math.max(0, offMax - age), 1))
        frac = math.max(0.02, 0.3 * (1 - (age - offAge) / (offMax - offAge)))
    end
    return { label = T("UI_BTT_Freshness", "Freshness"), text = text, frac = frac, color = C.barWarn, textColor = C.warn }
end

-- Food stat changes are stored as fractions for some stats (hunger -0.2 = -20)
local function scaled(v)
    v = num(v)
    if not v then return nil end
    if math.abs(v) <= 1 then v = v * 100 end
    return v
end

local function buildFood(item, player, model)
    table.insert(model.chips, T("UI_BTT_Chip_Food", "Food"))
    if call(item, "isBurnt") then table.insert(model.chips, T("UI_BTT_Chip_Burnt", "Burnt"))
    elseif call(item, "isCooked") then table.insert(model.chips, T("UI_BTT_Chip_Cooked", "Cooked")) end
    if call(item, "isFrozen") then table.insert(model.chips, T("UI_BTT_Chip_Frozen", "Frozen")) end
    model.bar = freshnessBar(item)

    local rows = {}
    local hunger = scaled(num(call(item, "getHungerChange")) or num(call(item, "getHungChange")))
    if hunger and math.abs(hunger) >= 0.5 then
        table.insert(rows, row(T("UI_BTT_Hunger", "Hunger"), signed(hunger, 0), effectColor(hunger, false)))
    end
    local function eff(key, fb, v, positiveIsGood)
        v = num(v)
        if v and math.abs(v) >= 0.5 then table.insert(rows, row(T(key, fb), signed(v, 0), effectColor(v, positiveIsGood))) end
    end
    eff("UI_BTT_Thirst", "Thirst", scaled(call(item, "getThirstChange")), false)
    eff("UI_BTT_Unhappiness", "Unhappiness", call(item, "getUnhappyChange"), false)
    eff("UI_BTT_Boredom", "Boredom", call(item, "getBoredomChange"), false)
    eff("UI_BTT_Stress", "Stress", scaled(call(item, "getStressChange")), false)
    eff("UI_BTT_Energy", "Endurance", scaled(call(item, "getEnduranceChange")), true)
    eff("UI_BTT_Fatigue", "Fatigue", scaled(call(item, "getFatigueChange")), false)
    if call(item, "isbDangerousUncooked") and not call(item, "isCooked") then
        table.insert(rows, row(T("UI_BTT_DangerRaw", "Dangerous to eat raw"), "!", C.bad))
    end
    addSection(model, section(T("UI_BTT_Sec_WhenEaten", "WHEN EATEN"), rows))

    local cal, carb, prot, fat = num(call(item, "getCalories")), num(call(item, "getCarbohydrates")),
                                 num(call(item, "getProteins")), num(call(item, "getLipids"))
    if (cal or 0) > 0 or (carb or 0) > 0 or (prot or 0) > 0 or (fat or 0) > 0 then
        table.insert(model.sections, {
            title = T("UI_BTT_Sec_Nutrition", "NUTRITION"),
            tiles = {
                { value = fmt(cal or 0, 0), label = T("UI_BTT_Calories", "Calories") },
                { value = fmt(carb or 0, 0) .. "g", label = T("UI_BTT_Carbs", "Carbs") },
                { value = fmt(prot or 0, 0) .. "g", label = T("UI_BTT_Protein", "Protein") },
                { value = fmt(fat or 0, 0) .. "g", label = T("UI_BTT_Fat", "Fat") },
            },
        })
    end

    local cook = num(call(item, "getMinutesToCook"))
    if cook and cook > 0 and call(item, "isIsCookable") then
        addRow(model.more, T("UI_BTT_CookTime", "Cooking time"), T("UI_BTT_Minutes", "%1 min", fmt(cook, 0)))
    end
    local age, offAge, offMax = num(call(item, "getAge")), num(call(item, "getOffAge")), num(call(item, "getOffAgeMax"))
    if age and offAge and offAge < NEVER_ROTS then
        addRow(model.more, T("UI_BTT_Fresh", "Fresh"), fmt(offAge, 1) .. "d")
        if offMax and offMax < NEVER_ROTS then addRow(model.more, T("UI_BTT_Rotten", "Rotten"), fmt(offMax, 1) .. "d") end
    end
    return model
end

---------------------------------------------------------
-- Clothing
---------------------------------------------------------
local function speedMod(v)
    v = num(v)
    if not v or math.abs(v - 1) < 0.005 then return nil end
    local d = (v - 1) * 100
    return signed(d, 0) .. "%", (d >= 0) and C.good or C.bad
end

local function buildClothing(item, player, model)
    table.insert(model.chips, T("UI_BTT_Chip_Clothing", "Clothing"))
    local loc = call(item, "getBodyLocation")
    if loc ~= nil then
        local s = BT.pretty(loc)
        if s and s ~= "" then table.insert(model.chips, s) end
    end
    model.bar = conditionBar(item)

    local prot = {}
    local function defense(key, fb, v)
        v = pct(v)
        if v and v > 0.05 then table.insert(prot, row(T(key, fb), fmt(v, 0) .. "%")) end
    end
    defense("UI_BTT_Bite", "Bite", call(item, "getBiteDefense"))
    defense("UI_BTT_Scratch", "Scratch", call(item, "getScratchDefense"))
    defense("UI_BTT_Bullet", "Bullet", call(item, "getBulletDefense"))
    addSection(model, section(T("UI_BTT_Sec_Protection", "PROTECTION"), prot))

    local comfort = {}
    local function stat(key, fb, v)
        v = pct(v)
        if v and v > 0.05 then table.insert(comfort, row(T(key, fb), fmt(v, 0) .. "%")) end
    end
    stat("UI_BTT_Insulation", "Insulation", call(item, "getInsulation"))
    stat("UI_BTT_Wind", "Wind resistance", call(item, "getWindresistance") or call(item, "getWindresist"))
    stat("UI_BTT_Water", "Water resistance", call(item, "getWaterResistance") or call(item, "getWaterresist"))
    local run, runC = speedMod(call(item, "getRunSpeedModifier"))
    if run then table.insert(comfort, row(T("UI_BTT_RunSpeed", "Running speed"), run, runC)) end
    local cmb, cmbC = speedMod(call(item, "getCombatSpeedModifier"))
    if cmb then table.insert(comfort, row(T("UI_BTT_CombatSpeed", "Combat speed"), cmb, cmbC)) end
    addSection(model, section(T("UI_BTT_Sec_Comfort", "COMFORT"), comfort))

    local state = {}
    local holes = num(call(item, "getHolesNumber"))
    if holes and holes > 0 then table.insert(state, row(T("UI_BTT_Holes", "Holes"), fmt(holes, 0), C.bad)) end
    local patches = num(call(item, "getPatchesNumber"))
    if patches and patches > 0 then table.insert(state, row(T("UI_BTT_Patches", "Patches"), fmt(patches, 0))) end
    local function level(key, fb, v)
        v = pct(v)
        if v and v >= 1 then table.insert(state, row(T(key, fb), fmt(v, 0) .. "%", C.warn)) end
    end
    level("UI_BTT_Blood", "Bloodiness", call(item, "getBloodLevel"))
    level("UI_BTT_Dirt", "Dirtiness", call(item, "getDirtiness"))
    level("UI_BTT_Wetness", "Wetness", call(item, "getWetness"))
    addSection(model, section(T("UI_BTT_Sec_State", "STATE"), state))
    return model
end

---------------------------------------------------------
-- Bags / containers
---------------------------------------------------------
local MAX_LIST = 10

local function buildContainer(item, player, model)
    table.insert(model.chips, T("UI_BTT_Chip_Container", "Container"))
    if call(item, "isEquipped") then table.insert(model.chips, T("UI_BTT_Chip_Equipped", "Equipped")) end

    local inv = call(item, "getInventory") or call(item, "getItemContainer")
    local cap = inv and player and num(call(inv, "getEffectiveCapacity", player))
    cap = cap or num(call(item, "getCapacity")) or (inv and num(call(inv, "getCapacity")))
    local used = inv and (num(call(inv, "getCapacityWeight")) or num(call(inv, "getContentsWeight")))
    if cap and cap > 0 and used then
        local frac = math.max(0, math.min(1, used / cap))
        model.bar = { label = T("UI_BTT_Contents", "Contents"), text = fmt(used, 1) .. " / " .. fmt(cap, 1),
                      frac = frac, color = frac > 0.9 and C.barWarn or C.barFluid }
    end

    local stats = {}
    if cap then table.insert(stats, row(T("UI_BTT_Capacity", "Capacity"), fmt(cap, 1))) end
    local wr = num(call(item, "getWeightReduction"))
    if wr and wr > 0 then table.insert(stats, row(T("UI_BTT_WeightReduction", "Weight reduction"), fmt(wr, 0) .. "%", C.good)) end
    local run, runC = speedMod(call(item, "getRunSpeedModifier"))
    if run then table.insert(stats, row(T("UI_BTT_RunSpeed", "Running speed"), run, runC)) end
    addSection(model, section(T("UI_BTT_Sec_Stats", "STATS"), stats))

    -- Contents, grouped by display name, biggest stacks first
    local items = inv and call(inv, "getItems")
    local n = items and num(call(items, "size")) or 0
    if n > 0 then
        local counts, order = {}, {}
        for i = 0, n - 1 do
            local it = items:get(i)
            local name = it and (call(it, "getDisplayName") or call(it, "getName"))
            if name then
                if not counts[name] then counts[name] = 0; table.insert(order, name) end
                counts[name] = counts[name] + 1
            end
        end
        table.sort(order, function(a, b)
            if counts[a] ~= counts[b] then return counts[a] > counts[b] end
            return a < b
        end)
        local list = {}
        for i, name in ipairs(order) do
            if i > MAX_LIST then break end
            table.insert(list, { name = name, count = "x" .. counts[name] })
        end
        if #order > MAX_LIST then
            table.insert(list, { name = T("UI_BTT_MoreItems", "+%1 more", #order - MAX_LIST), count = "" })
        end
        table.insert(model.sections, { title = T("UI_BTT_Sec_Inside", "INSIDE"), list = list })
    end
    return model
end

---------------------------------------------------------
-- Fluid containers (bottles, pots, jerry cans...)
---------------------------------------------------------
local function volume(liters, capLiters)
    if (capLiters or liters) < 10 then return fmt(liters * 1000, 0) .. " mL" end
    return fmt(liters, 1) .. " L"
end

local function buildFluid(item, player, model, fc)
    table.insert(model.chips, categoryChip(item) or T("UI_BTT_Chip_FluidContainer", "Fluid container"))
    local amount, cap = num(call(fc, "getAmount")) or 0, num(call(fc, "getCapacity")) or 0
    local fluidName
    if amount > 0 then
        local fluid = call(fc, "getPrimaryFluid")
        fluidName = fluid and (call(fluid, "getDisplayName") or call(fluid, "getFluidTypeString"))
    end
    if cap > 0 then
        local frac = math.max(0, math.min(1, amount / cap))
        model.bar = { label = fluidName or T("UI_BTT_Fluid", "Fluid"),
                      text = amount > 0 and (volume(amount, cap) .. " / " .. volume(cap, cap)) or T("UI_BTT_Empty", "Empty"),
                      frac = frac, color = C.barFluid }
    end
    -- condition matters for e.g. cooking pots that can break
    local cb = conditionBar(item)
    if cb and cb.frac < 1 then
        addSection(model, section(T("UI_BTT_Sec_State", "STATE"), { row(cb.label, cb.text, cb.frac < 0.3 and C.bad or nil) }))
    end
    return model
end

---------------------------------------------------------
-- Books, magazines, newspapers
-- Read-status rules follow vanilla's ISInventoryPane:isLiteratureRead.
---------------------------------------------------------
local MAX_RECIPES = 8

local function readingEffects(item, rows)
    local function eff(key, fb, v)
        v = num(v)
        if v and math.abs(v) >= 0.5 then table.insert(rows, row(T(key, fb), signed(v, 0), effectColor(v, false))) end
    end
    eff("UI_BTT_Boredom", "Boredom", call(item, "getBoredomChange"))
    eff("UI_BTT_Unhappiness", "Unhappiness", call(item, "getUnhappyChange"))
    eff("UI_BTT_Stress", "Stress", scaled(call(item, "getStressChange")))
end

-- Cached: looked up once per recipe id, so even a lookup that errors can
-- never repeat every frame.
local recipeNames = {}
local function recipeName(id)
    id = tostring(id)
    if recipeNames[id] then return recipeNames[id] end
    local ok, name = pcall(function() return Translator.getRecipeName(id) end)
    if not (ok and type(name) == "string" and name ~= "") then name = BT.pretty(id) end
    recipeNames[id] = name
    return name
end

local function knowsRecipe(player, id)
    local known = player and call(player, "getKnownRecipes")
    return known and call(known, "contains", id) == true
end

local function buildLiterature(item, player, model)
    local skill = call(item, "getSkillTrained")
    local book = SkillBook and skill and SkillBook[skill]
    local modData = call(item, "hasModData") and call(item, "getModData") or nil

    -- Pages (skill books and long reads)
    local pages = num(call(item, "getNumberOfPages")) or 0
    if pages > 0 then
        local read = player and num(call(player, "getAlreadyReadPages", call(item, "getFullType"))) or 0
        read = math.max(0, math.min(pages, read))
        local frac = read / pages
        model.bar = { label = T("UI_BTT_Pages", "Pages read"),
                      text = (read >= pages) and T("UI_BTT_Finished", "Finished") or (fmt(read, 0) .. " / " .. fmt(pages, 0)),
                      frac = frac, color = (read >= pages) and C.barGood or C.barFluid,
                      textColor = (read >= pages) and C.good or nil }
    end

    if book and book.perk then
        table.insert(model.chips, T("UI_BTT_Chip_SkillBook", "Skill book"))
        local perkLabel = perkName(book.perk)
        table.insert(model.chips, perkLabel)
        local from, to = num(call(item, "getLvlSkillTrained")), num(call(item, "getMaxLevelTrained"))
        local mine = player and num(call(player, "getPerkLevel", book.perk)) or nil
        local rows = {}
        if from and to and from > 0 then
            addRow(rows, T("UI_BTT_Teaches", "Teaches levels"), fmt(from, 0) .. " - " .. fmt(to, 0))
            -- vanilla volumes cover two levels each: 1-2 = vol 1 ... 9-10 = vol 5
            local mult = book["maxMultiplier" .. tostring(math.floor((from - 1) / 2) + 1)]
            if mult then addRow(rows, T("UI_BTT_XpBoost", "XP boost"), "x" .. fmt(mult, 1), C.good) end
        end
        if mine then
            addRow(rows, T("UI_BTT_Skill", "%1 skill", perkLabel), T("UI_BTT_Level", "Level %1", fmt(mine, 0)))
            if from and to and from > 0 then
                if from > mine + 1 then
                    addRow(rows, T("UI_BTT_Status", "Status"), T("UI_BTT_TooAdvanced", "Too advanced (need level %1)", fmt(from - 1, 0)), C.bad)
                elseif to < mine + 1 then
                    addRow(rows, T("UI_BTT_Status", "Status"), T("UI_BTT_AlreadyPast", "You're past this book"), C.label)
                else
                    addRow(rows, T("UI_BTT_Status", "Status"), T("UI_BTT_UsefulNow", "Useful now"), C.good)
                end
            end
        end
        addSection(model, section(T("UI_BTT_Sec_Skill", "SKILL"), rows))
        return model
    end

    -- Recipe magazines (list) or a single learned recipe in mod data
    local recipes = {}
    local list = call(item, "getLearnedRecipes")
    local n = list and num(call(list, "size")) or 0
    for i = 0, n - 1 do table.insert(recipes, list:get(i)) end
    if #recipes == 0 and modData and modData.learnedRecipe then table.insert(recipes, modData.learnedRecipe) end
    if #recipes > 0 then
        table.insert(model.chips, T("UI_BTT_Chip_Recipes", "Recipes"))
        local rows, newCount = {}, 0
        for i, id in ipairs(recipes) do
            local known = knowsRecipe(player, id)
            if not known then newCount = newCount + 1 end
            if i <= MAX_RECIPES then
                table.insert(rows, row(recipeName(id), known and T("UI_BTT_Known", "Known") or T("UI_BTT_New", "New"),
                                       known and C.label or C.good))
            end
        end
        if #recipes > MAX_RECIPES then
            table.insert(rows, row(T("UI_BTT_MoreItems", "+%1 more", #recipes - MAX_RECIPES), ""))
        end
        local title = T("UI_BTT_Sec_Teaches", "TEACHES")
        if newCount == 0 then title = title .. "  -  " .. T("UI_BTT_AllKnown", "ALL KNOWN") end
        addSection(model, section(title, rows))
        return model
    end

    -- Everything else readable: books, comics, newspapers, flyers
    table.insert(model.chips, categoryChip(item) or T("UI_BTT_Chip_Reading", "Reading"))
    local rows = {}
    readingEffects(item, rows)
    local readAlready = nil
    if modData and player then
        if modData.literatureTitle then readAlready = call(player, "isLiteratureRead", modData.literatureTitle) == true end
        if modData.printMedia and modData.printMedia.title then readAlready = call(player, "isPrintMediaRead", modData.printMedia.title) == true end
    end
    if readAlready ~= nil then
        table.insert(rows, row(T("UI_BTT_ReadIt", "Already read"), readAlready and T("UI_BTT_Yes", "Yes") or T("UI_BTT_No", "No"),
                               readAlready and C.label or C.good))
    end
    addSection(model, section(T("UI_BTT_Sec_WhenRead", "WHEN READ"), rows))
    return model
end

---------------------------------------------------------
-- Gun magazines (loose, not in a gun)
---------------------------------------------------------
local function buildMagazine(item, player, model, cur, max)
    table.insert(model.chips, T("UI_BTT_Chip_Magazine", "Magazine"))
    local frac = math.max(0, math.min(1, cur / max))
    model.bar = { label = T("UI_BTT_Ammo", "Loaded"), text = fmt(cur, 0) .. " / " .. fmt(max, 0),
                  frac = frac, color = frac > 0 and C.barFluid or C.barBad }
    local rows = {}
    local ammo = call(item, "getAmmoType")
    if ammo ~= nil then addRow(rows, T("UI_BTT_AmmoType", "Ammo"), itemName(ammo)) end
    addSection(model, section(T("UI_BTT_Sec_Stats", "STATS"), rows))
    return model
end

---------------------------------------------------------
-- Vehicle parts
---------------------------------------------------------
local function buildVehiclePart(item, player, model, mechType)
    table.insert(model.chips, T("UI_BTT_Chip_VehiclePart", "Vehicle part"))
    model.bar = conditionBar(item)
    local rows = {}
    local fits = getText("IGUI_VehicleType_" .. tostring(mechType))
    if fits and fits ~= "IGUI_VehicleType_" .. tostring(mechType) then
        addRow(rows, T("UI_BTT_Fits", "Fits"), fits)
    end
    local cap = num(call(item, "getMaxCapacity"))
    if cap and cap > 0 then addRow(rows, T("UI_BTT_Capacity", "Capacity"), fmt(cap, 0)) end
    addSection(model, section(T("UI_BTT_Sec_Stats", "STATS"), rows))
    return model
end

---------------------------------------------------------
-- Everything else ordinary: tools, materials, medical, batteries...
---------------------------------------------------------
-- These keep the vanilla tooltip: it shows special info a plain card would drop.
local VANILLA_ONLY = { "Radio", "Moveable", "AnimalInventoryItem", "AlarmClock", "AlarmClockClothing" }

local function keepVanilla(item)
    for _, cls in ipairs(VANILLA_ONLY) do
        if instanceof(item, cls) then return true end
    end
    if call(item, "isRecordedMedia") then return true end
    return false
end

local function buildGeneric(item, player, model)
    table.insert(model.chips, categoryChip(item) or T("UI_BTT_Chip_Item", "Item"))

    -- Uses (batteries, lighters, tape, thread, glue, propane...)
    if instanceof(item, "DrainableComboItem") then
        local cur, max = num(call(item, "getCurrentUses")), num(call(item, "getMaxUses"))
        local frac
        if cur and max and max > 0 then
            frac = cur / max
            model.bar = { label = T("UI_BTT_Uses", "Uses left"), text = fmt(cur, 0) .. " / " .. fmt(max, 0) }
        else
            local f = num(call(item, "getCurrentUsesFloat"))
            if f and f <= 1 then
                frac = f
                model.bar = { label = T("UI_BTT_Uses", "Uses left"), text = fmt(f * 100, 0) .. "%" }
            end
        end
        if model.bar then
            frac = math.max(0, math.min(1, frac))
            model.bar.frac, model.bar.color = frac, BT.barColor(frac)
        end
    end

    -- Condition, only when it actually matters (damaged)
    if not model.bar then
        local cb = conditionBar(item)
        if cb and cb.frac < 0.999 then model.bar = cb end
    end

    -- Medical
    local med = {}
    local bandage = num(call(item, "getBandagePower"))
    if bandage and bandage > 0 then addRow(med, T("UI_BTT_Bandage", "Bandage strength"), fmt(bandage, 1)) end
    local alcohol = num(call(item, "getAlcoholPower"))
    if alcohol and alcohol > 0 then addRow(med, T("UI_BTT_Disinfect", "Disinfectant strength"), fmt(alcohol, 1)) end
    addSection(model, section(T("UI_BTT_Sec_Medical", "MEDICAL"), med))
    return model
end

---------------------------------------------------------
-- Entry point
---------------------------------------------------------
function BT.Data.build(item, player)
    if not item then return nil end
    -- ISToolTipInv isn't only used for items: ISFluidBar passes a bare
    -- FluidContainer and ISEnergyBar passes a power Resource. Those have
    -- their own vanilla DoTooltip (e.g. the fluid amount) -- leave them be.
    if not instanceof(item, "InventoryItem") then return nil end
    if keepVanilla(item) then return nil end
    local model = baseModel(item)

    if instanceof(item, "HandWeapon") then return buildWeapon(item, player, model) end
    if instanceof(item, "Food") then return buildFood(item, player, model) end
    if instanceof(item, "Clothing") then return buildClothing(item, player, model) end
    if instanceof(item, "InventoryContainer") then return buildContainer(item, player, model) end
    if instanceof(item, "Literature") then return buildLiterature(item, player, model) end
    local fc = call(item, "getFluidContainer")
    if fc then return buildFluid(item, player, model, fc) end

    local maxAmmo = num(call(item, "getMaxAmmo"))
    if maxAmmo and maxAmmo > 0 then
        return buildMagazine(item, player, model, num(call(item, "getCurrentAmmoCount")) or 0, maxAmmo)
    end
    local mech = num(call(item, "getMechanicType"))
    if mech and mech > 0 then return buildVehiclePart(item, player, model, mech) end

    return buildGeneric(item, player, model)
end
