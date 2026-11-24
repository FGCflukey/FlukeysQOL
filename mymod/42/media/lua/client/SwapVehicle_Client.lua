------------------------------------------------------------
-- SwapVehicle Client Command Sender
-- Called by the UI when the player confirms a swap
------------------------------------------------------------

SwapVehicle_Client = {}

------------------------------------------------------------
-- Send swap request to server
------------------------------------------------------------
function SwapVehicle_Client.SendSwapRequest(player, vehicle, newScript)
    if not player or not vehicle or not newScript then
        print("[SwapVehicle] ERROR: missing data for swap request")
        return
    end

    local args = {
        vehicleId = vehicle:getId(),
        newScript = newScript,
    }

    sendClientCommand(player, "SwapVehicle", "Swap", args)
end

------------------------------------------------------------
-- Put the swapped vehicle back where the old one was, facing the same way.
-- In B42 MP the nearby player's game runs the vehicle's physics, so the server's
-- setAngles alone gets overwritten. Same approach as vanilla's debug Vehicle Angles
-- tool: pause physics, set the angles, then let physics carry on from there.
------------------------------------------------------------
local DEBUG = false
local function dbg(msg) if DEBUG then print("[SwapVehicle:Client] " .. tostring(msg)) end end

local WAIT_TICKS = 300   -- how long to wait for the new vehicle to reach this client (~5s)
local HOLD_TICKS = 10    -- how many ticks to hold it in place with physics paused

local pending = {}       -- vehicleId -> { args, waited, held }
local pendingCount = 0   -- PZ's Kahlua has no next(), so track the size ourselves

local function applyOrient(v, a)
    v:setX(a.x)
    v:setY(a.y)
    v:setZ(a.z)
    v:setAngles(a.ax, a.ay, a.az)
end

local function finish(id)
    pending[id] = nil
    pendingCount = pendingCount - 1
end

local function orientTick()
    local done = {}
    for id, p in pairs(pending) do
        local v = getVehicleById(id)
        if not v then
            p.waited = p.waited + 1
            if p.waited > WAIT_TICKS then
                dbg("vehicle " .. tostring(id) .. " never arrived, giving up")
                table.insert(done, id)
            end
        elseif p.held < HOLD_TICKS then
            v:setPhysicsActive(false, false)
            applyOrient(v, p.args)
            p.held = p.held + 1
        else
            v:setPhysicsActive(true, true)
            dbg("vehicle " .. tostring(id) .. " oriented to angleY " .. tostring(p.args.ay)
                .. ", client sees script " .. tostring(v:getScript() and v:getScript():getFullName()))
            table.insert(done, id)
        end
    end
    for _, id in ipairs(done) do finish(id) end
    if pendingCount <= 0 then
        pendingCount = 0
        Events.OnTick.Remove(orientTick)
    end
end

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "SwapVehicle" or command ~= "Orient" or not args or not args.vehicleId then return end
    local id = args.vehicleId
    if not pending[id] then
        if pendingCount == 0 then Events.OnTick.Add(orientTick) end
        pendingCount = pendingCount + 1
    end
    pending[id] = { args = args, waited = 0, held = 0 }
end)

------------------------------------------------------------
-- End of Client Command File
------------------------------------------------------------