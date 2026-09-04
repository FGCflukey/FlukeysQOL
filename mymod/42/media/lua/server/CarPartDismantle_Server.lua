-- lua/server/CarPartDismantle_Server.lua
-- Server-authoritative handler for the CarPartDismantle mod.
-- Re-validates everything the client claimed and is the only place
-- that actually mutates inventory state.

local DEBUG = false

local function dbg(msg)
    if DEBUG then
        print("[CarPartDismantle][Server] " .. tostring(msg))
    end
end

local function isGlassPart(name)
    return
        string.find(name, "frontwindow") or
        string.find(name, "frontsidewindow") or
        string.find(name, "rearwindow") or
        string.find(name, "rearsidewindow") or
        string.find(name, "windshield") or
        string.find(name, "rearwindshield")
end

-- Finds an item by ID anywhere within a player's inventory (handles
-- nested containers, e.g. an item sitting inside a backpack).
local function findItemByID(inv, id)
    if not inv or not id then return nil end

    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item:getID() == id then
            return item
        end

        if instanceof(item, "InventoryContainer") then
            local nested = findItemByID(item:getInventory(), id)
            if nested then return nested end
        end
    end

    return nil
end

local function addReward(inv, player, fullType)
    local item = inv:AddItem(fullType)
    if item then
        sendAddItemToContainer(inv, item)
    end
    return item
end

local function grantRewards(inv, player, name)
    if
        string.find(name, "trunkdoor") or string.find(name, "trunkcardoor") or
        string.find(name, "enginedoor") or string.find(name, "enginecardoor")
    then
        addReward(inv, player, "Base.SheetMetal")
        addReward(inv, player, "Base.SheetMetal")

    elseif
        string.find(name, "frontdoor") or string.find(name, "frontcardoor") or
        string.find(name, "reardoor")  or string.find(name, "rearcardoor")
    then
        addReward(inv, player, "Base.SheetMetal")

        local wires  = ZombRand(1, 4)
        local bolts  = ZombRand(1, 5)
        local screws = ZombRand(1, 5)

        for i = 1, wires  do addReward(inv, player, "Base.ElectricWire") end
        for i = 1, bolts  do addReward(inv, player, "Base.NutsBolts") end
        for i = 1, screws do addReward(inv, player, "Base.Screws") end

    elseif string.find(name, "bumper") then
        local bars  = ZombRand(1, 3)
        local bolts = ZombRand(1, 5)

        for i = 1, bars  do addReward(inv, player, "Base.SteelBar") end
        for i = 1, bolts do addReward(inv, player, "Base.NutsBolts") end

    elseif
        string.find(name, "frontwindow") or
        string.find(name, "frontsidewindow") or
        string.find(name, "rearwindow") or
        string.find(name, "rearsidewindow")
    then
        addReward(inv, player, "Base.GlassPanel")

    elseif
        string.find(name, "windshield") or
        string.find(name, "rearwindshield")
    then
        addReward(inv, player, "Base.GlassPanel")
        addReward(inv, player, "Base.GlassPanel")

    else
        addReward(inv, player, "Base.SheetMetal")
    end
end

local function onClientCommand(module, command, player, args)
    if module ~= "CarPartDismantle" or command ~= "dismantle" then return end

    dbg("Received dismantle request from " .. tostring(player:getUsername()))

    if not args or not args.partID then
        dbg("REJECT: missing partID in args")
        return
    end

    local inv = player:getInventory()
    if not inv then
        dbg("REJECT: player inventory nil")
        return
    end

    local part = findItemByID(inv, args.partID)
    if not part then
        dbg("REJECT: part with ID " .. tostring(args.partID) .. " not found in player inventory")
        return
    end

    local name = string.lower(part:getFullType() or part:getType() or "")
    local glass = isGlassPart(name)

    dbg("part=" .. tostring(name) .. " glass=" .. tostring(glass))

    if glass then
        local scalpel = inv:getFirstTypeRecurse("Scalpel")
        if not scalpel then
            dbg("REJECT: no scalpel present for glass dismantle")
            return
        end
    else
        local torch = inv:getFirstTypeRecurse("BlowTorch")
        local mask  = inv:getFirstTypeRecurse("WeldingMask")

        if not torch then
            dbg("REJECT: no blowtorch present")
            return
        end

        local uses = torch.getCurrentUses and torch:getCurrentUses() or 0
        if uses <= 0 then
            dbg("REJECT: blowtorch has no uses left")
            return
        end

        if not mask then
            dbg("REJECT: no welding mask present")
            return
        end

        dbg("Consuming one blowtorch use (was " .. tostring(uses) .. ")")
        torch:setCurrentUses(math.max(uses - 1, 0))
        syncItemFields(player, torch)
    end

    -- All checks passed - perform the actual, authoritative mutation.
    grantRewards(inv, player, name)

    dbg("Removing part " .. tostring(name) .. " from server inventory")
    local partContainer = part:getContainer() or inv
    partContainer:Remove(part)
    sendRemoveItemFromContainer(partContainer, part)

    dbg("Dismantle complete for " .. tostring(player:getUsername()))
end

Events.OnClientCommand.Add(onClientCommand)