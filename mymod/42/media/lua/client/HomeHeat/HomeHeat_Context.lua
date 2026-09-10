-- HomeHeat_Context.lua
-- Right-click menu entry for placed HomeHeat radiators.

-- TEMP DEBUG: prints what every nearby world object actually reports
-- for texture/sprite name, so we can see exactly why isRadiator() is
-- or isn't matching instead of guessing. Safe to remove once this is
-- confirmed working.
local DEBUG = true
local function dbg(msg)
    if DEBUG then print("[HomeHeat:Context] " .. tostring(msg)) end
end

local function isAdjacent(player, isoObject)
    local dx = math.abs(player:getX() - isoObject:getX())
    local dy = math.abs(player:getY() - isoObject:getY())
    return dx <= 1 and dy <= 1 and player:getZ() == isoObject:getZ()
end

local function OnFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    dbg("OnFillWorldObjectContextMenu fired, " .. tostring(#worldobjects) .. " worldobjects")

    local found = false

    for _, isoObject in ipairs(worldobjects) do
        local textureName = "nil"
        local ok, tex = pcall(function() return isoObject:getTextureName() end)
        if ok and tex then textureName = tex end

        local spriteName = "nil"
        local ok2, sp = pcall(function()
            local sprite = isoObject:getSprite()
            return sprite and sprite:getName()
        end)
        if ok2 and sp then spriteName = sp end

        local isRadiator = HomeHeat_Util.isRadiator(isoObject)
        local adjacent = isAdjacent(player, isoObject)

        dbg("  object=" .. tostring(isoObject) ..
            " textureName=" .. textureName ..
            " spriteName=" .. spriteName ..
            " isRadiator=" .. tostring(isRadiator) ..
            " adjacent=" .. tostring(adjacent))

        if isRadiator and adjacent and not found then
            found = true
            context:addOption("Home Heat Settings", worldobjects, function()
                HomeHeat_UI.open(player, isoObject)
            end)
        end
    end

    if not found then
        dbg("  no matching radiator found near player")
    end

    -- TEMP DEBUG: independent test path that doesn't rely on sprite
    -- detection at all -- finds anything nearby whose modData was set
    -- up by HomeHeat_Server.lua's OnObjectAdded (a real radiator, proven
    -- by the server, regardless of what isRadiator() thinks) and opens
    -- the settings UI on it directly. Remove once isRadiator is confirmed
    -- working end-to-end.
    if DEBUG then
        for _, isoObject in ipairs(worldobjects) do
            local ok, modData = pcall(function() return isoObject:getModData() end)
            if ok and modData and modData.presetKey ~= nil then
                context:addOption("[DEBUG] Open Home Heat UI", worldobjects, function()
                    HomeHeat_UI.open(player, isoObject)
                end)
                break
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu)
