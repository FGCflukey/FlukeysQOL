-- Survivor Chopper Travel -- SERVER
--
-- Each craftRecipe in Survivor_Travel.txt (timedAction = Making) fires its
-- OnCreate here on completion. OnCreate runs from the server's own
-- authoritative execution, not just client prediction, so this must live
-- server-side. OnCreate gets (item, player); `player` is the character who
-- crafted the recipe.
--
-- Does NOT move the player directly: a server-side setX/Y/Z never updates
-- that client's screen. This tells the owning client where to go and
-- client/Survivor_Travel/Survivor_Travel.lua does the move.

local DEBUG = false
local function dbg(msg)
    if DEBUG then
        print("[Survivor_Travel] " .. tostring(msg))
    end
end

local function sendTravelCommand(player, x, y, z)
    if not player then return end
    dbg(player:getUsername() .. " travelling to (" .. x .. "," .. y .. "," .. z .. ")")
    sendServerCommand(player, "Survivor_Travel", "DoTeleport", { x = x, y = y, z = z })
end

function travelToRosewood(_item, player)    -- Rosewood
    sendTravelCommand(player, 8067, 11732, 2)
end

function travelToWestpoint(_item, player)    -- West Point
    sendTravelCommand(player, 11808, 6817, 1)
end

function travelToMuldraugh(_item, player)    -- Muldraugh
    sendTravelCommand(player, 10658, 10405, 1)
end

function travelToLouisville(_item, player)    -- Louisville
    sendTravelCommand(player, 12473, 1598, 6)
end

function travelToBrandenburg(_item, player)    -- Brandenburg
    sendTravelCommand(player, 2036, 5973, 1)
end

function travelToMarchridge(_item, player)    -- March Ridge
    sendTravelCommand(player, 10012, 12738, 1)
end

function travelToEkron(_item, player)    -- Ekron
    sendTravelCommand(player, 822, 9879, 1)
end

function travelToIrvington(_item, player)    -- Irvington
    sendTravelCommand(player, 10173, 12677, 1)
end

function travelToEchocreek(_item, player)    -- Echo Creek
    sendTravelCommand(player, 3611, 10954, 1)
end

function travelToRiverside(_item, player)    -- Riverside
    sendTravelCommand(player, 6083, 5237, 1)
end
