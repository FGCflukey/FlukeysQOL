-- BrownCowMilkFix.lua
-- Brown (simmental) cows give chocolate milk. Runs on OnGameBoot, after
-- vanilla's CowDefinitions has loaded, so no require is needed.

local function BrownCowMilkFix()
    if AnimalDefinitions and AnimalDefinitions.breeds and AnimalDefinitions.breeds["cow"]
        and AnimalDefinitions.breeds["cow"].breeds and AnimalDefinitions.breeds["cow"].breeds["simmental"] then
        AnimalDefinitions.breeds["cow"].breeds["simmental"].milkType = "MilkChocolate"
    end
end

Events.OnGameBoot.Add(BrownCowMilkFix)
