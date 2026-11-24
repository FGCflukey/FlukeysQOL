------------------------------------------------------------
-- Flip This Car - shared definitions + checks (client and server)
--
-- Our own build, informed by reading FlipVehiclePlusTrailer (3430172149), its
-- multiplayer fix FlipVehicleFix (3843842246) and Push Vehicle (3780639614):
--  * B42 MP: the player whose game "owns" a vehicle's physics overrides the
--    server's rotation, so the flip runs on the server AND on that player's game,
--    with physics paused while it turns (FlipVehicleFix's finding).
--  * The server explicitly hands physics ownership to the flipping player first
--    (authorizationServerOnSeat), as Push Vehicle does, so it can't be someone else.
--  * setAngles(0, heading, 0) keeps the car's heading. Vanilla's flipUpright() was
--    checked in projectzomboid.jar: it resets the heading to 0, so it isn't used.
------------------------------------------------------------

FlipThisCar = FlipThisCar or {}

local DEBUG = true
function FlipThisCar.dbg(side, msg)
    if DEBUG then print("[FlipThisCar:" .. tostring(side) .. "] " .. tostring(msg)) end
end

FlipThisCar.MODULE        = "FlipThisCar"
FlipThisCar.MAX_DIST      = 6.0     -- tiles from the vehicle's centre (long trucks need room)
FlipThisCar.MAX_SPEED_KMH = 1.0     -- must be standing still
FlipThisCar.UPRIGHT_BELOW = 0.5     -- getUpVectorDot() under this = on its side / roof
FlipThisCar.UPRIGHT_DONE  = 0.99    -- getUpVectorDot() over this = back on its wheels
FlipThisCar.TURN_STEP     = 0.15    -- fraction of the remaining tilt removed per tick
FlipThisCar.TIMEOUT_MS    = 15000   -- give up turning after this long
FlipThisCar.COOLDOWN_MS   = 5000    -- per player, between accepted flips
FlipThisCar.HEAVES        = 3       -- shoves before the car goes over
FlipThisCar.HEAVE_MS      = 1000    -- time between shoves
FlipThisCar.SOUND         = "thumpa2"   -- vanilla vehicle-impact thump (as Push Vehicle)

function FlipThisCar.getMinStrength()
    local vars = SandboxVars and SandboxVars.FlipThisCar
    local v = vars and tonumber(vars.MinStrength) or 5
    if v < 0 then v = 0 end
    if v > 10 then v = 10 end
    return v
end

function FlipThisCar.needsFlip(vehicle)
    return vehicle:getUpVectorDot() < FlipThisCar.UPRIGHT_BELOW
end

function FlipThisCar.isBurnt(vehicle)
    local script = vehicle:getScript()
    local name = script and script:getName() or ""
    return string.find(name, "Burnt", 1, true) ~= nil
end

function FlipThisCar.isNear(player, vehicle)
    local dx = player:getX() - vehicle:getX()
    local dy = player:getY() - vehicle:getY()
    return dx * dx + dy * dy <= FlipThisCar.MAX_DIST * FlipThisCar.MAX_DIST
end

function FlipThisCar.hasOccupants(vehicle)
    for seat = 0, vehicle:getMaxPassengers() - 1 do
        if vehicle:getCharacter(seat) then return true end
    end
    return false
end

-- Returns ok, reasonKey (a Tooltip_ translation key when not ok).
-- Order matters: the context menu hides the option entirely for the first ones.
function FlipThisCar.check(player, vehicle)
    if not player or not vehicle or vehicle:isRemovedFromWorld() then
        return false, "Tooltip_FlipThisCar_NoVehicle"
    end
    if not FlipThisCar.needsFlip(vehicle) then return false, "Tooltip_FlipThisCar_NotFlipped" end
    if FlipThisCar.isBurnt(vehicle) then return false, "Tooltip_FlipThisCar_Burnt" end
    if player:getVehicle() then return false, "Tooltip_FlipThisCar_ExitVehicle" end
    if not FlipThisCar.isNear(player, vehicle) then return false, "Tooltip_FlipThisCar_TooFar" end
    if math.abs(vehicle:getCurrentAbsoluteSpeedKmHour()) > FlipThisCar.MAX_SPEED_KMH then
        return false, "Tooltip_FlipThisCar_Moving"
    end
    if FlipThisCar.hasOccupants(vehicle) then return false, "Tooltip_FlipThisCar_Occupied" end
    if player:getPerkLevel(Perks.Strength) < FlipThisCar.getMinStrength() then
        return false, "Tooltip_FlipThisCar_TooWeak"
    end
    return true, nil
end

-- One tick of turning the car upright, keeping its heading (angle Y).
-- Returns true once it's upright (physics switched back on).
function FlipThisCar.turnStep(vehicle)
    if vehicle:getUpVectorDot() > FlipThisCar.UPRIGHT_DONE then
        vehicle:setAngles(0, vehicle:getAngleY(), 0)
        vehicle:setPhysicsActive(true, true)
        return true
    end
    -- Same approach as vanilla's debug Vehicle Angles tool: pause physics while rotating
    vehicle:setPhysicsActive(false, false)
    local s = FlipThisCar.TURN_STEP
    local x, z = vehicle:getAngleX(), vehicle:getAngleZ()
    vehicle:setAngles(x - x * s, vehicle:getAngleY(), z - z * s)
    return false
end
