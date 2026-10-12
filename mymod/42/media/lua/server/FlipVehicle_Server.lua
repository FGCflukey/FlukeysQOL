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
    if vehicle.transmitPosition then vehicle:transmitPosition() end
    if vehicle.transmitDirection then vehicle:transmitDirection() end

    dbg(player:getUsername() .. " flipped vehicle " .. tostring(args.vehicleID) .. " upright")
end

Events.OnClientCommand.Add(OnClientCommand_FlipVehicle)
