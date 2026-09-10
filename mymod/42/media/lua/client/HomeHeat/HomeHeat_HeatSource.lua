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
-- Active fallback scan around the local player. OnObjectAdded alone
-- only reliably catches a radiator placed fresh during THIS session --
-- one that already existed before you connected/reconnected doesn't
-- necessarily re-fire it, leaving this client's registry empty for an
-- object that's otherwise completely real and interactable. Scanning
-- a modest area around the player directly (same approach the earlier
-- debug SCAN used successfully) closes that gap.
-----------------------------------------------------
local SCAN_RADIUS = HomeHeat_Util.HEAT_RADIUS + 4

local function scanForRadiators()
    local player = getPlayer()
    if not player then return end

    local cell = getCell()
    local px = math.floor(player:getX())
    local py = math.floor(player:getY())
    local pz = player:getZ()

    for dx = -SCAN_RADIUS, SCAN_RADIUS do
        for dy = -SCAN_RADIUS, SCAN_RADIUS do
            local sq = cell:getGridSquare(px + dx, py + dy, pz)
            if sq then
                local objs = sq:getObjects()
                for i = 0, objs:size() - 1 do
                    register(objs:get(i))
                end
            end
        end
    end
end

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

    scanForRadiators()

    for k, entry in pairs(knownRadiators) do
        if not updateOne(k, entry) then
            knownRadiators[k] = nil
        end
    end
end

Events.OnTick.Add(OnTick)
