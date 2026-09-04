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

    -- Scan for the barrel by sprite rather than trusting a client-supplied
    -- object-list index: that list's order isn't guaranteed to match between
    -- client and server at the moment the command arrives. This mirrors how
    -- the client's own context menu already picks a target barrel.
    local objects = square:getObjects()
    if not objects then
        OBSLog("findBarrel: square has no objects")
        return nil
    end

    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and OrangeBarrelFluid.IsOrangeBarrel(obj) then
            return obj, square
        end
    end

    OBSLog("findBarrel: no orange barrel found on square")
    return nil
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
