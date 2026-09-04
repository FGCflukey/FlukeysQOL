CarKeyCraft = CarKeyCraft or {}

CarKeyCraft.BlankType = "Base.Key_Blank"
CarKeyCraft.CutToolTypes = { "Base.Multitool", "Base.SmallFileSet" }

CarKeyCraft.CutSkill = { MetalWelding = 4, Mechanics = 2 }

function CarKeyCraft.getKeyBlank(playerObj)
    return playerObj:getInventory():getFirstTypeRecurse(CarKeyCraft.BlankType)
end

function CarKeyCraft.getCutTool(playerObj)
    local inv = playerObj:getInventory()
    for i = 1, #CarKeyCraft.CutToolTypes do
        local item = inv:getFirstTypeRecurse(CarKeyCraft.CutToolTypes[i])
        if item then return item end
    end
    return nil
end

function CarKeyCraft.meetsCutSkill(playerObj)
    return playerObj:getPerkLevel(Perks.MetalWelding) >= CarKeyCraft.CutSkill.MetalWelding
       and playerObj:getPerkLevel(Perks.Mechanics) >= CarKeyCraft.CutSkill.Mechanics
end