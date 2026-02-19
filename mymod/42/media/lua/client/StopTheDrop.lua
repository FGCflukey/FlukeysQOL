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