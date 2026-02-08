-- overriding the hood opening to be near instant.

local oldFunc = ISOpenMechanicsUIAction.new

function ISOpenMechanicsUIAction:new(character, vehicle, usedHood)
    local o = oldFunc(self, character, vehicle, usedHood)
    o.maxTime = 20 - character:getPerkLevel(Perks.Mechanics);
    return o
end