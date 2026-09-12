-- Automaker_Context.lua
-- Right-click "Build Vehicle" entry, anywhere in the world -- matches
-- the original mod's behavior (no placement restriction is enforced;
-- the window title itself just asks the player to build outside in
-- the open).

local function OnFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    context:addOption("Build Vehicle", worldobjects, function()
        AutomakerUI.open(player)
    end)
end

Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu)
