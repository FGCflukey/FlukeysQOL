Events.OnServerCommand.Add(function(module, command, args)
    if module == "VL" and command == "PlayLevelUpSound" then
        local player = getPlayer()
        if player then
            player:getEmitter():playSound("LevelUp")
        end
    end
end)