-- Must live in lua/shared/, not lua/client/ -- the zombie-hit roll that
-- decides whether a hat/glasses item falls off (IsoGameCharacter's
-- helmetFall check) is resolved with server authority in multiplayer.
-- A client-only listener would zero out ChanceToFall on the client's own
-- copy of the item, but the server's copy (the one actually rolled
-- against) would never be touched, so items would keep falling despite
-- the client believing it had fixed them.

local function StopTheDrop(player)
    if not player or player:isDead() then return end

    local wornItems = player:getWornItems()
    if not wornItems then return end

    for i = 0, wornItems:size() - 1 do
        local item = wornItems:getItemByIndex(i)

        if item and item.getChanceToFall and item.setChanceToFall then
            if item:getChanceToFall() ~= 0 then
                item:setChanceToFall(0)
            end
        end
    end
end

local function OnCreatePlayer(playerIndex, player)
    if playerIndex == 0 then
        StopTheDrop(player)
    end
end

Events.OnClothingUpdated.Add(StopTheDrop)
Events.OnCreatePlayer.Add(OnCreatePlayer)
