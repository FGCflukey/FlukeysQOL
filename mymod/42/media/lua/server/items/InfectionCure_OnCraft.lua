function OnCreate_FilledSyringes(recipe, ingredients, result)
    local player = getPlayer()
    local emitter = player:getEmitter()

    emitter:playSound("MixingMortarPestle")

    -- Play again after a short delay
    local function playAgain()
        emitter:playSound("MixingMortarPestle")
    end
    -- 6 ticks ≈ 0.1 seconds
    Events.OnTick.Add(function()
        playAgain()
        Events.OnTick.Remove(playAgain)
    end)

    player:getXp():AddXP(Perks.Doctor, 2)
end
