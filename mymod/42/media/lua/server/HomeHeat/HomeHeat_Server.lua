-- HomeHeat_Server.lua
-- Server-authoritative state for placed HomeHeat radiators. The
-- client only ever requests a change; this is the only place that
-- actually writes it, after re-validating everything itself.

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
    if not player or not args or not args.x or not args.y or not args.z then return end

    local isoObject, square = findRadiatorAt(args.x, args.y, args.z)
    if not isoObject then
        sendServerCommand(player, "HomeHeat", "stateResult", { success = false, reason = "missing" })
        return
    end

    local on = args.on == true
    local preset = HomeHeat_Util.presetByKey(args.presetKey) or HomeHeat_Util.presetByKey(HomeHeat_Util.DEFAULT_PRESET)

    if on and not HomeHeat_Util.hasPower(square) then
        sendServerCommand(player, "HomeHeat", "stateResult", { success = false, reason = "power" })
        return
    end

    if on and square:isOutside() then
        sendServerCommand(player, "HomeHeat", "stateResult", { success = false, reason = "outside" })
        return
    end

    local modData = isoObject:getModData()
    modData.on = on
    modData.presetKey = preset.key
    isoObject:transmitModData()

    sendServerCommand(player, "HomeHeat", "stateResult", { success = true })
end
Events.OnClientCommand.Add(OnClientCommand)
