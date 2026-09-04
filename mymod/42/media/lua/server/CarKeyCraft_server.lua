if isClient() then return end

local function noise(msg)
    print("[CarKeyCraft] " .. tostring(msg))
end

local Commands = {}

function Commands.cutKey(player, args)
    local vehicle = player:getVehicle()
    if not vehicle or not vehicle:isDriver(player) then
        noise("cutKey rejected: not driving a vehicle for " .. tostring(player:getUsername()))
        return
    end
    if vehicle:isEngineStarted() or vehicle:isEngineRunning() then
        noise("cutKey rejected: engine running for " .. tostring(player:getUsername()))
        return
    end
    if not CarKeyCraft.meetsCutSkill(player) then
        noise("cutKey rejected: insufficient skill for " .. tostring(player:getUsername()))
        return
    end

    local blank = CarKeyCraft.getKeyBlank(player)
    if not blank then
        noise("cutKey rejected: no key blank for " .. tostring(player:getUsername()))
        return
    end

    local tool = CarKeyCraft.getCutTool(player)
    if not tool then
        noise("cutKey rejected: no cutting tool for " .. tostring(player:getUsername()))
        return
    end

    local key = vehicle:createVehicleKey()
    if not key then
        noise("cutKey rejected: createVehicleKey returned nil for " .. tostring(player:getUsername()))
        player:Say("Couldn't make a key for this vehicle...")
        return
    end

    local inv = player:getInventory()
    inv:Remove(blank)
    sendRemoveItemFromContainer(inv, blank)

    inv:AddItem(key)
    key:syncItemFields()
    sendAddItemToContainer(inv, key)

    player:getXp():AddXP(Perks.MetalWelding, 25)
    noise("cut key blank into vehicle key for " .. tostring(player:getUsername()))
end

local function OnClientCommand(module, command, player, args)
    if module ~= "CarKeyCraft" then return end
    if Commands[command] then
        Commands[command](player, args or {})
    end
end

Events.OnClientCommand.Add(OnClientCommand)