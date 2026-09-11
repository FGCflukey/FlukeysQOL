-- HomeHeat_Context.lua
-- Right-click menu entry for placed HomeHeat radiators.
--
-- Doesn't rely on `worldobjects` (vanilla's own right-click candidate
-- list) at all -- confirmed by testing that vanilla's hit-testing for
-- this wall-mounted, directional moveable only offers it as a click
-- candidate from the one tile its sprite visually projects into (its
-- "front"), not from tiles beside it along the same wall. Scanning
-- for a nearby radiator directly (same approach already proven in
-- HomeHeat_HeatSource.lua's scanForRadiators) works from any of the
-- 8 surrounding tiles regardless of which way the sprite is facing.

local SCAN_RADIUS = 1

local function findNearbyRadiator(player)
    local cell = getCell()
    local px = math.floor(player:getX())
    local py = math.floor(player:getY())
    local pz = player:getZ()

    for dx = -SCAN_RADIUS, SCAN_RADIUS do
        for dy = -SCAN_RADIUS, SCAN_RADIUS do
            local sq = cell:getGridSquare(px + dx, py + dy, pz)
            if sq then
                local objs = sq:getObjects()
                for i = 0, objs:size() - 1 do
                    local obj = objs:get(i)
                    if HomeHeat_Util.isRadiator(obj) then
                        return obj
                    end
                end
            end
        end
    end

    return nil
end

local function OnFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    local isoObject = findNearbyRadiator(player)
    if not isoObject then return end

    context:addOption("Home Heat Settings", worldobjects, function()
        HomeHeat_UI.open(player, isoObject)
    end)
end

Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu)
