local scriptManager

local customWeights = {
    ["Base.Firewood"] = 1.0,
    ["Base.FirewoodBundle"] = 3.5,
    ["Base.Log"] = 4.0,
    ["Base.Plank"] = 1.5,
    ["Base.Twigs"] = 0.1,
    ["Base.Nails"] = 0.02,
    ["Base.Screws"] = 0.02,
}

local function modifyWeight(itemName)
    local item = scriptManager:getItem(itemName)
    if not item then return end

    local startWeight = item:getActualWeight()
    local newWeight = customWeights[itemName] or startWeight

    item:setActualWeight(newWeight)
    print("WeightOverride: " .. itemName .. " changed from " .. startWeight .. " to " .. newWeight)
end

local function initialize()
    scriptManager = ScriptManager.instance

    for itemName, _ in pairs(customWeights) do
        modifyWeight(itemName)
    end
end

Events.OnGameStart.Add(initialize)
