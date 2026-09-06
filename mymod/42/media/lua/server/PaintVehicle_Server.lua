-- PaintVehicle_Server.lua
-- Server-authoritative handler for spraycan-based vehicle repainting.
-- Must live in lua/server/ so it only loads on the server (and in solo,
-- where the local machine also acts as the server).

------------------------------------------------------------
-- Server-side trust boundary: everything below re-validates
-- what the client already checked, since `args` comes from a
-- ClientCommand and cannot be trusted as-is.
------------------------------------------------------------
local MAX_INTERACT_DISTANCE = 3 -- tiles; generous vs. vanilla vehicle interaction range
local PAINT_COOLDOWN_SECONDS = 3

local function GetDistanceToVehicle(player, vehicle)
    local dx = player:getX() - vehicle:getX()
    local dy = player:getY() - vehicle:getY()
    return math.sqrt(dx * dx + dy * dy)
end

------------------------------------------------------------
-- Ownership gate: require the vehicle's actual key, same rule
-- as the vinyl swap system. A vehicle with no key system
-- (keyId -1) can't be gated this way, so it's allowed through.
------------------------------------------------------------
local function PlayerHasVehicleKey(player, vehicle)
    local keyId = vehicle:getKeyId()
    if not keyId or keyId == -1 then return true end

    local inv = player:getInventory()
    local keyItem = inv:getFirstTypeEvalRecurse("Key", function(item)
        return item:getKeyId() == keyId
    end)
    return keyItem ~= nil
end

------------------------------------------------------------
-- Per-player cooldown to prevent command spam.
------------------------------------------------------------
local lastPaintTime = {}

local function IsOnCooldown(player)
    local id = player:getUsername()
    local now = getTimestamp()
    local last = lastPaintTime[id]
    return last ~= nil and (now - last) < PAINT_COOLDOWN_SECONDS
end

local function MarkPaintTime(player)
    lastPaintTime[player:getUsername()] = getTimestamp()
end

------------------------------------------------------------
-- Same blocklist as PaintVehicle_Context.lua -- a spoofed
-- client command must not be able to repaint vehicles the
-- menu itself would never have offered.
------------------------------------------------------------
local blockedKeywords = {
    "Ambulance","Blacksmith","Burnt","Butchers","Cereal","CraftSupplies",
    "Fire","Florist","Fossoil","_Glass","Genuine_Beer","Gigamart","Greenes",
    "Heralds","Jorgensen","JoyToy","Knox","Landscaping","Laundry","LectroMax",
    "LightsKST","Locksmith","LouisvilleCounty","LouisvillePD","LouisvilleSWAT",
    "Lumber","Mail","Masonry","MassGen","MassGenFac","McCoy","Mccoy",
    "MeltingPoint","News","OvoFarm","Plonkies","Police","Postal","Prison",
    "Radio","Ranger","Scarlet","SouthEasternHosp","SouthEasternPaint",
    "Spiffo","Taxi","Trailer","Transit","Trippy","Uncloggers","Utility",
    "YingsWood","Zippee",
}

local function isBlockedCommercial(name)
    if not name then return false end
    for _, keyword in ipairs(blockedKeywords) do
        if string.find(name, keyword) then
            return true
        end
    end
    return false
end

------------------------------------------------------------
-- Same large-vehicle test as PaintVehicle_Action.lua, used to
-- recompute the spraycan drain server-side instead of trusting
-- whatever drainFraction the client sends (a spoofed 0 would
-- otherwise mean a free, unlimited repaint).
------------------------------------------------------------
local function isLargeVehicle(name)
    if not name then return false end
    return string.find(name, "Van")
        or string.find(name, "Truck")
        or string.find(name, "Pickup")
        or string.find(name, "SUV")
end

------------------------------------------------------------
-- Recognised spraycan item types -- a spoofed spraycanID must
-- resolve to one of these, not an arbitrary item.
------------------------------------------------------------
local SpraycanTypes = {
    ["Base.SpraycanWhite"] = true, ["Base.SpraycanBlack"] = true,
    ["Base.SpraycanGray"] = true, ["Base.SpraycanDarkGray"] = true,
    ["Base.SpraycanRed"] = true, ["Base.SpraycanBlue"] = true,
    ["Base.SpraycanGreen"] = true, ["Base.SpraycanYellow"] = true,
    ["Base.SpraycanOrange"] = true, ["Base.SpraycanPurple"] = true,
    ["Base.SpraycanPastelBlue"] = true, ["Base.SpraycanPastelPink"] = true,
    ["Base.SpraycanPastelGreen"] = true, ["Base.SpraycanPastelYellow"] = true,
    ["Base.SpraycanMauve"] = true, ["Base.SpraycanBrown"] = true,
    ["Base.SpraycanTan"] = true, ["Base.SpraycanOlive"] = true,
    ["Base.SpraycanForestGreen"] = true, ["Base.SpraycanPink"] = true,
    ["Base.SpraycanCyan"] = true,
}

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
    if not player or not args then return end

    if IsOnCooldown(player) then
        print("[PaintVehicle] Rejected: " .. tostring(player:getUsername()) .. " is on cooldown")
        return
    end

    if not args.vehicleID then
        print("[PaintVehicle] Rejected: missing vehicleID")
        return
    end

    local vehicle = getVehicleById(args.vehicleID)
    if not vehicle then
        print("[PaintVehicle] Rejected: vehicle not found for id " .. tostring(args.vehicleID))
        return
    end

    --------------------------------------------------------
    -- Proximity check: player must actually be near the
    -- vehicle they're claiming to repaint.
    --------------------------------------------------------
    if GetDistanceToVehicle(player, vehicle) > MAX_INTERACT_DISTANCE then
        print("[PaintVehicle] Rejected: " .. tostring(player:getUsername()) .. " too far from vehicle " .. tostring(args.vehicleID))
        return
    end

    --------------------------------------------------------
    -- Ownership: must hold this vehicle's key.
    --------------------------------------------------------
    if not PlayerHasVehicleKey(player, vehicle) then
        print("[PaintVehicle] Rejected: " .. tostring(player:getUsername()) .. " does not have the key for vehicle " .. tostring(args.vehicleID))
        return
    end

    --------------------------------------------------------
    -- Blocklist: must not be a commercial/faction vehicle.
    --------------------------------------------------------
    local script = vehicle:getScript()
    local scriptName = script and script:getName() or ""
    if isBlockedCommercial(scriptName) then
        print("[PaintVehicle] Rejected: " .. tostring(scriptName) .. " is a blocked commercial vehicle")
        return
    end

    --------------------------------------------------------
    -- Player must actually have a sanding block, same as the
    -- client's own isValid() check.
    --------------------------------------------------------
    local inv = player:getInventory()
    if not inv:contains("SandingBlock") then
        print("[PaintVehicle] Rejected: " .. tostring(player:getUsername()) .. " missing sanding block")
        return
    end

    --------------------------------------------------------
    -- Resolve + validate the spraycan, if one was used (the
    -- "Random Color" option intentionally sends none).
    --------------------------------------------------------
    local spraycan = nil
    if args.spraycanID then
        spraycan = PV_findItemByID(inv, args.spraycanID)
        if not spraycan or not SpraycanTypes[spraycan:getFullType()] then
            print("[PaintVehicle] Rejected: invalid spraycan from " .. tostring(player:getUsername()))
            return
        end
        if spraycan:getCurrentUses() <= 0 then
            print("[PaintVehicle] Rejected: spraycan already empty")
            return
        end
    end

    --------------------------------------------------------
    -- Validate color values (clamp rather than reject small
    -- out-of-range noise, but refuse non-numeric garbage).
    --------------------------------------------------------
    local h, s, v = args.h, args.s, args.v
    if type(h) ~= "number" or type(s) ~= "number" or type(v) ~= "number" then
        print("[PaintVehicle] Rejected: invalid color values from " .. tostring(player:getUsername()))
        return
    end
    h = math.max(0, math.min(1, h))
    s = math.max(0, math.min(1, s))
    v = math.max(0, math.min(1, v))

    --------------------------------------------------------
    -- All checks passed.
    --------------------------------------------------------
    MarkPaintTime(player)

    vehicle:setColorHSV(h, s, v)
    vehicle:transmitColorHSV()

    if spraycan then
        -- drainFraction is recomputed here rather than trusting
        -- args.drainFraction, so a spoofed command can't paint
        -- for free.
        local maxUses = spraycan:getMaxUses()
        local before = spraycan:getCurrentUses()
        local drainFraction = isLargeVehicle(scriptName) and 1.0 or 0.5
        local drainUses = math.floor(maxUses * drainFraction + 0.001)
        local after = math.max(0, before - drainUses)
        spraycan:setCurrentUses(after)

        print("[PaintVehicle] Spraycan drained:", before, "/", maxUses, "->", after)

        if after <= 0 then
            -- spraycan may have been found inside a nested container
            -- (e.g. a backpack) via the recursive ID lookup above, so
            -- remove it from its actual container, not assume it's
            -- top-level -- same lesson as the CarKeyCraft blank-key bug.
            local container = spraycan:getContainer() or inv
            container:Remove(spraycan)
            sendRemoveItemFromContainer(container, spraycan)
        else
            spraycan:syncItemFields()
        end
    end
end

Events.OnClientCommand.Add(OnClientCommand_PaintVehicle)
