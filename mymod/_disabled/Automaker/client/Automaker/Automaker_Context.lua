-- Automaker_Context.lua
-- Right-click "Build Vehicle" entry, anywhere in the world -- matches
-- the original mod's behavior (no placement restriction is enforced;
-- the window title itself just asks the player to build outside in
-- the open).
--
-- The option only shows up at all if the player is physically carrying
-- Base.AutomakerMag3 (Autobody Design And Manufacture) -- the top-tier
-- magazine acts as a reference manual you consult while building, kept
-- deliberately separate from "has learned the recipe" (LearnedRecipes):
-- this is a possession check, not a knowledge check, so you can't build
-- from memory alone. Checked recursively (getFirstTypeRecurse) so it
-- counts from a worn backpack or dolly, not just main inventory.
local function hasReferenceMagazine(player)
    local inv = player:getInventory()
    return inv:getFirstTypeRecurse("Base.AutomakerMag3") ~= nil
end

local function OnFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    if not hasReferenceMagazine(player) then return end

    context:addOption("Build Vehicle", worldobjects, function()
        AutomakerUI.open(player)
    end)
end

Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu)
