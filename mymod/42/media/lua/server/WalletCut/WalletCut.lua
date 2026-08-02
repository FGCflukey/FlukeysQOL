WalletCut_OnCreate = function(item, player)
    -- Handles both CraftRecipeData and InventoryItem
    local wallet = nil

    if item then
        if item.getItem then
            wallet = item:getItem()
        elseif item.getInventory then
            wallet = item
        end
    end

    if not wallet or not wallet.getInventory then return end

    local inv = wallet:getInventory()
    local square = player:getSquare()

    if inv and square then
        local innerItems = inv:getItems()
        for i = 0, innerItems:size() - 1 do
            local inner = innerItems:get(i)
            square:AddWorldInventoryItem(inner, 0.5, 0.5, 0)
        end
        inv:clear()
    end

    player:getInventory():Remove(wallet)
end
