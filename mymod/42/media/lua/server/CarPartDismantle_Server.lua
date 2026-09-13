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

-- Finds an item by ID in the player's own inventory (above), OR in a
-- nearby world container (a crate, etc.) if containerX/Y/Z point at
-- one -- same gap CarPartRepair had: this context menu fires for ANY
-- open inventory-style panel (OnFillInventoryObjectContextMenu), not
-- just the player's own, so a part sitting in a crate's loot panel
-- used to silently fail here with "not found in player inventory".
-- containerX/Y/Z is just a client hint -- re-validated against the
-- player's actual distance before trusting it (same 2-tile margin
-- vanilla's own luautils.walkToContainer() uses for containers), never
-- trusted blindly. See CarPartRepair_Util.findItemNearby() for the
-- proven original of this exact pattern.
local function findItemNearby(player, id, containerX, containerY, containerZ)
    local found = findItemByID(player:getInventory(), id)
    if found then return found end

    if not containerX or not containerY or not containerZ then return nil end

    local square = getSquare(containerX, containerY, containerZ)
    if not square then return nil end

    local playerSquare = player:getSquare()
    if not playerSquare or playerSquare:DistToProper(square) > 2 then
        return nil
    end

    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and obj.getContainer then
            local ok, container = pcall(obj.getContainer, obj)
            if ok and container then
                found = findItemByID(container, id)
                if found then return found end
            end
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

    local part = findItemNearby(player, args.partID, args.containerX, args.containerY, args.containerZ)
    if not part then
        dbg("REJECT: part with ID " .. tostring(args.partID) .. " not found in player inventory or nearby container")
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

        -- Use() (not a raw setCurrentUses() decrement) is what actually
        -- respects UseDelta -- getCurrentUses() on a Drainable item is a
        -- 0.0-1.0 fraction, not an integer count, so "uses - 1" on a full
        -- torch (1.0) drove it straight to 0 in a single dismantle instead
        -- of costing one real UseDelta unit. Same bug family as the repair
        -- kits; see CarPartRepair_Server.lua for the same fix.
        dbg("Consuming one blowtorch use (was " .. tostring(uses) .. ")")
        torch:Use()
        sendItemStats(torch)
    end

    -- All checks passed - perform the actual, authoritative mutation.
    -- Reward materials always go to the player's OWN inventory (`inv`,
    -- never the part's source container), same as if it'd been picked up
    -- first -- so unlike CarPartRepair's crate case, there's no "part sits
    -- in a crate showing stale state" problem here: the part is fully
    -- REMOVED (sendRemoveItemFromContainer, already proven reliable for
    -- material consumption in CarPartRepair even from a backpack/dolly),
    -- not condition-mutated in place, so no move-into-inventory step
    -- should be needed. Not yet tested against a live crate dismantle --
    -- if the crate keeps showing the removed part until reconnect, that's
    -- the same class of bug and the fix is the same move-first trick.
    grantRewards(inv, player, name)

    dbg("Removing part " .. tostring(name) .. " from server inventory")
    local partContainer = part:getContainer() or inv
    partContainer:Remove(part)
    sendRemoveItemFromContainer(partContainer, part)

    dbg("Dismantle complete for " .. tostring(player:getUsername()))
end

Events.OnClientCommand.Add(onClientCommand)