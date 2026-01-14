local ProtectedItems = {
    ["Base.HCHanddolly"] = true,
    ["Base.HCToywagon"] = true,
}

---------------------------------------------------------
-- Helper: check if a single tile contains a fence
---------------------------------------------------------
local function isFenceTile(square, label)
    label = label or "UNKNOWN"

    if not square then
        -- print("DEBUG: [" .. label .. "] square is NIL")
        return false
    end

    -- Check floor
    local floor = square:getFloor()
    if floor then
        local spr = floor:getSprite()
        if spr and spr.getName then
            local name = spr:getName()
            if name and name:sub(1, 7) == "fencing" then
                -- print("DEBUG: [" .. label .. "] Fence detected (FLOOR)")
                return true
            end
        end
    end

    -- Check objects
    local objects = square:getObjects()
    if objects then
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            if obj then
                local spr = obj:getSprite()
                if spr and spr.getName then
                    local name = spr:getName()
                    if name and name:sub(1, 7) == "fencing" then
                        -- print("DEBUG: [" .. label .. "] Fence detected (OBJECT)")
                        return true
                    end
                end
            end
        end
    end

    return false
end

---------------------------------------------------------
-- Helper: get the tile in front of the player
---------------------------------------------------------
local function getFrontSquare(player, square)
    square = square or player:getSquare()
    if not square then return nil end

    local dir = player:getDir()
    local dx, dy = 0, 0

    if dir == IsoDirections.N then dy = -1
    elseif dir == IsoDirections.S then dy = 1
    elseif dir == IsoDirections.E then dx = 1
    elseif dir == IsoDirections.W then dx = -1 end

    return getCell():getGridSquare(
        square:getX() + dx,
        square:getY() + dy,
        square:getZ()
    )
end

---------------------------------------------------------
-- Combined check: current tile OR tile in front
---------------------------------------------------------
local function isFenceNearby(player)
    local square = player:getSquare()
    local front  = getFrontSquare(player, square)

    local currentIsFence = isFenceTile(square, "CURRENT")
    local frontIsFence   = isFenceTile(front,  "FRONT")

    if currentIsFence or frontIsFence then
       -- print("DEBUG: Fence nearby (" ..
       --     (currentIsFence and "CURRENT " or "") ..
       --     (frontIsFence and "FRONT" or "") .. ")")
        return true
    end

    return false
end

---------------------------------------------------------
-- Key Press Handler (E)
---------------------------------------------------------
local function OnKeyPressed(key)
    if key ~= 18 then return end  -- Only E key

    local player = getPlayer()
    if not player then return end

    if not isFenceNearby(player) then
        return
    end

    local secondary = player:getSecondaryHandItem()
    if not secondary then
        print("DEBUG: No item in secondary hand")
        return
    end

    local fullType = secondary:getFullType()
    if not ProtectedItems[fullType] then
        print("DEBUG: Secondary item not protected:", fullType)
        return
    end

    print("DEBUG: Protecting item:", fullType)

    local inv = player:getInventory()
    if not inv then return end

    -- Unequip
    player:setPrimaryHandItem(nil)
    player:setSecondaryHandItem(nil)

    -- Remove from inventory
    inv:Remove(secondary)

    local md = player:getModData()
    md.StoredClimbItem = secondary

    print("### PRE-CLIMB REMOVE:", fullType)
end

Events.OnKeyPressed.Add(OnKeyPressed)

---------------------------------------------------------
-- Restore item after climb
---------------------------------------------------------
local function OnTick()
    local player = getPlayer()
    if not player then return end

    local md = player:getModData()
    local item = md.StoredClimbItem
    if not item then return end

    if not isFenceNearby(player) then
        local inv = player:getInventory()
        if inv then
            inv:AddItem(item)
            player:setSecondaryHandItem(item)
            print("### RESTORED AFTER CLIMB:", item:getFullType())
        end

        md.StoredClimbItem = nil
    end
end

Events.OnTick.Add(OnTick)

Events.OnGameStart.Add(function()
    print("### FENCE-CLIMB PROTECTION LOADED ###")
end)