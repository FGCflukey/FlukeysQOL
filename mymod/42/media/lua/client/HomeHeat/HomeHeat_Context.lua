-- HomeHeat_Context.lua
-- Right-click menu entry for placed HomeHeat radiators.

local function isAdjacent(player, isoObject)
    local dx = math.abs(player:getX() - isoObject:getX())
    local dy = math.abs(player:getY() - isoObject:getY())
    return dx <= 1 and dy <= 1 and player:getZ() == isoObject:getZ()
end

local function OnFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    for _, isoObject in ipairs(worldobjects) do
        if HomeHeat_Util.isRadiator(isoObject) and isAdjacent(player, isoObject) then
            context:addOption("Home Heat Settings", worldobjects, function()
                HomeHeat_UI.open(player, isoObject)
            end)
            return
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu)
