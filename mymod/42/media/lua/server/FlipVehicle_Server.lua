-- FlipVehicle_Server.lua
-- Server-authoritative handler for flipping a stopped, tipped-over vehicle
-- back upright. Rebuilds the Workshop mod "FlipVehicle" (SportXAI, id
-- 3764476627), which did the whole flip purely client-side with zero server
-- validation or sync -- in real MP the flip would only ever be visible to
-- whoever triggered it, reverting for everyone else on their next resync.
--
-- Does an instant snap-upright rather than the source mod's smooth multi-
-- tick animation: vanilla has dedicated sync calls for vehicle position/
-- direction/part-state (transmitPosition, transmitDirection, transmitPart*,
-- all confirmed real and already used elsewhere in this pack, e.g.
-- SwapVehicle_Server.lua), but no dedicated sync call for vehicle angles
-- specifically -- a single discrete change synced once is the safe,
-- verifiable choice.

local MAX_INTERACT_DISTANCE = 3 -- tiles
local FLIP_COOLDOWN_SECONDS = 3

-- DEBUG left on (2026-10-12) to diagnose "nothing happens, no errors either
-- side" -- flip back to false once confirmed working, per this pack's
-- standing debug-flag convention.
local DEBUG = true
local function dbg(msg)
    if DEBUG then
        print("[FlipVehicle:Server] " .. tostring(msg))
    end
end

local function GetDistanceToVehicle(player, vehicle)
    local dx = player:getX() - vehicle:getX()
    local dy = player:getY() - vehicle:getY()
    return math.sqrt(dx * dx + dy * dy)
end

local lastFlipTime = {}

local function isOnCooldown(player)
    local id = player:getUsername()
    local now = getTimestamp()
    local last = lastFlipTime[id]
    return last ~= nil and (now - last) < FLIP_COOLDOWN_SECONDS
end

local function markFlipTime(player)
    lastFlipTime[player:getUsername()] = getTimestamp()
end

-- Same detection formula as the client-side display gate
-- (FlipVehicle_Menu.lua) -- re-validated here since args from a
-- ClientCommand can never be trusted as-is.
local function isVehicleFlipped(vehicle)
    if not vehicle or not vehicle:isStopped() then return false end
    local script = vehicle:getScript()
    if not script then return false end
    -- Burnt/destroyed wrecks are decorative, not physics-active vehicles --
    -- forcing setPhysicsActive(true)/setAngles on one produces a broken,
    -- floating result (confirmed live 2026-10-12). Same real check vanilla
    -- itself uses to detect a burnt wreck (ISVehicleMenu.lua:867).
    if string.match(script:getName() or "", "Burnt") then return false end
    local shape = script:getPhysicsChassisShape()
    if not shape then return false end
    local shapeY = shape:y()
    local vectorDot = vehicle:getUpVectorDot()
    return vectorDot + (vectorDot - shapeY) <= 0
end

local function OnClientCommand_FlipVehicle(module, command, player, args)
    if module ~= "FlipVehicle" then return end
    if command ~= "Flip" then return end
    if not player or not args then return end

    if isOnCooldown(player) then
        dbg(player:getUsername() .. " rejected: on cooldown")
        return
    end

    if not args.vehicleID then
        dbg("rejected: missing vehicleID")
        return
    end

    local vehicle = getVehicleById(args.vehicleID)
    if not vehicle then
        dbg("rejected: vehicle not found for id " .. tostring(args.vehicleID))
        return
    end

    -- Diagnostic (2026-10-12): server reported success but nothing visibly
    -- changed for a prior test vehicle -- dump everything that could explain
    -- a "ran fine, synced nothing" outcome before guessing further.
    local script = vehicle:getScript()
    dbg("vehicle " .. tostring(args.vehicleID) .. " script=" .. tostring(script and script:getName())
        .. " removedFromWorld=" .. tostring(vehicle:isRemovedFromWorld())
        .. " hasTransmitPosition=" .. tostring(vehicle.transmitPosition ~= nil)
        .. " hasTransmitDirection=" .. tostring(vehicle.transmitDirection ~= nil)
        .. " anglesBefore=" .. tostring(vehicle:getAngleX()) .. "," .. tostring(vehicle:getAngleY()) .. "," .. tostring(vehicle:getAngleZ()))

    if GetDistanceToVehicle(player, vehicle) > MAX_INTERACT_DISTANCE then
        dbg(player:getUsername() .. " rejected: too far from vehicle " .. tostring(args.vehicleID))
        return
    end

    if not isVehicleFlipped(vehicle) then
        dbg("rejected: vehicle " .. tostring(args.vehicleID) .. " is not actually flipped")
        return
    end

    markFlipTime(player)

    vehicle:setAngles(0, 0, 0)
    vehicle:setPhysicsActive(true)

    -- CONFIRMED (2026-10-12 live test): `if vehicle.transmitPosition then ...`
    -- always evaluated false for a real, already-existing vehicle obtained via
    -- getVehicleById -- the server-side angle change genuinely happened
    -- (confirmed via logged before/after angles) but was never synced to any
    -- client, including the triggering player's own. Likely the same Kahlua
    -- Java-method-binding quirk already hit elsewhere in this pack (a plain
    -- existence check doesn't reliably detect a real Java-bound method).
    -- Calling directly through pcall instead -- fires if the method is real
    -- regardless of what the existence check claimed, and fails safe if it
    -- genuinely isn't there.
    local okPos, errPos = pcall(function() vehicle:transmitPosition() end)
    local okDir, errDir = pcall(function() vehicle:transmitDirection() end)
    dbg("transmitPosition ok=" .. tostring(okPos) .. (okPos and "" or (" err=" .. tostring(errPos))))
    dbg("transmitDirection ok=" .. tostring(okDir) .. (okDir and "" or (" err=" .. tostring(errDir))))

    dbg(player:getUsername() .. " flipped vehicle " .. tostring(args.vehicleID) .. " upright"
        .. " anglesAfter=" .. tostring(vehicle:getAngleX()) .. "," .. tostring(vehicle:getAngleY()) .. "," .. tostring(vehicle:getAngleZ()))
end

Events.OnClientCommand.Add(OnClientCommand_FlipVehicle)
