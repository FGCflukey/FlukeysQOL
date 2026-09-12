-- Automaker_Server.lua
-- Server-authoritative vehicle spawning for Automaker.
--
-- Re-validates skill levels and recipe knowledge here (both are plain
-- character state, safe and cheap to check server-side). The
-- material-on-ground check is NOT duplicated here -- it depends on
-- buildUtil.getMaterialOnGround/consumeMaterial, the same vanilla
-- module the wall/furniture build menu uses, and that module's
-- server-side safety isn't confirmed the way the rest of this file's
-- calls are. The client already gates its own Build button on the
-- full check (materials included) before ever sending this command,
-- and the material consumption itself happens client-side in response
-- to TakeMaterials below -- the exact same round-trip the original
-- mod used. This mirrors the original's trust model (a private mod
-- for a small friend group, not hardened against a modified client)
-- rather than guessing at an untested "more secure" alternative.

if isClient() then return end

local Commands = {}

Commands.CreateVehicle = function(player, args)
    local mechanictype = tonumber(args.MechanicType) or 0

    local mechanicReq, metalworkReq, electricalReq = Automaker_Util.getSkillReq(player, mechanictype)
    if player:getPerkLevel(Perks.Mechanics) < mechanicReq
        or player:getPerkLevel(Perks.MetalWelding) < metalworkReq
        or player:getPerkLevel(Perks.Electricity) < electricalReq then
        print("[Automaker] Rejected build for " .. tostring(player:getUsername()) .. ": insufficient skill")
        return
    end

    if not player:getKnownRecipes():contains(Automaker_Util.recipeForType(mechanictype)) then
        print("[Automaker] Rejected build for " .. tostring(player:getUsername()) .. ": missing recipe knowledge")
        return
    end

    local vehicle = addVehicleDebug(tostring(args.VehicleID), IsoDirections.E, nil, player:getSquare())
    if not vehicle then
        print("[Automaker] Error: no vehicle spawned for " .. tostring(player:getUsername()) .. " (" .. tostring(args.VehicleID) .. ")")
        return
    end

    vehicle:putKeyInIgnition(vehicle:createVehicleKey())

    if SandboxVars.Automaker.fullbuild then
        vehicle:repair()

        local gastank = vehicle:getPartById("GasTank")
        if gastank then
            gastank:setContainerContentAmount(0.0)
        end

        local frontDoor = vehicle:getPartById("DoorFrontLeft")
        if frontDoor and frontDoor:getDoor() then
            frontDoor:getDoor():setLocked(false)
            frontDoor:getDoor():setLockBroken(false)
        end
    else
        local i = 0
        local part = vehicle:getPartByIndex(i)
        while part ~= nil do
            part:setInventoryItem(nil)
            i = i + 1
            part = vehicle:getPartByIndex(i)
        end
    end

    vehicle:setEngineFeature(
        PZMath.clamp(player:getPerkLevel(Perks.Mechanics) * 10 + (ZombRand(30) - 15), 50, 100),
        vehicle:getEngineLoudness(),
        vehicle:getEnginePower()
    )

    print("[Automaker] " .. tostring(player:getUsername()) .. " built " .. tostring(args.VehicleID))

    sendServerCommand(player, "Automaker", "TakeMaterials", { MechanicType = mechanictype })
end

local function OnClientCommand(module, command, player, args)
    if module ~= "Automaker" then return end
    if Commands[command] then
        Commands[command](player, args or {})
    end
end

Events.OnClientCommand.Add(OnClientCommand)
