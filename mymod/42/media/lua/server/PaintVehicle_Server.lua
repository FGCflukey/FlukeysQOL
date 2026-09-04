-- PaintVehicle_Server.lua
-- Server-authoritative handler for spraycan-based vehicle repainting.
-- Must live in lua/server/ so it only loads on the server (and in solo,
-- where the local machine also acts as the server).

local function PV_findItemByID(inv, id)
    if not inv or not id then return nil end

    if inv.getItemById then
        local ok, item = pcall(function() return inv:getItemById(id) end)
        if ok and item then return item end
    end

    if inv.getItemWithIDRecursiv then
        local ok, item = pcall(function() return inv:getItemWithIDRecursiv(id) end)
        if ok and item then return item end
    end

    if inv.getItemWithID then
        local ok, item = pcall(function() return inv:getItemWithID(id) end)
        if ok and item then return item end
    end

    return nil
end

local function OnClientCommand_PaintVehicle(module, command, player, args)
    if module ~= "PaintVehicle" then return end
    if command ~= "paint" then return end
    if not args then return end

    -----------------------------------------------------
    -- VEHICLE COLOR
    -----------------------------------------------------
    if args.vehicleID and args.h and args.s and args.v then
        local vehicle = getVehicleById(args.vehicleID)
        if vehicle then
            vehicle:setColorHSV(args.h, args.s, args.v)
            vehicle:transmitColorHSV()
        else
            print("[PaintVehicle] Server could not find vehicle ID:", args.vehicleID)
        end
    end

    -----------------------------------------------------
    -- SPRAYCAN DRAIN
    -----------------------------------------------------
    -- NOTE: spraycans must be ItemType = Normal with MaxUses set in their
    -- item script (not the old ItemType = Drainable / UseDelta format).
    if args.spraycanID and args.drainFraction then
        local inv = player and player:getInventory()
        local spraycan = PV_findItemByID(inv, args.spraycanID)

        if spraycan then
            local maxUses = spraycan:getMaxUses()
            local before   = spraycan:getCurrentUses()
            local drainUses = math.floor(maxUses * args.drainFraction + 0.001)
            local after = before - drainUses
            if after < 0 then after = 0 end
            spraycan:setCurrentUses(after)

            print("[PaintVehicle] Spraycan drained:", before, "/", maxUses, "->", after)

            if after <= 0 then
                inv:Remove(spraycan)
            end
        else
            print("[PaintVehicle] Server could not find spraycan ID:", args.spraycanID)
        end
    end
end

Events.OnClientCommand.Add(OnClientCommand_PaintVehicle)