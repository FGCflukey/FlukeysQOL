-- HomeHeat_Util.lua
-- Shared constants + helpers for the HomeHeat radiator. Used by both
-- client and server so the two sides can never drift out of sync on
-- what counts as "has power" or what the preset temperatures are.

HomeHeat_Util = {}

-----------------------------------------------------
-- PRESETS -- tempC is the IsoHeatSource's own radiated
-- source temperature, not the felt room temperature.
-- In-game testing on a cold snowy night showed a fairly
-- consistent ~7C gap between source temp and felt temp
-- at typical standing distance (nominal 15/20/24 read as
-- roughly 8/13/17), so these run well above the old
-- 15/20/24 figures to compensate -- same reasoning Ed's
-- original mod used (his own source temps ran 25-40+ for
-- an intended room feel much lower than that).
-----------------------------------------------------
HomeHeat_Util.PRESETS = {
    { key = "cool", label = "Cool",   tempC = 22 },
    { key = "warm", label = "Normal", tempC = 28 },
    { key = "hot",  label = "Hot",    tempC = 34 },
}
HomeHeat_Util.DEFAULT_PRESET = "warm"
HomeHeat_Util.HEAT_RADIUS = 7

function HomeHeat_Util.presetByKey(key)
    for _, preset in ipairs(HomeHeat_Util.PRESETS) do
        if preset.key == key then return preset end
    end
    return nil
end

-----------------------------------------------------
-- Does this square have power to run the radiator?
-- Generator coverage, or grid power indoors.
-----------------------------------------------------
function HomeHeat_Util.hasPower(square)
    if not square then return false end
    return square:haveElectricity() or (square:hasGridPower() and not square:isOutside())
end

-----------------------------------------------------
-- Is this world object a placed HomeHeat radiator?
-- Matched by sprite texture name, same approach vanilla-
-- adjacent moveable mods use since a placed moveable's
-- iso object doesn't carry its originating item type directly.
--
-- The sprite itself is still named "eds_hk_0".."eds_hk_3"
-- -- that's baked as fixed strings into the compiled .pack
-- texture atlas (verified by hex-dumping it), so it can't be
-- renamed without corrupting the pack. Only the item's own
-- identity (Base.HomeHeatRadiator) and its in-game display
-- name are actually rebranded; this sprite-name check has to
-- match what the pack really contains.
-----------------------------------------------------
local function matchesRadiatorSprite(name)
    return name ~= nil and string.match(name, "^eds_hk_[0-3]$") ~= nil
end

function HomeHeat_Util.isRadiator(isoObject)
    if not isoObject then return false end

    if matchesRadiatorSprite(isoObject:getTextureName()) then return true end

    local sprite = isoObject:getSprite()
    if sprite and matchesRadiatorSprite(sprite:getName()) then return true end

    return false
end
