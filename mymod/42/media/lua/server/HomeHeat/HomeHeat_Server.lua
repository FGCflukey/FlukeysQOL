-- HomeHeat_Server.lua
-- Server-authoritative state for placed HomeHeat radiators. The
-- client only ever requests a change; this is the only place that
-- actually writes it, after re-validating everything itself.

-- TEMP DEBUG: safe to remove once preset-switching is confirmed working.
local DEBUG = true
local function dbg(msg)
    if DEBUG then print("[HomeHeat:Server] " .. tostring(msg)) end
end

local function findRadiatorAt(x, y, z)
    local square = getCell():getGridSquare(x, y, z)
    if not square then return nil, nil end

    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if HomeHeat_Util.isRadiator(obj) then
            return obj, square
        end
    end
    return nil, square
end

-----------------------------------------------------
-- Initialise modData the first time a radiator is placed
-- or loaded (fires for both -- see BlowtorchGateRemoval /
-- other world-object mods in this pack for the same pattern).
-----------------------------------------------------
local function OnObjectAdded(isoObject)
    if not HomeHeat_Util.isRadiator(isoObject) then return end

    local modData = isoObject:getModData()
    if modData.presetKey == nil then
        modData.on = false
        modData.presetKey = HomeHeat_Util.DEFAULT_PRESET
        isoObject:transmitModData()
    end
end
Events.OnObjectAdded.Add(OnObjectAdded)

-----------------------------------------------------
-- CLIENT COMMAND HANDLER
-----------------------------------------------------
local function OnClientCommand(module, command, player, args)
    if module ~= "HomeHeat" then return end
    if command ~= "setState" then return end

    dbg("setState received: args=" .. tostring(args) ..
        " x=" .. tostring(args and args.x) ..
        " y=" .. tostring(args and args.y) ..
        " z=" .. tostring(args and args.z) ..
        " on=" .. tostring(args and args.on) ..
        " presetKey=" .. tostring(args and args.presetKey))

    if not player or not args or not args.x or not args.y or not args.z then
        dbg("  rejected: missing player/args")
        return
    end

    local isoObject, square = findRadiatorAt(args.x, args.y, args.z)
    if not isoObject then
        dbg("  rejected: no radiator found at those coords (square=" .. tostring(square) .. ")")
        sendServerCommand(player, "HomeHeat", "stateResult", { success = false, reason = "missing" })
        return
    end

    local on = args.on == true
    local preset = HomeHeat_Util.presetByKey(args.presetKey) or HomeHeat_Util.presetByKey(HomeHeat_Util.DEFAULT_PRESET)
    dbg("  found radiator, on=" .. tostring(on) .. " preset=" .. tostring(preset and preset.key))

    if on and not HomeHeat_Util.hasPower(square) then
        dbg("  rejected: no power")
        sendServerCommand(player, "HomeHeat", "stateResult", { success = false, reason = "power" })
        return
    end

    if on and square:isOutside() then
        dbg("  rejected: outside")
        sendServerCommand(player, "HomeHeat", "stateResult", { success = false, reason = "outside" })
        return
    end

    local modData = isoObject:getModData()
    modData.on = on
    modData.presetKey = preset.key
    isoObject:transmitModData()

    dbg("  applied: on=" .. tostring(modData.on) .. " presetKey=" .. tostring(modData.presetKey) ..
        " -- transmitted")

    sendServerCommand(player, "HomeHeat", "stateResult", { success = true })
end
Events.OnClientCommand.Add(OnClientCommand)
