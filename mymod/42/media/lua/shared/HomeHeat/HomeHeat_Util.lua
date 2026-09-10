-- HomeHeat_Util.lua
-- Shared constants + helpers for the HomeHeat radiator. Used by both
-- client and server so the two sides can never drift out of sync on
-- what counts as "has power" or what the preset temperatures are.

HomeHeat_Util = {}

-----------------------------------------------------
-- PRESETS (Celsius) -- these are what get sent over the
-- network and stored; the client-side C/F toggle only
-- changes how they're displayed, never what's stored.
-- Tweak tempC here if the felt warmth needs recalibrating
-- after in-game testing.
-----------------------------------------------------
HomeHeat_Util.PRESETS = {
    { key = "cool", label = "Cool", tempC = 15 },
    { key = "warm", label = "Warm", tempC = 20 },
    { key = "hot",  label = "Hot",  tempC = 24 },
}
HomeHeat_Util.DEFAULT_PRESET = "warm"
HomeHeat_Util.HEAT_RADIUS = 6

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
-----------------------------------------------------
function HomeHeat_Util.isRadiator(isoObject)
    if not isoObject then return false end
    local texture = isoObject:getTextureName()
    return texture ~= nil and string.match(texture, "^HomeHeat_[0-3]$") ~= nil
end

-----------------------------------------------------
-- Display helpers (client-side only, but harmless if
-- called from shared code)
-----------------------------------------------------
function HomeHeat_Util.celsiusToFahrenheit(c)
    return (c * 9 / 5) + 32
end

function HomeHeat_Util.formatTemp(tempC, useFahrenheit)
    if useFahrenheit then
        return math.floor(HomeHeat_Util.celsiusToFahrenheit(tempC) + 0.5) .. "F"
    end
    return math.floor(tempC + 0.5) .. "C"
end
