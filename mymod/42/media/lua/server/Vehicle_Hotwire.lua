function addKey()

    local player = getPlayer()
    local car = player:getVehicle()
    local inv = player:getInventory()

    -- look for vehicles nearby
    local container = player:getUseableVehicle()
    if not container then
        container = player:getNearVehicle()
    end

    -- if not sitting in a car but a vehicle is nearby, create a key for it
    if not car and container then
        inv:AddItem(container:createVehicleKey())
        return
    end

    -- if no vehicle at all
    if not car then
        player:Say("Not in a vehicle...")
        inv:AddItem("Base.SmallSheetMetal")
    else
        inv:AddItem(car:createVehicleKey())
    end
end

function unHotwire(items, result, player)
    -- print("Unhotwire function loaded from:", getFileReader("Vehicle_Hotwire.lua", true))

    player = player or getPlayer()

    local car = player:getVehicle()

    if not car then
        player:Say("Not in a vehicle...")
        return
    end

    car:setHotwired(false)
    car:setHotwiredBroken(false)
    car:setKeysInIgnition(false)

    car:transmitModData()
end


