------------------------------------------------------------
-- SwapVehicle Context Menu (Vehicle‑only, no cell scan)
------------------------------------------------------------

local DEBUG = false  -- set to false to silence debug output

local function dbg(msg)
    if DEBUG then
        print("[SwapVehicle DEBUG] " .. tostring(msg))
    end
end

if not SwapVehicleRegistry then
    print("ERROR: SwapVehicleRegistry missing! (Vanilla/KI5 registry not loaded)")
    return
end

------------------------------------------------------------
-- Add context menu option (no nearest‑vehicle scan)
------------------------------------------------------------
local function SV_AddContextMenu(playerIndex, context, worldobjects, test)
    dbg("SV_AddContextMenu triggered")

    local player = getSpecificPlayer(playerIndex)
    if not player then
        dbg("Player not found")
        return
    end

    local vehicle = nil

    --------------------------------------------------------
    -- 1) Try official helper (vehicle under cursor)
    --------------------------------------------------------
    if ISWorldObjectContextMenu.getVehicle then
        vehicle = ISWorldObjectContextMenu.getVehicle(worldobjects)
        dbg("Helper vehicle: " .. tostring(vehicle))
    end

    --------------------------------------------------------
    -- 2) If that failed, try player:getVehicle() (inside car)
    --------------------------------------------------------
    if not vehicle then
        dbg("Trying player:getVehicle()")
        vehicle = player:getVehicle()
    end

    --------------------------------------------------------
    -- HARD GUARD: bail if not a valid BaseVehicle
    --------------------------------------------------------
    if not vehicle or not instanceof(vehicle, "BaseVehicle") then
        dbg("No valid vehicle found, aborting context menu")
        return
    end

    --------------------------------------------------------
    -- Registry lookup
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
    -- Add context menu option
    --------------------------------------------------------
    dbg("Adding context menu option for vehicle swap")

    context:addOption("Swap Vehicle Vinyl", vehicle, function(v)
        dbg("Callback triggered for vehicle: " .. tostring(v))

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
end

Events.OnFillWorldObjectContextMenu.Add(SV_AddContextMenu)
