-- Play Arcade Machines -- SERVER
--
-- Client only ever says "I started/stopped playing machine at (x,y,z)".
-- This file owns the real stat reduction: a periodic watchdog re-validates
-- power and that the player is still actually there, and applies a
-- proportional slice of the sandbox-configured reduction each pass --
-- matching the watchdog pattern already proven in this pack (HomeHeat).
-- Never trusts a client-reported amount, only a client-reported "I'm at
-- this machine" claim, which gets re-checked every pass.

local DEBUG = false
local function dbg(msg)
    if DEBUG then
        print("[PlayArcadeMachines:Server] " .. tostring(msg))
    end
end

-- Keyed by player username -> { player=, x=, y=, z=, machineType= }
local playing = {}

local function isAmbientGridStillOn()
    local ok, powerOffDay = pcall(function() return getSandboxOptions():getElecShutModifier() end)
    if not ok then return true end
    if powerOffDay <= -1 then return true end
    local ok2, day = pcall(function()
        return getGameTime():getWorldAgeHours() / 24 + (getSandboxOptions():getTimeSinceApo() - 1) * 30
    end)
    if not ok2 then return true end
    return day < powerOffDay
end

local function isMachinePowered(square)
    if not square then return false end
    local ok, real = pcall(function() return square:haveElectricity() end)
    if ok and real then return true end
    local ok2, gridOn = pcall(function() return square:hasGridPower() end)
    return ok2 and gridOn and isAmbientGridStillOn()
end

local function getOption(name, default)
    local vars = SandboxVars and SandboxVars.ArcadePlay
    if vars and vars[name] ~= nil then return vars[name] end
    return default
end

local WATCHDOG_INTERVAL = 30 -- ~1s, matches the client's 3000-tick (~100s) full session

local function onClientCommand(module, command, player, args)
    if module ~= "PlayArcadeMachines" then return end
    if not player then return end

    if command == "StartPlaying" then
        if not args or not args.x then return end
        playing[player:getUsername()] = {
            player = player,
            x = args.x, y = args.y, z = args.z,
            machineType = args.machineType,
        }
        dbg(player:getUsername() .. " started playing at (" .. args.x .. "," .. args.y .. "," .. args.z .. ")")
    elseif command == "StopPlaying" then
        playing[player:getUsername()] = nil
        dbg(player:getUsername() .. " stopped playing")
    end
end
Events.OnClientCommand.Add(onClientCommand)

local watchdogTicks = 0
Events.OnTick.Add(function()
    watchdogTicks = watchdogTicks + 1
    if watchdogTicks < WATCHDOG_INTERVAL then return end
    watchdogTicks = 0

    for username, entry in pairs(playing) do
        local player = entry.player
        local ok, isValid = pcall(function()
            if not player or player:isDead() then return false end
            local square = getCell():getGridSquare(entry.x, entry.y, entry.z)
            return isMachinePowered(square)
        end)

        if ok and isValid then
            local boredomPct = getOption("BoredomDecrease", 33)
            local unhappinessPct = getOption("UnhappinessDecrease", 33)
            local stressPct = getOption("StressDecrease", 33)

            -- WATCHDOG_INTERVAL ticks out of a 3000-tick full session -- same
            -- per-slice math the original used, just driven server-side.
            local fraction = WATCHDOG_INTERVAL / 3000

            local applied, err = pcall(function()
                local bodyDamage = player:getBodyDamage()
                if bodyDamage then
                    bodyDamage:setBoredomLevel(math.max(0, bodyDamage:getBoredomLevel() - boredomPct * fraction))
                    bodyDamage:setUnhappynessLevel(math.max(0, bodyDamage:getUnhappynessLevel() - unhappinessPct * fraction))
                end
                local stats = player:getStats()
                if stats then
                    local currentStress = stats:getStress() - stats:getStressFromCigarettes()
                    stats:setStress(math.max(0, currentStress - (stressPct / 100) * fraction))
                end
            end)
            if not applied then
                dbg("stat update failed for " .. username .. ": " .. tostring(err))
            end
        else
            -- Power cut out, player died/disconnected, or square gone --
            -- stop crediting them silently rather than erroring every pass.
            playing[username] = nil
            dbg(username .. " dropped from watchdog (no longer valid)")
        end
    end
end)
