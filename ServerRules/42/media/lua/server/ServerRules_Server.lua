-- ServerRules_Server.lua
-- Server-authoritative side of Server Rules:
--   * reads the rules config (Zomboid/Lua/ServerRules.txt override, else the mod's own copy),
--     fresh on every check so edits apply to the next joining player without a restart
--   * keeps who accepted which rules version in global ModData (saved with the world)
--   * appends every accept / decline / timeout to Zomboid/Lua/ServerRules_log.txt
--   * optionally protects a player (god mode + invisible) while the rules window is open
--
-- The player identity always comes from the server's own player object, never from the
-- client's args. The client-reported Steam ID string is only written to the log for display.

if isClient() then return end

require "ServerRules_Shared"

local DEBUG = false
local function dbg(msg) if DEBUG then print("[ServerRules:Server] " .. tostring(msg)) end end

local MOD_ID      = "ServerRules"
local CONFIG_NAME = "ServerRules.txt"
local LOG_NAME    = "ServerRules_log.txt"
local RECORD_KEY  = "ServerRules_Accepted"

---------------------------------------------------------
-- Config
---------------------------------------------------------
local function trim(s)
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")
    return s
end

local function openConfigReader()
    -- Server owner's override copy in Zomboid/Lua/ wins
    local ok, reader = pcall(getFileReader, CONFIG_NAME, false)
    if ok and reader then return reader, "Zomboid/Lua/" .. CONFIG_NAME end
    -- Otherwise the copy shipped in the mod. The path is resolved against the mod folder,
    -- which differs between layouts, so try each.
    for _, path in ipairs({ "media/" .. CONFIG_NAME, "42/media/" .. CONFIG_NAME, "common/media/" .. CONFIG_NAME }) do
        ok, reader = pcall(getModFileReader, MOD_ID, path, false)
        if ok and reader then return reader, path end
    end
    return nil, nil
end

local function toBool(v, default)
    if v == nil then return default end
    v = string.lower(v)
    if v == "true" or v == "yes" or v == "1" then return true end
    if v == "false" or v == "no" or v == "0" then return false end
    return default
end

local function loadConfig()
    local reader, source = openConfigReader()
    if not reader then
        print("[ServerRules] WARNING: no " .. CONFIG_NAME .. " found, nothing will be shown to players")
        return nil
    end

    local keys, welcome, rules = {}, {}, {}
    local section = nil
    local line = reader:readLine()
    while line ~= nil do
        local t = trim(line)
        if t:sub(1, 1) == "#" then
            -- comment
        elseif t:match("^%[(%w+)%]$") then
            section = string.lower(t:match("^%[(%w+)%]$"))
        elseif section == "welcome" then
            table.insert(welcome, t)
        elseif section == "rules" then
            if t ~= "" then
                table.insert(rules, trim((t:gsub("^[-*]%s*", ""))))
            end
        elseif t ~= "" then
            local k, v = t:match("^([%w_]+)%s*=%s*(.-)$")
            if k then keys[string.lower(k)] = v end
        end
        line = reader:readLine()
    end
    reader:close()

    -- Trim blank lines off both ends of the welcome text, keep blank lines inside as paragraph breaks
    while #welcome > 0 and welcome[1] == "" do table.remove(welcome, 1) end
    while #welcome > 0 and welcome[#welcome] == "" do table.remove(welcome) end

    local cfg = {
        version   = tonumber(keys.version) or 1,
        title     = keys.title,
        banner    = keys.banner,
        timeLimit = math.max(0, math.floor(tonumber(keys.timelimitseconds) or 300)),
        protect   = toBool(keys.protectwhilereading, true),
        welcome   = table.concat(welcome, " <LINE> "),   -- ISRichTextPanel line-break tag
        rules     = rules,
    }
    dbg("config from " .. tostring(source) .. ": version=" .. cfg.version .. " rules=" .. #rules)
    return cfg
end

---------------------------------------------------------
-- Records
---------------------------------------------------------
local function getData()
    local data = ModData.getOrCreate(RECORD_KEY)
    data.players   = data.players or {}
    data.protected = data.protected or {}
    return data
end

-- Steam ID when the server has one, username otherwise (non-Steam servers report 0)
local function getPlayerKey(player)
    local ok, id = pcall(function() return player:getSteamID() end)
    local s = ok and id ~= nil and tostring(id) or ""
    if s ~= "" and s ~= "0" and s ~= "nil" then
        return "steam:" .. s
    end
    return "user:" .. tostring(player:getUsername())
end

local function nowString()
    local ok, s = pcall(function() return os.date("%Y-%m-%d %H:%M:%S") end)
    if ok and type(s) == "string" then return s end
    return "ts:" .. tostring(getTimestamp())
end

local function writeLog(text)
    local ok, writer = pcall(getFileWriter, LOG_NAME, true, true)
    if not ok or not writer then
        print("[ServerRules] WARNING: could not open " .. LOG_NAME)
        return
    end
    writer:write(nowString() .. "  " .. text .. "\r\n")
    writer:close()
end

local function describe(player, args)
    local steamText = args and type(args.steamId) == "string" and args.steamId ~= "" and args.steamId or "?"
    return tostring(player:getUsername()) .. " (steam " .. steamText .. ")"
end

---------------------------------------------------------
-- Protection while reading
---------------------------------------------------------
local function protect(player, key, data)
    if not data.protected[key] and (player:isGodMod() or player:isInvisible()) then
        -- Already has admin powers on that we didn't set: leave them alone, and don't
        -- record them as ours, so accepting never switches off an admin's own god mode.
        dbg("protect: " .. key .. " already has god mode/invisible, not touching")
        return
    end
    data.protected[key] = true
    player:setGodMod(true)
    player:setInvisible(true)
    dbg("protect: on for " .. key)
end

local function unprotect(player, key, data)
    if not data.protected[key] then return end
    data.protected[key] = nil
    player:setGodMod(false)
    player:setInvisible(false)
    dbg("protect: off for " .. key)
end

---------------------------------------------------------
-- Commands
---------------------------------------------------------
-- previousVersion: the version this player accepted before, when they're being asked again
-- because the rules changed (nil for a brand new player)
local function sendShow(player, cfg, previousVersion)
    sendServerCommand(player, ServerRules.MODULE, ServerRules.CMD_SHOW, {
        version   = cfg.version,
        previousVersion = previousVersion,
        title     = cfg.title,
        banner    = cfg.banner,
        welcome   = cfg.welcome,
        rules     = cfg.rules,
        timeLimit = cfg.timeLimit,
    })
end

local Commands = {}

Commands[ServerRules.CMD_CHECK] = function(player, args)
    local data = getData()
    local key = getPlayerKey(player)
    local cfg = loadConfig()

    if not cfg or #cfg.rules == 0 then
        unprotect(player, key, data)
        sendServerCommand(player, ServerRules.MODULE, ServerRules.CMD_NONE, {})
        return
    end

    local rec = data.players[key]
    if rec and tonumber(rec.version) == cfg.version then
        unprotect(player, key, data)   -- clears a leftover from a crash mid-read
        dbg("check: " .. key .. " already accepted v" .. cfg.version)
        sendServerCommand(player, ServerRules.MODULE, ServerRules.CMD_ACCEPTED, {})
        return
    end

    if cfg.protect then protect(player, key, data) end
    dbg("check: " .. key .. " must accept v" .. cfg.version)
    sendShow(player, cfg, rec and rec.version or nil)
end

-- Keybind: show the rules again. Already accepted the current version -> a read-only copy (no
-- checkboxes, timer or protection). Not accepted yet -> exactly the same as joining (Check).
Commands[ServerRules.CMD_VIEW] = function(player, args)
    local data = getData()
    local key = getPlayerKey(player)
    local cfg = loadConfig()
    local rec = data.players[key]
    if cfg and #cfg.rules > 0 and rec and tonumber(rec.version) == cfg.version then
        sendServerCommand(player, ServerRules.MODULE, ServerRules.CMD_SHOW, {
            version  = cfg.version,
            title    = cfg.title,
            banner   = cfg.banner,
            welcome  = cfg.welcome,
            rules    = cfg.rules,
            readOnly = true,
        })
        return
    end
    Commands[ServerRules.CMD_CHECK](player, args)
end

Commands[ServerRules.CMD_ACCEPT] = function(player, args)
    local data = getData()
    local key = getPlayerKey(player)
    local cfg = loadConfig()
    if not cfg or #cfg.rules == 0 then
        unprotect(player, key, data)
        sendServerCommand(player, ServerRules.MODULE, ServerRules.CMD_RECORDED, {})
        return
    end

    -- Rules were edited while they were reading: show them the new ones instead
    if tonumber(args and args.version) ~= cfg.version then
        dbg("accept: " .. key .. " accepted old version " .. tostring(args and args.version) .. ", resending")
        local rec = data.players[key]
        sendShow(player, cfg, rec and rec.version or nil)
        return
    end

    data.players[key] = {
        version  = cfg.version,
        username = tostring(player:getUsername()),
        accepted = nowString(),
    }
    unprotect(player, key, data)
    writeLog("ACCEPTED  v" .. cfg.version .. "  " .. describe(player, args) .. "  key=" .. key)
    sendServerCommand(player, ServerRules.MODULE, ServerRules.CMD_RECORDED, {})
end

Commands[ServerRules.CMD_DECLINE] = function(player, args)
    local data = getData()
    local key = getPlayerKey(player)
    unprotect(player, key, data)
    local reason = (args and args.reason == "timeout") and "TIMED OUT" or "DECLINED "
    writeLog(reason .. "      " .. describe(player, args) .. "  key=" .. key)
end

local function onClientCommand(module, command, player, args)
    if module ~= ServerRules.MODULE then return end
    local fn = Commands[command]
    if fn and player then fn(player, args) end
end

Events.OnClientCommand.Add(onClientCommand)
