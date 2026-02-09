-- External Generator Barrel Fuel (Server)

require "EG_BarrelFuel_Shared"

local function updateGenerator(gen)
    if not gen:isActivated() then return end

    local barrel = EG_BarrelFuel.findNearbyBarrel(gen)
    if not barrel then return end
    if not EG_BarrelFuel.isBarrelOpen(barrel) then return end

    local barrelFuel = EG_BarrelFuel.getBarrelFuel(barrel)
    if barrelFuel <= 0 then return end

    local md = gen:getModData()
    local now = getGameTime():getWorldAgeHours()

    if not md.EG_LastUpdate then
        md.EG_LastUpdate = now
        return
    end

    local elapsed = now - md.EG_LastUpdate
    if elapsed <= 0 then return end

    md.EG_LastUpdate = now

    -- Vanilla generator fuel burn rate
    local burnRate = 0.01  -- fuel units per hour (adjust if needed)

    local needed = elapsed * burnRate

    if barrelFuel >= needed then
        -- Keep generator full
        gen:setFuel(100)
        EG_BarrelFuel.drainBarrel(barrel, needed)
    else
        -- Barrel ran dry mid‑simulation
        gen:setFuel(0)
        gen:setActivated(false)
        EG_BarrelFuel.drainBarrel(barrel, barrelFuel)
    end

    gen:transmitModData()
end

local function serverTick()
    local cell = getWorld():getCell()
    if not cell then return end

    local objects = cell:getObjectList()
    if not objects then return end

    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if instanceof(obj, "IsoGenerator") then
            updateGenerator(obj)
        end
    end
end

Events.EveryTenMinutes.Add(serverTick)