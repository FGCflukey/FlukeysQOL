-- Corpse Cleanup - Server Module (MP Safe)

CorpseCleanupDebug = true

local function CCDebug(msg)
    if CorpseCleanupDebug then
        print("[CorpseCleanup SERVER] " .. tostring(msg))
    end
end

CCDebug("CorpseCleanup_Server.lua loaded")

local function fallbackCorpseLookup(x, y, z)
    CCDebug("Fallback corpse lookup at " .. x .. "," .. y .. "," .. z)

    local sq = getSquare(x, y, z)
    if not sq then
        CCDebug("Fallback square missing")
        return nil
    end

    local dead = sq:getDeadBodys()
    if dead and dead:size() > 0 then
        CCDebug("Fallback corpse found")
        return dead:get(0)
    end

    CCDebug("Fallback corpse NOT found")
    return nil
end

local function dropCorpseInventory(corpse)
    CCDebug("Dropping corpse inventory")

    local container = corpse:getContainer()
    if not container then
        CCDebug("Corpse container missing")
        return
    end

    local square = corpse:getSquare()
    if not square then
        CCDebug("Corpse square missing")
        return
    end

    local items = {}
    local list = container:getItems()
    for i = 0, list:size() - 1 do
        table.insert(items, list:get(i))
    end

    for _, item in ipairs(items) do
        CCDebug("Dropping item: " .. tostring(item:getFullType()))
        container:Remove(item)
        square:AddWorldInventoryItem(item, 0, 0, 0)
    end
end

local function getZombieMeatYield(player)
    local perk = player:getPerkLevel(Perks.Butchering)
    CCDebug("Player Butchering level=" .. perk)

    if perk < 2 then return ZombRand(1, 3)
    elseif perk < 4 then return ZombRand(1, 4)
    elseif perk < 6 then return ZombRand(3, 6)
    else return ZombRand(5, 11)
    end
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "CorpseCleanup" or command ~= "Butcher" then return end

    local data = args

    CCDebug("Received butcher command from username=" .. tostring(data.playerID))

    ---------------------------------------------------------
    -- CORPSE LOOKUP
    ---------------------------------------------------------
    CCDebug("Looking for corpse at coords: " .. data.x .. "," .. data.y .. "," .. data.z)

    local corpse = fallbackCorpseLookup(data.x, data.y, data.z)
    if not corpse then
        CCDebug("ERROR: No corpse found at coords. Aborting.")
        return
    end

    ---------------------------------------------------------
    -- PLAYER (use sender directly)
    ---------------------------------------------------------
    local targetPlayer = player
    if not targetPlayer then
        CCDebug("ERROR: Player object missing. Aborting.")
        return
    end

    ---------------------------------------------------------
    -- DROP CORPSE INVENTORY
    ---------------------------------------------------------
    CCDebug("Dropping corpse inventory")
    dropCorpseInventory(corpse)

    ---------------------------------------------------------
    -- REMOVE CORPSE
    ---------------------------------------------------------
    CCDebug("Removing corpse from world")
    local sq = corpse:getSquare()
    if sq then
        sq:removeCorpse(corpse, false)
        CCDebug("Corpse removed")
    else
        CCDebug("ERROR: Corpse square missing")
    end

    ---------------------------------------------------------
    -- SPAWN MEAT
    ---------------------------------------------------------
    -- FIX: ProcessAdminChatMessage is not exposed as a callable global
    -- here, which is what crashed this section entirely last test (and
    -- also silently prevented the re-equip section below from ever
    -- running, since the crash aborted the whole handler).
    --
    -- sendAddItemToContainer(container, item) is a GameServer function
    -- built specifically to tell clients "this item was added to this
    -- container" - a much better fit than sendItemListNet (a generic
    -- notification packet, not a container-sync mechanism).
    CCDebug("Calculating zombie meat yield")
    local meatCount = getZombieMeatYield(targetPlayer)
    CCDebug("Meat count=" .. meatCount)

    local invContainer = targetPlayer:getInventory()
    for i = 1, meatCount do
        local meat = invContainer:AddItem("Base.ZombieMeat")
        if meat then
            CCDebug("Created meat item #" .. i .. ", notifying client")
            sendAddItemToContainer(invContainer, meat)
        end
    end

    ---------------------------------------------------------
    -- RE-EQUIP ORIGINAL ITEMS
    ---------------------------------------------------------
    -- FIX: same live-sync gap as the meat. setPrimaryHandItem/
    -- setSecondaryHandItem called here (server-side) change the
    -- authoritative state but don't visually update until the client
    -- forces a resync itself (e.g. manually unequipping) - that's the
    -- stuck-knife/instant-dolly behavior. Tell the owning client to
    -- re-equip itself locally instead; client-driven equip changes sync
    -- properly both ways.
    CCDebug("Telling client to re-equip original items")

    sendServerCommand(targetPlayer, "CorpseCleanup", "ReEquip", {
        originalPrimary = data.originalPrimary,
        originalSecondary = data.originalSecondary,
    })

    CCDebug("Butcher command complete")
end)