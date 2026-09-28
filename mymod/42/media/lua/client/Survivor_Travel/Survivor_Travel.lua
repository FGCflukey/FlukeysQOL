-- Survivor Chopper Travel -- CLIENT
--
-- Does the actual move. Confirmed via the Workshop mod "FastTravelMP"
-- (3775394486)'s own real-tested notes: a server directly mutating a
-- remote player's x/y/z is genuinely correct server-side (survives
-- reconnect) but never live-updates that client's own screen -- only the
-- owning client calling player:teleportTo() on its own local character
-- does. server/Survivor_Travel/Survivor_Travel.lua sends the destination
-- here instead of moving the player itself.

local DEBUG = false
local function dbg(msg)
    if DEBUG then
        print("[Survivor_Travel:Client] " .. tostring(msg))
    end
end

local function OnServerCommand(module, command, args)
    if module ~= "Survivor_Travel" or command ~= "DoTeleport" then return end
    if not args then return end

    local player = getPlayer()
    if not player then return end

    local x, y, z = math.floor(args.x), math.floor(args.y), math.floor(args.z)
    local ok, err = pcall(function()
        player:teleportTo(x, y, z)
        player:setCurrentSquareFromPosition(x, y, z)
    end)
    if not ok then
        dbg("teleportTo failed: " .. tostring(err))
        return
    end
    dbg("Arrived at (" .. x .. "," .. y .. "," .. z .. ")")
end

Events.OnServerCommand.Add(OnServerCommand)
