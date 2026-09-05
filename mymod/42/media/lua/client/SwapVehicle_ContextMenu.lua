------------------------------------------------------------
-- SwapVehicle Context Menu (Vehicle‑only, no cell scan)
------------------------------------------------------------

local DEBUG = false

local function dbg(msg)
    if DEBUG then
        print("[SwapVehicle DEBUG] " .. tostring(msg))
    end
end

------------------------------------------------------------
-- Shared realism helpers (same as paint system)
------------------------------------------------------------

local function PV_debugClimate()
    if not DEBUG then return end
    local climate = getClimateManager()
    print("---- Climate Debug ----")
    print("Rain:\t" .. tostring(climate:getRainIntensity()))
    print("Snow:\t" .. tostring(climate:getSnowIntensity()))
    print("Fog:\t" .. tostring(climate:getFogIntensity()))
    print("Storm:\t" .. tostring(climate:getThunderStorm()))
    print("NightStrength:\t" .. tostring(climate:getNightStrength()))
    print("------------------------")
end

local function PV_isBadWeather()
    local climate = getClimateManager()
    if climate:getRainIntensity() > 0 then return true end
    if climate:getSnowIntensity() > 0 then return true end
    if climate:getFogIntensity() > 0 then return true end
    local storm = climate:getThunderStorm()
    if storm and storm.active then return true end
    return false
end

local function PV_hasEnoughLight(character)
    local square = character:getSquare()
    if not square then return false end
    local playerIndex = character:getPlayerNum()
    if not square:isOutside() then
        return square:getLightLevel(playerIndex) > 0.3
    end
    local climate = getClimateManager()
    local isNight = climate:getNightStrength() > 0.5
    if not isNight then return true end
    return square:getLightLevel(playerIndex) > 0.6
end

local function PV_needsCleaning(vehicle)
    if not vehicle or not vehicle.getBloodIntensity then
        return false
    end

    if vehicle:getBloodIntensity("Front") > 0 then return true end
    if vehicle:getBloodIntensity("Rear") > 0 then return true end
    if vehicle:getBloodIntensity("Left") > 0 then return true end
    if vehicle:getBloodIntensity("Right") > 0 then return true end

    return false
end

------------------------------------------------------------
-- Ownership gate: require the vehicle's actual key so
-- randoms can't walk a parking lot re-skinning cars that
-- aren't theirs. A vehicle with no key system (keyId -1)
-- can't be gated this way, so it's allowed through.
------------------------------------------------------------
local function PV_hasVehicleKey(player, vehicle)
    local keyId = vehicle:getKeyId()
    if not keyId or keyId == -1 then return true end

    local inv = player:getInventory()
    local keyItem = inv:getFirstTypeEvalRecurse("Key", function(item)
        return item:getKeyId() == keyId
    end)
    return keyItem ~= nil
end

------------------------------------------------------------
-- Registry check
------------------------------------------------------------

if not SwapVehicleRegistry then
    print("ERROR: SwapVehicleRegistry missing! (Vanilla/KI5 registry not loaded)")
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

    PV_debugClimate()

    --------------------------------------------------------
    -- Evaluate every requirement up front so the option can
    -- always be shown, greyed out with a tooltip explaining
    -- what's missing, instead of blocking with a chat message
    -- on every right-click.
    --------------------------------------------------------
    local inv = player:getInventory()

    local hasKey     = PV_hasVehicleKey(player, vehicle)
    local weatherOk  = not PV_isBadWeather()
    local lightOk    = PV_hasEnoughLight(player)
    local cleanOk    = not PV_needsCleaning(vehicle)
    local hasSanding = inv:contains("SandingBlock")
    local hasSpray   = inv:contains("SpraycanVinylCoat")

    local allOk = hasKey and weatherOk and lightOk and cleanOk and hasSanding and hasSpray

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
            print("ERROR: SwapVehicle_UI.Open missing!")
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
    tip.description = tip.description .. reqLine(hasSanding, "Sanding Block")
    tip.description = tip.description .. reqLine(hasSpray, "Vinyl Spray Paint")

    option.toolTip = tip
end

Events.OnFillWorldObjectContextMenu.Add(SV_AddContextMenu)
