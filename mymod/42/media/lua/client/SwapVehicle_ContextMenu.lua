------------------------------------------------------------
-- SwapVehicle Context Menu (Vehicle‑only, no cell scan)
------------------------------------------------------------

local DEBUG = false

local function dbg(msg)
    if DEBUG then
        print("[SwapVehicle DEBUG] " .. tostring(msg))
    end
end

require "PaintVehicle_Shared"   -- shared weather/light/blood/key checks

-- Animals in a livestock/horse trailer can't be carried over by a swap
local function SV_hasAnimals(vehicle)
    if not vehicle.getAnimals then return false end
    local ok, animals = pcall(function() return vehicle:getAnimals() end)
    return ok and animals ~= nil and animals:size() > 0
end

------------------------------------------------------------
-- Registry check
------------------------------------------------------------

if not SwapVehicleRegistry then
    print("[SwapVehicle] ERROR: SwapVehicleRegistry missing! (Vanilla/KI5 registry not loaded)")
    return
end

------------------------------------------------------------
-- Vehicle detection (MATCHES PAINT SYSTEM)
------------------------------------------------------------
local function SV_FindVehicle(player)
    local vehicle = ISVehicleMenu.getVehicleToInteractWith(player)
    dbg("ISVehicleMenu returned: " .. tostring(vehicle))
    return vehicle
end

------------------------------------------------------------
-- Add context menu option
------------------------------------------------------------
local function SV_AddContextMenu(playerIndex, context, worldobjects, test)
    dbg("SV_AddContextMenu triggered")

    local player = getSpecificPlayer(playerIndex)
    if not player then
        dbg("Player not found")
        return
    end

    --------------------------------------------------------
    -- Vehicle detection FIRST — unrelated right-clicks (no
    -- vehicle nearby) must not trigger vinyl-specific gating
    -- or chat messages.
    --------------------------------------------------------
    local vehicle = SV_FindVehicle(player)

    if not vehicle or not instanceof(vehicle, "BaseVehicle") then
        dbg("No valid vehicle found, aborting context menu")
        return
    end

    dbg("Vehicle detected: " .. tostring(vehicle))

    --------------------------------------------------------
    -- Registry lookup FIRST — vehicles that simply aren't
    -- part of any swap group should never show this option
    -- at all, regardless of weather/key/materials.
    --------------------------------------------------------
    local scriptObj = vehicle:getScript()
    if not scriptObj then
        dbg("Vehicle scriptObj nil")
        return
    end

    local script = scriptObj:getFullName()
    dbg("Vehicle script: " .. script)

    local group = SwapVehicleRegistry.Groups[script]
    if not group then
        dbg("No group found for script")
        return
    end

    local variants = SwapVehicleRegistry.SwapPairs[group]
    if not variants or #variants < 2 then
        dbg("No swap variants found")
        return
    end

    if test then
        dbg("Test mode active")
        return true
    end

    --------------------------------------------------------
    -- Evaluate every requirement up front so the option can
    -- always be shown, greyed out with a tooltip explaining
    -- what's missing, instead of blocking with a chat message
    -- on every right-click.
    --------------------------------------------------------
    local inv = player:getInventory()

    local hasKey     = PaintVehicle.hasVehicleKey(player, vehicle)
    local weatherOk  = not PaintVehicle.isBadWeather()
    local lightOk    = PaintVehicle.hasEnoughLight(player)
    local cleanOk    = not PaintVehicle.isBloody(vehicle)
    local noAnimals  = not SV_hasAnimals(vehicle)
    local hasSanding = inv:containsTypeRecurse("Base.SandingBlock")         -- bags count too
    local hasSpray   = inv:containsTypeRecurse("Base.SpraycanVinylCoat")

    local allOk = hasKey and weatherOk and lightOk and cleanOk and noAnimals and hasSanding and hasSpray

    --------------------------------------------------------
    -- Add context menu option (always shown; disabled + a
    -- tooltip when a requirement isn't met, mirroring the
    -- vanilla "Dismantle Vehicle Chassis" requirements list).
    --------------------------------------------------------
    dbg("Adding context menu option for vehicle swap, allOk=" .. tostring(allOk))

    local option = context:addOption("Swap Vehicle Vinyl", vehicle, function(v)
        dbg("Callback triggered for vehicle: " .. tostring(v))

        if not allOk then
            dbg("Callback fired while requirements unmet, ignoring")
            return
        end

        if not v or not instanceof(v, "BaseVehicle") then
            dbg("Callback received non‑vehicle, aborting")
            return
        end

        local worldVehicle = getVehicleById(v:getId())
        if not worldVehicle then
            dbg("getVehicleById failed")
            return
        end

        if SwapVehicle_UI and SwapVehicle_UI.Open then
            dbg("Opening SwapVehicle_UI for group " .. tostring(group))
            SwapVehicle_UI.Open(player, worldVehicle, group, variants)
        else
            print("[SwapVehicle] ERROR: SwapVehicle_UI.Open missing!")
        end
    end)

    if allOk then
        option.notAvailable = false
        return
    end

    option.notAvailable = true

    local function reqLine(ok, text)
        local rgb = ok and " <RGB:1,1,1>" or " <RGB:1,0,0>"
        return rgb .. text .. " <LINE>"
    end

    local tip = ISToolTip:new()
    tip:initialise()
    tip:setVisible(true)

    tip.description = "Requirements:" .. " <LINE>"
    if vehicle:getKeyId() and vehicle:getKeyId() ~= -1 then
        tip.description = tip.description .. reqLine(hasKey, "Vehicle key")
    end
    tip.description = tip.description .. reqLine(weatherOk, "Clear weather")
    tip.description = tip.description .. reqLine(lightOk, "Enough light")
    tip.description = tip.description .. reqLine(cleanOk, "Vehicle is clean")
    if not noAnimals then
        tip.description = tip.description .. reqLine(false, "No animals inside")
    end
    tip.description = tip.description .. reqLine(hasSanding, "Sanding Block")
    tip.description = tip.description .. reqLine(hasSpray, "Vinyl Spray Paint")

    option.toolTip = tip
end

Events.OnFillWorldObjectContextMenu.Add(SV_AddContextMenu)
