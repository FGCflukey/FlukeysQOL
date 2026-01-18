local scriptManager

-- ⭐ Custom weights table (itemName → new weight)
local customWeights = {
    Firewood = 1.0,
    FirewoodBundle = 3.5,
    Log = 4.0,
    Plank = 1.5,
    Twigs = 0.1,
    -- Add as many as you want...
}

local function modifyWeight(itemName)
    local item = scriptManager:getItem(itemName)
    if not item then return end

    local startWeight = item:getActualWeight()
    local newWeight

    -- ⭐ If custom weight exists, use it
    if customWeights[itemName] then
        newWeight = customWeights[itemName]

    -- ⭐ Otherwise, fall back to your original halving logic
    else
        newWeight = round(startWeight * 0.5, 2)
    end

    item:setActualWeight(newWeight)
    print("ReducedWoodWeightMod: Modified weight of " .. itemName ..
          " from " .. startWeight .. " to " .. newWeight)
end

local function initialize()
    scriptManager = ScriptManager.instance

    modifyWeight("Firewood")
    modifyWeight("FirewoodBundle")
    modifyWeight("Firewood_Nails")
    modifyWeight("Log")
    modifyWeight("LogStacks2")
    modifyWeight("LogStacks3")
    modifyWeight("LogStacks4")
    modifyWeight("PercedWood")
    modifyWeight("Plank")
    modifyWeight("Plank_Brake")
    modifyWeight("Plank_Broken")
    modifyWeight("Plank_Broken_Nails")
    modifyWeight("Plank_Nails")
    modifyWeight("Sapling")
    modifyWeight("TreeBranch2")
    modifyWeight("Twigs")
    modifyWeight("TwigsBundle")
    modifyWeight("UnusableWood")
    modifyWeight("Charcoal")
    modifyWeight("CharcoalCrafted")
    modifyWeight("Coke")
end

Events.OnGameBoot.Add(initialize)