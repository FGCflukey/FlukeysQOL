-- BrownCowMilkFix.lua
-- Ported in from the Workshop mod "Nepenthe's Chocolate Milk From
-- Brown Cows" (Steam id 3399431185), which is broken as published.
--
-- Its own BrownCowFix.lua has:
--     require "Definitions\animal\CowDefinitions"
-- using Windows-style backslashes. A Lua string literal treats \ as
-- an escape-sequence introducer, not a literal path separator: \a is
-- the real Lua escape for the bell control character (silently
-- swallowing the "a"), and \C isn't a recognized escape at all
-- (silently dropped too) -- between the two, the string that actually
-- reaches require() comes out as "DefinitionsnimalCowDefinitions",
-- exactly matching the "require(...) failed" error reported in the
-- logs. Since that failure aborts the whole chunk, the OnGameBoot
-- handler that actually applies the milk-type change never even gets
-- registered.
--
-- That require was unnecessary to begin with -- OnGameBoot fires
-- after ALL lua (vanilla included) has already loaded, so vanilla's
-- own shared/Definitions/animal/CowDefinitions.lua has always already
-- populated AnimalDefinitions by the time this runs. Dropped it
-- entirely (rather than just fixing the slashes) so there's nothing
-- left that could break the same way again.

local function BrownCowMilkFix()
    if AnimalDefinitions and AnimalDefinitions.breeds and AnimalDefinitions.breeds["cow"]
        and AnimalDefinitions.breeds["cow"].breeds and AnimalDefinitions.breeds["cow"].breeds["simmental"] then
        AnimalDefinitions.breeds["cow"].breeds["simmental"].milkType = "MilkChocolate"
    end
end

Events.OnGameBoot.Add(BrownCowMilkFix)
