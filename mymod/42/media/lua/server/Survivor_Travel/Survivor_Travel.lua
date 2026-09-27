-- Survivor Chopper Travel
--
-- Each craftRecipe in Survivor_Travel.txt (timedAction = Making) fires its
-- OnCreate here on completion. OnCreate runs from the server's own
-- authoritative execution, not just client prediction, so this must live
-- server-side -- matches this pack's own proven OnCreate hooks
-- (WalletCut_OnCreate, GiveBack_CarSeatStuff), which take (item, player)
-- positionally; `player` is the real character who crafted the recipe.
--
-- setLastX/Y/Z (not setX/Y/Z alone) is required too, or the destination
-- chunk never gets flagged to actually start loading -- same requirement
-- documented in the BasementBunkers mod's own WB.movePlayer.

local DEBUG = false
local function dbg(msg)
    if DEBUG then
        print("[Survivor_Travel] " .. tostring(msg))
    end
end

local function teleportPlayer(player, x, y, z)
    if not player then return end
    player:setX(x)
    player:setY(y)
    player:setZ(z)
    player:setLastX(x)
    player:setLastY(y)
    player:setLastZ(z)
    dbg(player:getUsername() .. " travelled to (" .. x .. "," .. y .. "," .. z .. ")")
end

function travelToRosewood(_item, player)    -- Rosewood
    teleportPlayer(player, 8067, 11732, 2)
end

function travelToWestpoint(_item, player)    -- West Point
    teleportPlayer(player, 11808, 6817, 1)
end

function travelToMuldraugh(_item, player)    -- Muldraugh
    teleportPlayer(player, 10658, 10405, 1)
end

function travelToLouisville(_item, player)    -- Louisville
    teleportPlayer(player, 12473, 1598, 6)
end

function travelToBrandenburg(_item, player)    -- Brandenburg
    teleportPlayer(player, 2036, 5973, 1)
end

function travelToMarchridge(_item, player)    -- March Ridge
    teleportPlayer(player, 10012, 12738, 1)
end

function travelToEkron(_item, player)    -- Ekron
    teleportPlayer(player, 822, 9879, 1)
end

function travelToIrvington(_item, player)    -- Irvington
    teleportPlayer(player, 10173, 12677, 1)
end

function travelToEchocreek(_item, player)    -- Echo Creek
    teleportPlayer(player, 3611, 10954, 1)
end

function travelToRiverside(_item, player)    -- Riverside
    teleportPlayer(player, 6083, 5237, 1)
end
