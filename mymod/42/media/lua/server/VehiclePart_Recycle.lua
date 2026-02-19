local function giveItems(character, items)
    local inv = character:getInventory()
    for _, item in ipairs(items) do
        inv:AddItem(item)
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

