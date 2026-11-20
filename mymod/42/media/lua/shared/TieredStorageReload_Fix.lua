-- ===================================================================
--  Tiered Storage reload fix (for Workshop "Customizable Containers")
-- ===================================================================
--  That mod saves an upgraded container's tier + capacity in the
--  object's modData (CCStorageTier / CCStorageCapacity), but only
--  re-applies the capacity on game start / when an object is placed.
--  When a chunk unloads (drive away) and loads back in, the container
--  comes back with its default sprite capacity (e.g. 974 -> 65).
--
--  This re-applies the saved capacity every time a square loads, on
--  both the client and the server. Local only (no network traffic):
--  each side loads the square itself, so each side fixes its own copy.
--  Does nothing if Customizable Containers isn't installed (no object
--  will carry the modData keys).
-- ===================================================================

local DEBUG = false
local function dbg(msg)
    if DEBUG then print("[TieredStorageReloadFix] " .. tostring(msg)) end
end

local TIER_KEY     = "CCStorageTier"
local CAPACITY_KEY = "CCStorageCapacity"

local function reapply(obj)
    -- hasModData() first: getModData() would create an empty table on every object.
    if not obj:hasModData() then return end
    local md = obj:getModData()
    if md[TIER_KEY] == nil then return end

    local capacity = tonumber(md[CAPACITY_KEY])
    if not capacity or capacity <= 0 then
        -- Old save with only a tier stored: let the mod work it out (client only,
        -- since its apply function sends network updates when run on the server).
        if not isServer() and CCTieredStorage and CCTieredStorage.applyCapacityToWorldObject then
            pcall(CCTieredStorage.applyCapacityToWorldObject, obj, nil, nil, false)
        end
        return
    end
    capacity = math.floor(capacity)

    local count = obj:getContainerCount() or 0
    if count > 0 then
        for i = 0, count - 1 do
            local c = obj:getContainerByIndex(i)
            if c and c:getCapacity() ~= capacity then
                dbg("restore " .. tostring(c:getCapacity()) .. " -> " .. capacity)
                c:setCapacity(capacity)
                c:setDrawDirty(true)
            end
        end
    else
        local c = obj:getContainer()
        if c and c:getCapacity() ~= capacity then
            dbg("restore " .. tostring(c:getCapacity()) .. " -> " .. capacity)
            c:setCapacity(capacity)
            c:setDrawDirty(true)
        end
    end
end

local function onLoadGridsquare(square)
    if not square then return end
    local objects = square:getObjects()
    if not objects then return end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and obj:getContainer() then
            reapply(obj)
        end
    end
end

Events.LoadGridsquare.Add(onLoadGridsquare)
