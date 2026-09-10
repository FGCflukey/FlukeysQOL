-- HomeHeat_HeatSource.lua
-- Per-client management of the actual IsoHeatSource for every known
-- HomeHeat radiator. IsoHeatSource is a local/client-side simulation
-- object, so every client runs this independently (not just whoever
-- placed or set the radiator) -- that's what makes anyone visiting a
-- heated house actually get warm, not just the owner.

-- TEMP DEBUG: safe to remove once heating is confirmed working.
local DEBUG = true
local function dbg(msg)
    if DEBUG then print("[HomeHeat:HeatSource] " .. tostring(msg)) end
end

local knownRadiators = {} -- key "x,y,z" -> { isoObject = ..., heatsrc = nil }

local function makeKey(x, y, z)
    return x .. "," .. y .. "," .. z
end

local function register(isoObject)
    if not HomeHeat_Util.isRadiator(isoObject) then return end
    local k = makeKey(isoObject:getX(), isoObject:getY(), isoObject:getZ())
    if knownRadiators[k] then return end
    dbg("Registered radiator at " .. k)
    knownRadiators[k] = { isoObject = isoObject }
end

Events.OnObjectAdded.Add(register)

-----------------------------------------------------
-- Sync one radiator's local heat source to its current
-- modData (on/preset) and power state. Returns false if
-- the entry is stale and should be dropped from the registry.
-----------------------------------------------------
local function updateOne(k, entry)
    local isoObject = entry.isoObject
    local square = isoObject and isoObject:getSquare()

    if not isoObject or not square then
        dbg(k .. ": object/square gone, dropping")
        if entry.heatsrc then
            getCell():removeHeatSource(entry.heatsrc)
            entry.heatsrc = nil
        end
        return false
    end

    local modData = isoObject:getModData()
    local on = modData.on == true
    local power = HomeHeat_Util.hasPower(square)
    local outside = square:isOutside()
    -- Indoor-only by design: doesn't heat at all if the square it's on
    -- is outside, rather than just placement being restricted.
    local active = on and power and not outside

    dbg(k .. ": on=" .. tostring(on) .. " power=" .. tostring(power) .. " outside=" .. tostring(outside) ..
        " presetKey=" .. tostring(modData.presetKey) .. " active=" .. tostring(active) ..
        " hasHeatsrc=" .. tostring(entry.heatsrc ~= nil))

    if active then
        local preset = HomeHeat_Util.presetByKey(modData.presetKey) or HomeHeat_Util.presetByKey(HomeHeat_Util.DEFAULT_PRESET)
        local temp = preset.tempC
        local radius = HomeHeat_Util.HEAT_RADIUS

        if not entry.heatsrc then
            dbg(k .. ": creating IsoHeatSource temp=" .. tostring(temp) .. " radius=" .. tostring(radius))
            entry.heatsrc = IsoHeatSource.new(isoObject:getX(), isoObject:getY(), isoObject:getZ(), radius, temp)
            getCell():addHeatSource(entry.heatsrc)
        else
            entry.heatsrc:setTemperature(temp)
            entry.heatsrc:setRadius(radius)
        end
    elseif entry.heatsrc then
        dbg(k .. ": removing IsoHeatSource")
        getCell():removeHeatSource(entry.heatsrc)
        entry.heatsrc = nil
    end

    return true
end

-----------------------------------------------------
-- Throttled scan -- cheap (a handful of radiators at
-- most in a private game), but no need to run it every
-- single frame.
-----------------------------------------------------
local TICKS_BETWEEN_SCANS = 30
local tickCounter = 0

local function OnTick()
    tickCounter = tickCounter + 1
    if tickCounter < TICKS_BETWEEN_SCANS then return end
    tickCounter = 0

    for k, entry in pairs(knownRadiators) do
        if not updateOne(k, entry) then
            knownRadiators[k] = nil
        end
    end
end

Events.OnTick.Add(OnTick)
