local function getActualItem(items)
    if not items then return nil end

    if instanceof(items, "InventoryItem") then
        return items
    end

    if type(items) == "table" then
        local first = items[1]
        if not first then return nil end

        if instanceof(first, "InventoryItem") then
            return first
        end

        if type(first) == "table" and first.items and first.items[1] then
            return first.items[1]
        end
    end

    return nil
end

local function isValidCarPart(item)
    if not item then return false end

    local name = string.lower(item:getFullType() or item:getType())

    if string.find(name, "armor") then
        return false
    end

    return
        string.find(name, "door") or
        string.find(name, "bumper") or
        string.find(name, "frontwindow") or
        string.find(name, "frontsidewindow") or
        string.find(name, "rearwindow") or
        string.find(name, "rearsidewindow") or
        string.find(name, "windshield") or
        string.find(name, "rearwindshield")
end

local function addContextOption(_, context, items)
    local player = getSpecificPlayer(0)
    if not player then return end

    local item = getActualItem(items)
    if not item then return end

    if not isValidCarPart(item) then return end

    context:addOption("Dismantle Car Part", item, function()
        ISTimedActionQueue.add(DismantleCarPartAction:new(player, item))
    end)
end

Events.OnFillInventoryObjectContextMenu.Add(addContextOption)