------------------------------------------------------------
-- SwapVehicle Context Menu (Hybrid Vehicle Detection)
------------------------------------------------------------

if not SwapVehicleRegistry then
    print("ERROR: SwapVehicleRegistry missing! (Vanilla/KI5 registry not loaded)")
    return
end

------------------------------------------------------------
-- Fallback: nearest vehicle scan (your original method)
------------------------------------------------------------
local function SV_FindNearestVehicle(player)
    local px, py = player:getX(), player:getY()
    local vehicles = getCell():getVehicles()
    local closest = nil
    local closestDist = 3 -- tiles

    for i = 0, vehicles:size() - 1 do
        local v = vehicles:get(i)
        local dx = v:getX() - px
        local dy = v:getY() - py
        local dist = math.sqrt(dx*dx + dy*dy)

        if dist < closestDist then
            closest = v
            closestDist = dist
        end
    end

    return closest
end

------------------------------------------------------------
-- Add context menu option
------------------------------------------------------------
local function SV_AddContextMenu(playerIndex, context, worldobjects, test)
    local player = getSpecificPlayer(playerIndex)
    if not player then return end

    --------------------------------------------------------
    -- 1) Try official helper
    --------------------------------------------------------
    local vehicle = nil
    if ISWorldObjectContextMenu.getVehicle then
        vehicle = ISWorldObjectContextMenu.getVehicle(worldobjects)
    end

    --------------------------------------------------------
    -- 2) If that failed, use nearest-vehicle scan
    --------------------------------------------------------
    if not vehicle then
        vehicle = SV_FindNearestVehicle(player)
    end

    --------------------------------------------------------
    -- 3) If still nil, try player:getVehicle() (inside car)
    --------------------------------------------------------
    if not vehicle then
        vehicle = player:getVehicle()
    end

    if not vehicle then return end

    --------------------------------------------------------
    -- Registry lookup
    --------------------------------------------------------
    local script = vehicle:getScript():getFullName()
    if not script then return end

    local group = SwapVehicleRegistry.Groups[script]
    if not group then return end

    local variants = SwapVehicleRegistry.SwapPairs[group]
    if not variants or #variants < 2 then return end

    if test then return true end

    --------------------------------------------------------
    -- Add context menu option
    --------------------------------------------------------
    context:addOption("Swap Vehicle Vinyl", vehicle, function(v)
        if SwapVehicle_UI and SwapVehicle_UI.Open then
            SwapVehicle_UI.Open(player, v, group, variants)
        else
            print("ERROR: SwapVehicle_UI.Open missing!")
        end
    end)
end

Events.OnFillWorldObjectContextMenu.Add(SV_AddContextMenu)