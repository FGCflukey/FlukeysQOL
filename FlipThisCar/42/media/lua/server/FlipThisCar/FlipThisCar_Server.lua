------------------------------------------------------------
-- Flip This Car - server (authoritative)
-- Re-checks everything the client checked, hands the car's physics to the
-- flipping player, turns it upright, then takes physics back.
------------------------------------------------------------

-- In MP, clients load server/ files too (the HomeHeat lesson). Only the real
-- server (or single-player, where isClient() is false) should run this.
if isClient() then return end

require "FlipThisCar/FlipThisCar_Shared"

local function dbg(msg) FlipThisCar.dbg("Server", msg) end

local RELEASE_AFTER_MS = 2000   -- keep the flipper as physics owner briefly after landing

local flipping = {}       -- vehicleId -> { vehicle, player, playerId, startedAt, doneAt }
local flippingCount = 0   -- PZ's Kahlua has no next()
local lastFlipAt = {}     -- username -> ms

local function reject(player, reasonKey)
    dbg("rejected " .. tostring(player and player:getUsername()) .. ": " .. tostring(reasonKey))
    if isServer() then
        sendServerCommand(player, FlipThisCar.MODULE, "rejected", { reason = reasonKey })
    elseif player then
        player:Say(getText(reasonKey))   -- single-player
    end
end

local function detachTowing(player, vehicle)
    -- Same call vanilla's own detachTrailer command uses (VehicleCommands.lua)
    local towing = vehicle:getVehicleTowing()
    if towing then
        vehicle:breakConstraint(player, true, false)
        dbg("detached towed vehicle")
    end
    local towedBy = vehicle:getVehicleTowedBy()
    if towedBy then
        towedBy:breakConstraint(player, true, false)
        dbg("detached from towing vehicle")
    end
end

-- Push Vehicle's pattern: take physics ownership off whoever has it and give it to
-- the flipping player, so their game (which also turns the car) is the one others follow.
local function giveAuthority(player, vehicle)
    if not isServer() then return end
    local pid = player:getOnlineID()
    local owner = vehicle:getNetPlayerId()
    if owner ~= -1 and owner ~= pid then
        local prev = getPlayerByOnlineID(owner)
        if prev then vehicle:authorizationServerOnSeat(prev, false) end
    end
    vehicle:authorizationServerOnSeat(player, true)
    dbg("physics owner was " .. tostring(owner) .. ", now " .. tostring(vehicle:getNetPlayerId())
        .. " (flipper " .. tostring(pid) .. ")")
end

local function releaseAuthority(entry)
    if not isServer() then return end
    local v = entry.vehicle
    if v and not v:isRemovedFromWorld() and entry.player and v:getNetPlayerId() == entry.playerId then
        v:authorizationServerOnSeat(entry.player, false)
        dbg("released physics ownership of vehicle " .. tostring(v:getId()))
    end
end

local function onTick()
    local now = getTimestampMs()
    local done = {}
    for id, e in pairs(flipping) do
        local v = e.vehicle
        if not v or v:isRemovedFromWorld() then
            table.insert(done, id)
        elseif not e.doneAt then
            local upright = FlipThisCar.turnStep(v)
            if upright or now - e.startedAt > FlipThisCar.TIMEOUT_MS then
                if not upright then
                    v:setPhysicsActive(true, true)
                    dbg("vehicle " .. tostring(id) .. " timed out turning, upDot=" .. tostring(v:getUpVectorDot()))
                else
                    dbg("vehicle " .. tostring(id) .. " upright on server, angleY=" .. tostring(v:getAngleY()))
                end
                e.doneAt = now
            end
        elseif now - e.doneAt >= RELEASE_AFTER_MS then
            releaseAuthority(e)
            table.insert(done, id)
        end
    end
    for _, id in ipairs(done) do
        flipping[id] = nil
        flippingCount = flippingCount - 1
    end
    if flippingCount <= 0 then
        flippingCount = 0
        Events.OnTick.Remove(onTick)
    end
end

function FlipThisCar.serverRequest(player, args)
    if not player or not args then return end
    local vehicle = getVehicleById(tonumber(args.vehicle) or -1)

    local ok, reason = FlipThisCar.check(player, vehicle)
    if not ok then return reject(player, reason) end

    local id = vehicle:getId()
    if flipping[id] then return reject(player, "Tooltip_FlipThisCar_Busy") end

    local now = getTimestampMs()
    local who = player:getUsername()
    if lastFlipAt[who] and now - lastFlipAt[who] < FlipThisCar.COOLDOWN_MS then
        return reject(player, "Tooltip_FlipThisCar_Cooldown")
    end
    lastFlipAt[who] = now

    dbg(who .. " flipping vehicle " .. tostring(id) .. " (" .. tostring(vehicle:getScript():getFullName())
        .. ") upDot=" .. tostring(vehicle:getUpVectorDot())
        .. " angles=" .. tostring(vehicle:getAngleX()) .. "," .. tostring(vehicle:getAngleY())
        .. "," .. tostring(vehicle:getAngleZ()))

    detachTowing(player, vehicle)
    giveAuthority(player, vehicle)

    if flippingCount == 0 then Events.OnTick.Add(onTick) end
    flippingCount = flippingCount + 1
    flipping[id] = { vehicle = vehicle, player = player, playerId = player:getOnlineID(), startedAt = now }

    -- Everyone hears the thump; the flipper's game also turns the car (it owns the physics now)
    if isServer() then
        sendServerCommand(FlipThisCar.MODULE, "startFlip", { vehicle = id, requester = player:getOnlineID() })
    end
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module == FlipThisCar.MODULE and command == "requestFlip" then
        FlipThisCar.serverRequest(player, args)
    end
end)
