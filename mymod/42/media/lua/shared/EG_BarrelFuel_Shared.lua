-- External Generator Barrel Fuel (Shared)

EG_BarrelFuel = EG_BarrelFuel or {}

-- Sprite IDs for open barrels
EG_BarrelFuel.BarrelSprites = {
    ["crafted_01_32"] = true,
    ["location_military_generic_01_14"] = true,
    ["location_military_generic_01_6"] = true,
    ["industry_01_22"] = true,
    ["industry_01_23"] = true,
}

-- Find a barrel next to a generator
function EG_BarrelFuel.findNearbyBarrel(gen)
    local sq = gen:getSquare()
    if not sq then return nil end

    for dx = -1, 1 do
        for dy = -1, 1 do
            local nsq = getCell():getGridSquare(sq:getX()+dx, sq:getY()+dy, sq:getZ())
            if nsq then
                local objects = nsq:getObjects()
                for i = 0, objects:size()-1 do
                    local obj = objects:get(i)
                    local spr = obj:getSprite()
                    if spr then
                        local name = spr:getName()
                        if name and EG_BarrelFuel.BarrelSprites[name] then
                            return obj
                        end
                    end
                end
            end
        end
    end

    return nil
end

-- Read barrel fuel (generic modData)
function EG_BarrelFuel.getBarrelFuel(barrel)
    local md = barrel:getModData()
    return md.FuelAmount or md.FluidAmount or 0
end

-- Drain barrel fuel
function EG_BarrelFuel.drainBarrel(barrel, amount)
    local md = barrel:getModData()
    local current = md.FuelAmount or md.FluidAmount or 0
    local new = math.max(0, current - amount)
    md.FuelAmount = new
    md.FluidAmount = new
    barrel:transmitModData()
end

-- Check if barrel is open
function EG_BarrelFuel.isBarrelOpen(barrel)
    local md = barrel:getModData()
    return md.IsOpen == true or md.Open == true
end