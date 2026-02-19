--========================================================--
--  Make Vehicle Parts - Right Click Submenu
--  Auto‑generated from your recipe file
--========================================================--

local function craft(recipeName, player)
    ISInventoryPaneContextMenu.onCraft(recipeName, player)
end

local VehiclePartsMenu = {}

VehiclePartsMenu.Hoods = {
    { "MakeStandardCarHood", "Standard Hood" },
    { "MakeHeavyDutyCarHood", "Heavy Duty Hood" },
    { "MakeSportCarHood", "Sport Hood" },
}

VehiclePartsMenu.Doors = {
    { "MakeStandardFrontCarDoor", "Standard Front Door" },
    { "MakeStandardRearCarDoor", "Standard Rear Door" },
    { "MakeStandardRearCarDoubleDoor", "Standard Double Rear Door" },
    { "MakeStandardTrunkLid", "Standard Trunk Lid" },

    { "MakeHeavyDutyFrontCarDoor", "Heavy Duty Front Door" },
    { "MakeHeavyDutyRearCarDoor", "Heavy Duty Rear Door" },
    { "MakeHeavyDutyRearCarDoubleDoor", "Heavy Duty Double Rear Door" },
    { "MakeHeavyDutyTrunkLid", "Heavy Duty Trunk Lid" },

    { "MakeSportFrontCarDoor", "Sport Front Door" },
    { "MakeSportRearCarDoor", "Sport Rear Door" },
    { "MakeSportRearCarDoubleDoor", "Sport Double Rear Door" },
    { "MakeSportTrunkLid", "Sport Trunk Lid" },
}

VehiclePartsMenu.GasTanks = {
    { "MakeStandardSmallGasTank", "Standard Small Gas Tank" },
    { "MakeStandardGasTank", "Standard Gas Tank" },
    { "MakeStandardBigGasTank", "Standard Big Gas Tank" },

    { "MakeHeavyDutySmallGasTank", "Heavy Duty Small Gas Tank" },
    { "MakeHeavyDutyGasTank", "Heavy Duty Gas Tank" },
    { "MakeHeavyDutyBigGasTank", "Heavy Duty Big Gas Tank" },

    { "MakeSportSmallGasTank", "Sport Small Gas Tank" },
    { "MakeSportGasTank", "Sport Gas Tank" },
    { "MakeSportBigGasTank", "Sport Big Gas Tank" },
}

VehiclePartsMenu.Mufflers = {
    { "MakeStandardCarMuffler", "Standard Muffler" },
    { "MakeStandardPerformanceCarMuffler", "Standard Performance Muffler" },

    { "MakeHeavyDutyCarMuffler", "Heavy Duty Muffler" },
    { "MakeHeavyDutyPerformanceCarMuffler", "Heavy Duty Performance Muffler" },

    { "MakeSportCarMuffler", "Sport Muffler" },
    { "MakeSportPerformanceCarMuffler", "Sport Performance Muffler" },
}

VehiclePartsMenu.Tires = {
    { "MakeStandardRegularTire", "Standard Regular Tire" },
    { "MakeStandardPerformanceTire", "Standard Performance Tire" },

    { "MakeHeavyRegularTire", "Heavy Regular Tire" },
    { "MakeHeavyPerformanceTire", "Heavy Performance Tire" },

    { "MakeSportRegularTire", "Sport Regular Tire" },
    { "MakeSportPerformanceTire", "Sport Performance Tire" },
}

--========================================================--
--  Build the right‑click menu
--========================================================--

local function addSubMenu(context, title, entries, player)
    local parent = context:addOption(title)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(parent, sub)

    for _, entry in ipairs(entries) do
        local recipeName = entry[1]
        local label = entry[2]
        sub:addOption(label, nil, craft, recipeName, player)
    end
end

Events.OnFillWorldObjectContextMenu.Add(function(player, context, worldobjects, test)
    -- Only show if player has welding mask + blowtorch in inventory
    local inv = getSpecificPlayer(player):getInventory()

    -- Check for actual items, not tags (most reliable)
    if not inv:containsTypeRecurse("WeldingMask") then return end
    if not inv:containsTypeRecurse("BlowTorch") then return end

    -- Main parent menu
    local root = context:addOption("Make Vehicle Parts")
    local rootMenu = ISContextMenu:getNew(context)
    context:addSubMenu(root, rootMenu)

    addSubMenu(rootMenu, "Hoods", VehiclePartsMenu.Hoods, player)
    addSubMenu(rootMenu, "Doors", VehiclePartsMenu.Doors, player)
    addSubMenu(rootMenu, "Gas Tanks", VehiclePartsMenu.GasTanks, player)
    addSubMenu(rootMenu, "Mufflers", VehiclePartsMenu.Mufflers, player)
    addSubMenu(rootMenu, "Tires", VehiclePartsMenu.Tires, player)
end)
