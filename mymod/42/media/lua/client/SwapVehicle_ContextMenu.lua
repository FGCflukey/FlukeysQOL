local function SV_AddContextMenu(player, context, worldobjects, test)
    local p = getSpecificPlayer(player)
    if not p then return end

    -- Find nearest vehicle to player
    local px, py = p:getX(), p:getY()
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

    if not closest then return end

    local script = closest:getScript():getFullName()
    if script ~= "Base.CarTaxi" and script ~= "Base.CarTaxi2" then
        return
    end

    if test then return true end

    context:addOption("Swap Vehicle", closest, function(v)
        local args = { vehicleId = v:getId() }
        sendClientCommand("SwapVehicle", "SwapVehicle_Request", args)
    end)
end

Events.OnFillWorldObjectContextMenu.Add(SV_AddContextMenu)