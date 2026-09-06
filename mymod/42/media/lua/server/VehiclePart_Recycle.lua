local function giveItems(character, items)
    local inv = character:getInventory()
    local square = character:getSquare()

    for _, itemType in ipairs(items) do
        local item = inv:AddItem(itemType)

        if item and inv:contains(item) then
            -- Without this, the server's inventory is correctly updated
            -- but the owning client never hears about it until something
            -- else forces a full resync (e.g. a reconnect) -- same bug
            -- class as the vinyl/paint spraycans and the CarKeyCraft key.
            sendAddItemToContainer(inv, item)
        elseif square then
            -- Couldn't fit in inventory for whatever reason (e.g. a
            -- sub-container that's genuinely full) -- drop it at the
            -- character's feet instead of silently losing it.
            square:AddWorldInventoryItem(itemType, ZombRand(0, 100) / 100, ZombRand(0, 100) / 100, 0)
        end
    end
end

function GiveBack_CarSeatStuff(craftRecipeData, character)
    giveItems(character, {
        "Base.Sheet",
        "Base.LeatherStrips",
        "Base.LeatherStrips",
        "Base.MetalBar",
        "Base.MetalBar",
        "Base.SmallSheetMetal",
        "Base.SmallSheetMetal",
        "Base.Thread",
        "Base.Thread",
    })
end

function GiveBack_ElectronicScrap(craftRecipeData, character)
    giveItems(character, {
        "Base.ElectronicsScrap",
        "Base.ElectronicsScrap",
        "Base.ElectricWire",
        "Base.ElectricWire",
    })
end

function GiveBack_DoorStuff(craftRecipeData, character)
    giveItems(character, {
        "Base.MetalBar",
        "Base.MetalBar",
        "Base.SheetMetal",
        "Base.SmallSheetMetal",
        "Base.ElectronicsScrap",
        "Base.ElectricWire",
        "Base.NutsBolts",
    })
end

