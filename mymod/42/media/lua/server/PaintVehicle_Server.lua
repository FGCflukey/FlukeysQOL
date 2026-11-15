-- PaintVehicle_Server.lua
-- Server-authoritative handler for spraycan-based vehicle repainting.
-- Must live in lua/server/ so it only loads on the server (and in solo,
-- where the local machine also acts as the server).

require "PaintVehicle_Shared"

local DEBUG = false
local function dbg(msg) if DEBUG then print("[PaintVehicle:Server] " .. tostring(msg)) end end

------------------------------------------------------------
-- Server-side trust boundary: everything below re-validates what the client already
-- checked, since `args` comes from a ClientCommand and cannot be trusted as-is.
-- The color is never taken from the client: it comes from the spraycan item itself.
------------------------------------------------------------
local MAX_INTERACT_DISTANCE = 3 -- tiles; generous vs. vanilla vehicle interaction range
local PAINT_COOLDOWN_SECONDS = 3

local function getDistanceToVehicle(player, vehicle)
    local dx = player:getX() - vehicle:getX()
    local dy = player:getY() - vehicle:getY()
    return math.sqrt(dx * dx + dy * dy)
end

------------------------------------------------------------
-- Per-player cooldown to prevent command spam.
------------------------------------------------------------
local lastPaintTime = {}

local function isOnCooldown(player)
    local last = lastPaintTime[player:getUsername()]
    return last ~= nil and (getTimestamp() - last) < PAINT_COOLDOWN_SECONDS
end

local function markPaintTime(player)
    lastPaintTime[player:getUsername()] = getTimestamp()
end

local function findItemByID(inv, id)
    if not inv or not id then return nil end
    for _, fn in ipairs({ "getItemById", "getItemWithIDRecursiv", "getItemWithID" }) do
        if inv[fn] then
            local ok, item = pcall(function() return inv[fn](inv, id) end)
            if ok and item then return item end
        end
    end
    return nil
end

local function OnClientCommand_PaintVehicle(module, command, player, args)
    if module ~= "PaintVehicle" then return end
    if command ~= "paint" then return end
    if not player or not args then return end
    local who = tostring(player:getUsername())

    if isOnCooldown(player) then
        dbg("rejected: " .. who .. " is on cooldown")
        return
    end

    local vehicle = args.vehicleID and getVehicleById(args.vehicleID)
    if not vehicle then
        dbg("rejected: vehicle not found for id " .. tostring(args.vehicleID))
        return
    end

    -- Player must actually be near the vehicle they're claiming to repaint
    if getDistanceToVehicle(player, vehicle) > MAX_INTERACT_DISTANCE then
        dbg("rejected: " .. who .. " too far from vehicle " .. tostring(args.vehicleID))
        return
    end

    -- Ownership: must hold this vehicle's key
    if not PaintVehicle.hasVehicleKey(player, vehicle) then
        dbg("rejected: " .. who .. " does not have the key for vehicle " .. tostring(args.vehicleID))
        return
    end

    -- A spoofed command must not repaint vehicles the menu itself would never offer
    local blocked, scriptName = PaintVehicle.isBlockedCommercial(vehicle)
    if blocked then
        dbg("rejected: " .. tostring(scriptName) .. " is a blocked commercial vehicle")
        return
    end

    local inv = player:getInventory()
    if not inv:containsTypeRecurse(PaintVehicle.SANDING_BLOCK) then
        dbg("rejected: " .. who .. " missing sanding block")
        return
    end

    -- A real spraycan of a known color is required, and decides the color
    local spraycan = findItemByID(inv, args.spraycanID)
    local colorName = spraycan and PaintVehicle.BY_ITEM[spraycan:getFullType()]
    if not colorName then
        dbg("rejected: missing/invalid spraycan from " .. who)
        return
    end
    local hsv = PaintVehicle.COLORS[colorName].hsv

    markPaintTime(player)

    vehicle:setColorHSV(hsv[1], hsv[2], hsv[3])
    vehicle:transmitColorHSV()

    -- One can per repaint, regardless of vehicle size (same rule as the vinyl swap system).
    -- Remove it from its actual container, not assume it's top-level -- same lesson as
    -- the CarKeyCraft blank-key bug.
    local container = spraycan:getContainer() or inv
    container:Remove(spraycan)
    sendRemoveItemFromContainer(container, spraycan)

    dbg(who .. " painted vehicle " .. tostring(args.vehicleID) .. " " .. colorName)
end

Events.OnClientCommand.Add(OnClientCommand_PaintVehicle)
