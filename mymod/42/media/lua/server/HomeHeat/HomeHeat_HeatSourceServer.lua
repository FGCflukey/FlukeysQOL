-- HomeHeat_HeatSourceServer.lua
-- Server-side counterpart to the client's HomeHeat_HeatSource.lua.
--
-- The client-side IsoHeatSource we already create is what drives the
-- local ambient-temperature HUD reading, and that part was confirmed
-- working. But the actual body-temperature/cold-moodle simulation is
-- server-authoritative in MP and only reads heat sources the SERVER
-- itself knows about -- a client-only IsoHeatSource is invisible to
-- it. Vanilla's own precedent (campfires) creates its heat-emitting
-- object server-side, in server/Camping/SCampfireGlobalObject.lua,
-- gated by server/Camping/SCampfireSystem.lua's "if isClient() then
-- return end" -- the client there never builds its own heat source at
-- all, it only mirrors replicated state. This file closes that same
-- gap for HomeHeat: without it, standing next to a radiator can show
-- a warm local temperature reading while the character still shows
-- cold hands/feet and the cold moodle, because the server-side body-
-- warmth calculation never found a heat source to factor in.

-- TEMPORARY debug logging -- added 2026-09-17 to catch a reported
-- "thermometer says warm but player still feels cold after sleeping"
-- case. Logs every state transition (created/removed/why) plus a
-- periodic heartbeat, specifically so a next occurrence tells us
-- whether Events.EveryOneMinute keeps firing correctly through a
-- sleep time-skip, and whether the heat source was ever actually
-- dropped server-side vs. this being a client-display-only issue.
-- Safe to remove once the root cause is confirmed.
local DEBUG = true
local function dbg(msg) if DEBUG then print("[HomeHeat:HeatSourceServer] " .. tostring(msg)) end end

local knownRadiators = {} -- key "x,y,z" -> { isoObject = ..., heatsrc = nil }
local heartbeatCounter = 0

local function makeKey(x, y, z)
    return x .. "," .. y .. "," .. z
end

local function register(isoObject)
    if not HomeHeat_Util.isRadiator(isoObject) then return end
    local k = makeKey(isoObject:getX(), isoObject:getY(), isoObject:getZ())
    if knownRadiators[k] then return end
    knownRadiators[k] = { isoObject = isoObject, key = k }
    dbg("Registered new radiator at " .. k)
end

Events.OnObjectAdded.Add(register)

-----------------------------------------------------
-- Active fallback scan around every connected player -- same
-- reasoning as the client-side scan: OnObjectAdded alone doesn't
-- reliably catch a radiator that already existed before a player
-- connected/reconnected or before the server itself restarted.
-----------------------------------------------------
local SCAN_RADIUS = HomeHeat_Util.HEAT_RADIUS + 4

local function scanForRadiators()
    local cell = getCell()
    local players = getOnlinePlayers()

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player then
            local px = math.floor(player:getX())
            local py = math.floor(player:getY())
            local pz = player:getZ()

            for dx = -SCAN_RADIUS, SCAN_RADIUS do
                for dy = -SCAN_RADIUS, SCAN_RADIUS do
                    local sq = cell:getGridSquare(px + dx, py + dy, pz)
                    if sq then
                        local objs = sq:getObjects()
                        for j = 0, objs:size() - 1 do
                            register(objs:get(j))
                        end
                    end
                end
            end
        end
    end
end

-----------------------------------------------------
-- Sync one radiator's server-side heat source to its current
-- modData (on/preset) and power state. Returns false if the
-- entry is stale and should be dropped from the registry.
-----------------------------------------------------
local function updateOne(entry)
    local isoObject = entry.isoObject
    local square = isoObject and isoObject:getSquare()

    if not isoObject or not square then
        if entry.heatsrc then
            dbg("DROPPING radiator " .. tostring(entry.key) .. " -- isoObject/square gone, removing heat source")
            getCell():removeHeatSource(entry.heatsrc)
            entry.heatsrc = nil
        end
        return false
    end

    local modData = isoObject:getModData()
    local on = modData.on == true
    local power = HomeHeat_Util.hasPower(square)
    local outside = square:isOutside()
    local active = on and power and not outside

    if active then
        local preset = HomeHeat_Util.presetByKey(modData.presetKey) or HomeHeat_Util.presetByKey(HomeHeat_Util.DEFAULT_PRESET)
        local temp = preset.tempC
        local radius = HomeHeat_Util.HEAT_RADIUS

        if not entry.heatsrc then
            entry.heatsrc = IsoHeatSource.new(isoObject:getX(), isoObject:getY(), isoObject:getZ(), radius, temp)
            getCell():addHeatSource(entry.heatsrc)
            dbg("CREATED heat source for " .. tostring(entry.key) .. " temp=" .. tostring(temp) .. " radius=" .. tostring(radius))
        else
            entry.heatsrc:setTemperature(temp)
            entry.heatsrc:setRadius(radius)
        end
    elseif entry.heatsrc then
        dbg("REMOVED heat source for " .. tostring(entry.key) .. " -- on=" .. tostring(on) .. " power=" .. tostring(power) .. " outside=" .. tostring(outside))
        getCell():removeHeatSource(entry.heatsrc)
        entry.heatsrc = nil
    end

    return true
end

-----------------------------------------------------
-- Server-side periodic tasks conventionally run on a slower
-- cadence than client OnTick (matches vanilla precedent, e.g.
-- Ed's own SEdsRadiatorSystem.EveryOneMinute power check) --
-- body warmth doesn't need sub-second responsiveness.
-----------------------------------------------------
local function EveryOneMinute()
    -- Heartbeat every 30 calls (~30 in-game minutes) -- confirms this
    -- event keeps firing through a sleep time-skip at all, which is
    -- the single biggest unknown in the "warm thermometer, still cold
    -- after sleeping" report this is instrumenting.
    heartbeatCounter = heartbeatCounter + 1
    if heartbeatCounter >= 30 then
        heartbeatCounter = 0
        local tracked, active = 0, 0
        for _, entry in pairs(knownRadiators) do
            tracked = tracked + 1
            if entry.heatsrc then active = active + 1 end
        end
        -- getGameTime():getWorldAgeHours() is a real, widely-used vanilla
        -- call (e.g. server/Vehicles/Vehicles.lua) -- used here instead of
        -- guessing at an unconfirmed timestamp method.
        dbg("Heartbeat: tracking " .. tracked .. " radiator(s), " .. active
            .. " with an active heat source, at world age " .. tostring(getGameTime():getWorldAgeHours()) .. "h")
    end

    scanForRadiators()

    for k, entry in pairs(knownRadiators) do
        if not updateOne(entry) then
            knownRadiators[k] = nil
        end
    end
end

Events.EveryOneMinute.Add(EveryOneMinute)
