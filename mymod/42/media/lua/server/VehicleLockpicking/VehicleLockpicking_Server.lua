-- server/VehicleLockpicking/VehicleLockpicking_Server.lua
-- Server-authoritative handler for VehicleLockpicking.
--
-- The client-only version of this mod called door:setLocked(false)
-- directly and never told the server -- that mutation only exists on
-- the acting client's own local copy. The server's real vehicle-part
-- lock state (which is what actually gates trunk/container access)
-- never changed, which is why the trunk looked unlocked to the picker
-- but stayed genuinely inaccessible until a properly-synced vanilla
-- action (the driver's-seat lock toggle) touched it. The fallback
-- command the old code sent on failure (module "vehicle", command
-- "setDoorLocked") also isn't a real vanilla server command -- grepped
-- the entire vanilla server lua tree, no such handler exists anywhere.
--
-- vehicle:transmitPartDoor(part) is the real, confirmed sync call --
-- vanilla's own ISLockDoors.lua (shared/Vehicles/TimedActions/) uses
-- it after every part:getDoor():setLocked() change.

local DEBUG = true
local function dbg(msg) if DEBUG then print("[VehicleLockpicking:Server] " .. tostring(msg)) end end

local function getLockpickSuccessChance(player)
    local mech = player:getPerkLevel(Perks.Mechanics)

    if mech <= 2 then
        return 15
    elseif mech <= 4 then
        return 45
    elseif mech <= 8 then
        return 75
    else
        return 100
    end
end

local function hasTools(player)
    local inv = player:getInventory()

    local tool = inv:getFirstTypeRecurse("Screwdriver")
        or inv:getFirstTypeRecurse("Base.Multitool")
        or inv:getFirstTypeRecurse("Base.SurvivorMultitool")
    local paperclip = inv:getFirstTypeRecurse("Paperclip")

    return tool ~= nil and paperclip ~= nil
end

local function OnClientCommand(module, command, player, args)
    if module ~= "VehicleLockpicking" or command ~= "attemptUnlock" then return end

    if not player or not args or not args.vehicleId or not args.partId then
        dbg("Malformed attemptUnlock request, ignoring")
        return
    end

    -- Re-derive vehicle and part from IDs server-side -- never trust a
    -- client-sent object reference. Same pattern this pack's other
    -- server-authoritative mods already use (CarPartRepair, etc.).
    local vehicle = getVehicleById(args.vehicleId)
    if not vehicle then
        dbg("Vehicle not found for id " .. tostring(args.vehicleId))
        return
    end

    local part = vehicle:getPartById(args.partId)
    if not part or not part:getDoor() then
        dbg("Part/door not found: " .. tostring(args.partId))
        return
    end

    local playerSquare = player:getSquare()
    local vehicleSquare = vehicle:getSquare()
    if not playerSquare or not vehicleSquare or playerSquare:DistToProper(vehicleSquare) > 2 then
        dbg("Player too far from vehicle, rejecting")
        return
    end

    if not hasTools(player) then
        dbg("REJECT: missing tools server-side for " .. tostring(player:getUsername()))
        return
    end

    if not part:getDoor():isLocked() then
        dbg("Door already unlocked, nothing to do")
        sendServerCommand(player, "VehicleLockpicking", "lockpickResult", { success = true })
        return
    end

    -- Roll server-side -- trusting a client-reported result would let a
    -- modified client always report success.
    local chance = getLockpickSuccessChance(player)
    local roll = ZombRand(100)

    if roll < chance then
        part:getDoor():setLocked(false)
        vehicle:transmitPartDoor(part)

        -- Picking any door also opens the trunk, same as the original
        -- mod's intent -- just properly synced now.
        if args.partId ~= "TrunkDoor" then
            local trunk = vehicle:getPartById("TrunkDoor")
            if trunk and trunk:getDoor() and trunk:getDoor():isLocked() then
                trunk:getDoor():setLocked(false)
                vehicle:transmitPartDoor(trunk)
            end
        end

        dbg("Unlock succeeded for " .. tostring(player:getUsername()))
        sendServerCommand(player, "VehicleLockpicking", "lockpickResult", { success = true })
    else
        dbg("Unlock failed for " .. tostring(player:getUsername()))

        local broke = ZombRand(100) < 35
        if broke then
            local inv = player:getInventory()
            local pc = inv:getFirstTypeRecurse("Paperclip")
            if pc then
                local container = pc:getContainer() or inv
                container:Remove(pc)
                sendRemoveItemFromContainer(container, pc)
            end
        end

        sendServerCommand(player, "VehicleLockpicking", "lockpickResult", { success = false, broke = broke })
    end
end

Events.OnClientCommand.Add(OnClientCommand)
