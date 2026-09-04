RefillPropane = RefillPropane or {}

function RefillPropane.isPropanePumpObject(obj)
    if not obj then return false end
    local sprite = obj:getSprite()
    if not sprite then return false end
    local lower = string.lower(sprite:getName() or "")
    return string.find(lower, "shop_fossoil_01", 1, true) ~= nil
        or string.find(lower, "shop_gas2go_01", 1, true) ~= nil
end

function RefillPropane.getPropanePump(square)
    if not square then return nil end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        if RefillPropane.isPropanePumpObject(objects:get(i)) then
            return objects:get(i)
        end
    end
    return nil
end

function RefillPropane.findNearbyPump(square)
    for dx = -1, 1 do
        for dy = -1, 1 do
            local sq = getCell():getGridSquare(square:getX()+dx, square:getY()+dy, square:getZ())
            if sq then
                local pump = RefillPropane.getPropanePump(sq)
                if pump then return pump end
            end
        end
    end
    return nil
end

function RefillPropane.isAdjacentToSquare(playerObj, targetSquare)
    if not playerObj or not targetSquare then return false end
    return playerObj:getSquare():isAdjacentTo(targetSquare)
end

function RefillPropane.collectRefillableItemsRecursive(container, results)
    if not container then return end
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local itemType = item:getType()
        if (itemType == "BlowTorch" or itemType == "PropaneTank")
           and instanceof(item, "Drainable")
           and item:getCurrentUses() < item:getMaxUses() then
            table.insert(results, item)
        end
        if item:IsInventoryContainer() then
            RefillPropane.collectRefillableItemsRecursive(item:getItemContainer(), results)
        end
    end
end

function RefillPropane.getAllRefillableItems(playerObj)
    local results = {}
    RefillPropane.collectRefillableItemsRecursive(playerObj:getInventory(), results)
    return results
end