if isClient() then return end

require "OrangeBarrelFluid_Shared"

local function OBSLog(...)
    if not OrangeBarrelFluid.DEBUG then return end
    print("[OrangeBarrelFluid-Server]", ...)
end

local function findBarrel(args)
    local square = getCell():getGridSquare(args.x, args.y, args.z)
    if not square then
        OBSLog("findBarrel: no square at", tostring(args.x), tostring(args.y), tostring(args.z))
        return nil
    end

    local objects = square:getObjects()
    if not objects or args.index == nil or args.index < 0 or args.index >= objects:size() then
        OBSLog("findBarrel: invalid index", tostring(args.index))
        return nil
    end

    local obj = objects:get(args.index)
    if not obj or not OrangeBarrelFluid.IsOrangeBarrel(obj) then
        OBSLog("findBarrel: object at index is not an orange barrel")
        return nil
    end

    return obj, square
end

local function isPlayerAdjacent(player, square)
    local plSquare = player and player:getSquare()
    if not plSquare or not square then return false end
    return plSquare == square or plSquare:isAdjacentTo(square)
end

local Commands = {}

function Commands.convert(player, args)
    local barrel, square = findBarrel(args)
    if not barrel then
        OBSLog("convert rejected: barrel not found for", tostring(player:getUsername()))
        return
    end

    if not isPlayerAdjacent(player, square) then
        OBSLog("convert rejected: player not adjacent,", tostring(player:getUsername()))
        return
    end

    if not OrangeBarrelFluid.getPlayerWrench(player) then
        OBSLog("convert rejected: no pipe wrench,", tostring(player:getUsername()))
        return
    end

    if OrangeBarrelFluid.HasFluidComponent(barrel) then
        OBSLog("convert rejected: barrel already converted")
        return
    end

    OrangeBarrelFluid.AddFluidComponent(barrel)
    OBSLog("convert applied for", tostring(player:getUsername()))
end

function Commands.reset(player, args)
    local barrel, square = findBarrel(args)
    if not barrel then
        OBSLog("reset rejected: barrel not found for", tostring(player:getUsername()))
        return
    end

    if not isPlayerAdjacent(player, square) then
        OBSLog("reset rejected: player not adjacent,", tostring(player:getUsername()))
        return
    end

    if not OrangeBarrelFluid.getPlayerWrench(player) then
        OBSLog("reset rejected: no pipe wrench,", tostring(player:getUsername()))
        return
    end

    if not OrangeBarrelFluid.HasFluidComponent(barrel) then
        OBSLog("reset rejected: barrel is not converted")
        return
    end

    OrangeBarrelFluid.RemoveFluidComponent(barrel)
    OBSLog("reset applied for", tostring(player:getUsername()))
end

local function OnClientCommand(module, command, player, args)
    if module ~= "OrangeBarrelFluid" then return end
    if Commands[command] then
        Commands[command](player, args or {})
    end
end

Events.OnClientCommand.Add(OnClientCommand)
