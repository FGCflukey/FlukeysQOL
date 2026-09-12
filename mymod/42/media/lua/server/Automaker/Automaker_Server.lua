-- Automaker_Server.lua
-- Server-authoritative vehicle spawning for Automaker.
--
-- Re-validates skill levels and recipe knowledge here (both are plain
-- character state, safe and cheap to check server-side). Material
-- consumption also happens directly here via buildUtil.consumeMaterial
-- -- its real source (read in full) branches on isServer() and is
-- designed to be called this way, so there's no need for the
-- client-round-trip the original B41 mod used.

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

    -- Everything below is native vehicle setup -- wrapped in pcall so a
    -- signature mismatch in any ONE of these calls can't also silently
    -- skip material consumption at the end, leaving the vehicle built
    -- but materials never taken. The vehicle spawn itself already
    -- happened above regardless of what happens in here.
    --
    -- vehicle:putKeyInIgnition(key, ???) is deliberately NOT called --
    -- B42 requires a 2nd argument and two different guesses at its type
    -- (ItemContainer, then int) both threw. The key still goes straight
    -- into the player's inventory, which is confirmed working; it's
    -- just not pre-inserted into the ignition, a minor convenience loss
    -- not worth a third blind guess at an undocumented native signature.
    local ok, err = pcall(function()
        local key = vehicle:createVehicleKey()
        player:getInventory():AddItem(key)
        sendAddItemToContainer(player:getInventory(), key)

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
    end)

    if not ok then
        print("[Automaker] WARNING: post-spawn setup failed for " .. tostring(player:getUsername()) .. ": " .. tostring(err))
    end

    print("[Automaker] " .. tostring(player:getUsername()) .. " built " .. tostring(args.VehicleID))

    Automaker_Util.takeMaterials(player, mechanictype)
end

local function OnClientCommand(module, command, player, args)
    if module ~= "Automaker" then return end
    if Commands[command] then
        Commands[command](player, args or {})
    end
end

Events.OnClientCommand.Add(OnClientCommand)
