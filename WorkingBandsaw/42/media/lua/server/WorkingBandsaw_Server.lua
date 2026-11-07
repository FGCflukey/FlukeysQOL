-- WorkingBandsaw_Server.lua
-- Server-authoritative handler for the Working Bandsaw mod: sawing logs
-- into planks, picking a bandsaw up off the floor, and placing one back
-- down. The client's request is never trusted on its own -- every fact
-- that actually matters is re-derived here: the plank-per-log ratio, that
-- the player is actually near the square they claim, that a real bandsaw
-- object is actually there (or isn't, for placement), that the square has
-- electricity, and that the player actually has a crowbar.
--
-- The Workshop mod the SawLogs handler replaces ("Industrial Saw Mod", id
-- 3702250114) skipped all of its equivalent checks and took the plank
-- ratio straight off the network packet -- a tampered client could
-- request any ratio it liked.
--
-- The pick-up/place flow mirrors MyPersonalBankSafe's proven
-- detach/place/pick-up pattern (PersonalBankSafe_Server.lua), with one
-- real difference: a bandsaw has no owner and nothing to loot, so there's
-- no registry, no ownership key, and no "is it empty" check -- anyone
-- with a crowbar can pick up any bandsaw, same as anyone can use one.

require "WorkingBandsaw_Shared"

local DEBUG = false
local function dbg(msg)
    if DEBUG then
        print("[WorkingBandsaw:Server] " .. tostring(msg))
    end
end

local MAX_INTERACT_DISTANCE = 2
local MAX_LOG_REQUEST = 200 -- sanity cap, independent of what's actually on the map

---------------------------------------------------------
-- Shared helpers
---------------------------------------------------------
local function playerIsNearSquare(player, square)
    if not square then return false end
    if player:getZ() ~= square:getZ() then return false end
    local dist = IsoUtils.DistanceTo(player:getX(), player:getY(), square:getX() + 0.5, square:getY() + 0.5)
    return dist <= MAX_INTERACT_DISTANCE
end

local function findBandsawAt(square)
    if not square then return nil end
    local objects = square:getObjects()
    if not objects then return nil end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if WorkingBandsaw.IsBandSaw(obj) then return obj end
    end
    return nil
end

local function hasCrowbar(player)
    local inv = player:getInventory()
    if inv:getFirstTypeRecurse("Base.Crowbar") then return true end

    local primary = player:getPrimaryHandItem()
    if primary and primary:getFullType() == "Base.Crowbar" then return true end

    local secondary = player:getSecondaryHandItem()
    if secondary and secondary:getFullType() == "Base.Crowbar" then return true end

    return false
end

local function giveItem(player, fullType)
    local inv = player:getInventory()
    local item = inv:AddItem(fullType)
    if item and inv:contains(item) then
        sendAddItemToContainer(inv, item)
    end
    return item
end

local function removeOneItem(player, fullType)
    local inv = player:getInventory()
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it:getFullType() == fullType then
            inv:Remove(it)
            -- Removing server-side alone never tells the owning client -- the
            -- item would just sit there visually, same bug class already
            -- fixed throughout this pack (e.g. ATM_Server.lua).
            sendRemoveItemFromContainer(inv, it)
            return true
        end
    end
    return false
end

--- B42: AddSpecialObject adds the object to both the square's objects list
--- AND its special-objects list. RemoveTileObject only clears the objects
--- list, so the special-objects entry survives as a ghost reference --
--- causing "IsoThumpable not found on square" and a tile that silently
--- refuses further placement. Same fix already proven in
--- PersonalBankSafe_Server.lua's removeSafeFromSquare.
local function removeBandsawFromSquare(sq, obj)
    if not sq or not obj then return end
    pcall(function() sq:transmitRemoveItemFromSquare(obj) end)
    pcall(function() sq:RemoveTileObject(obj) end)
    pcall(function()
        local specials = sq:getSpecialObjects()
        if specials then specials:remove(obj) end
    end)
    pcall(function() sq:RecalcProperties() end)
end

---------------------------------------------------------
-- SawLogs
---------------------------------------------------------
local function handleSawLogs(player, args)
    local requestedLogs = math.floor(tonumber(args.logCount) or 0)
    if requestedLogs < 1 then return end
    requestedLogs = math.min(requestedLogs, MAX_LOG_REQUEST)

    local squareX, squareY, squareZ = args.squareX, args.squareY, args.squareZ
    if not (squareX and squareY and squareZ) then
        dbg(player:getUsername() .. " sent SawLogs with no square")
        return
    end

    local square = getCell():getGridSquare(squareX, squareY, squareZ)
    if not square then
        dbg(player:getUsername() .. " sent SawLogs for an invalid square")
        return
    end

    -- Re-validate proximity server-side -- the client's own walkAdj check
    -- only ever governed the LOCAL action queue, never the server's trust.
    if not playerIsNearSquare(player, square) then
        dbg(player:getUsername() .. " is too far from that bandsaw")
        return
    end

    if not findBandsawAt(square) then
        dbg(player:getUsername() .. " claimed a bandsaw that isn't there")
        return
    end

    if not WorkingBandsaw.HasElectricity(square) then
        dbg(player:getUsername() .. " tried to saw with no electricity")
        return
    end

    -- Plank ratio and search range: server's own sandbox-configured values,
    -- never the client's.
    local planksPerLog = WorkingBandsaw.GetOption("PlanksPerLog", 3)
    local range = WorkingBandsaw.GetOption("SearchRange", 5)

    local inv = player:getInventory()
    if not inv then return end
    inv:setDrawDirty(true)

    local logsRemoved = 0
    local logsNeeded = requestedLogs

    -- Step 1: player's own inventory.
    while logsNeeded > 0 do
        local log = inv:FindAndReturn("Base.Log")
        if not log then break end
        inv:Remove(log)
        sendRemoveItemFromContainer(inv, log)
        logsRemoved = logsRemoved + 1
        logsNeeded = logsNeeded - 1
    end

    local sx, sy, sz = square:getX(), square:getY(), square:getZ()

    -- Step 2: logs on the ground nearby.
    if logsNeeded > 0 then
        for dx = -range, range do
            for dy = -range, range do
                if logsNeeded <= 0 then break end
                local checkSquare = getCell():getGridSquare(sx + dx, sy + dy, sz)
                if checkSquare then
                    local groundObjects = checkSquare:getObjects()
                    if groundObjects then
                        for i = groundObjects:size() - 1, 0, -1 do
                            if logsNeeded <= 0 then break end
                            local obj = groundObjects:get(i)
                            if obj and instanceof(obj, "IsoWorldInventoryObject") then
                                local item = obj:getItem()
                                if item and item:getFullType() == "Base.Log" then
                                    checkSquare:transmitRemoveItemFromSquare(obj)
                                    logsRemoved = logsRemoved + 1
                                    logsNeeded = logsNeeded - 1
                                end
                            end
                        end
                    end
                end
            end
            if logsNeeded <= 0 then break end
        end
    end

    -- Step 3: logs in nearby containers (crates, vehicle parts, etc.).
    if logsNeeded > 0 then
        local processedContainers = {}

        for dx = -range, range do
            for dy = -range, range do
                if logsNeeded <= 0 then break end
                local checkSquare = getCell():getGridSquare(sx + dx, sy + dy, sz)
                if checkSquare then
                    local containerObjects = checkSquare:getObjects()
                    if containerObjects then
                        for i = 0, containerObjects:size() - 1 do
                            if logsNeeded <= 0 then break end
                            local obj = containerObjects:get(i)
                            if obj and obj.getContainer then
                                local container = obj:getContainer()
                                if container and not processedContainers[container] then
                                    processedContainers[container] = true
                                    local logs = container:getItemsFromFullType("Base.Log")
                                    if logs then
                                        for j = logs:size() - 1, 0, -1 do
                                            if logsNeeded <= 0 then break end
                                            local log = logs:get(j)
                                            container:Remove(log)
                                            sendRemoveItemFromContainer(container, log)
                                            logsRemoved = logsRemoved + 1
                                            logsNeeded = logsNeeded - 1
                                        end
                                    end
                                end
                            end
                        end
                    end

                    local vehicle = checkSquare:getVehicleContainer()
                    if vehicle and logsNeeded > 0 then
                        for partIndex = 0, vehicle:getPartCount() - 1 do
                            if logsNeeded <= 0 then break end
                            local part = vehicle:getPartByIndex(partIndex)
                            if part and part:getItemContainer() then
                                local container = part:getItemContainer()
                                if not processedContainers[container] then
                                    processedContainers[container] = true
                                    local logs = container:getItemsFromFullType("Base.Log")
                                    if logs then
                                        for j = logs:size() - 1, 0, -1 do
                                            if logsNeeded <= 0 then break end
                                            local log = logs:get(j)
                                            container:Remove(log)
                                            sendRemoveItemFromContainer(container, log)
                                            logsRemoved = logsRemoved + 1
                                            logsNeeded = logsNeeded - 1
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if logsNeeded <= 0 then break end
        end
    end

    if logsRemoved <= 0 then
        dbg(player:getUsername() .. " had no logs available after all")
        return
    end

    local totalPlanks = logsRemoved * planksPerLog
    for _i = 1, totalPlanks do
        local posX = ZombRandFloat(0.2, 0.8)
        local posY = ZombRandFloat(0.2, 0.8)
        square:AddWorldInventoryItem("Base.Plank", posX, posY, 0)
    end

    local xpAmount = logsRemoved * 3
    player:getXp():AddXP(Perks.Woodwork, xpAmount)

    dbg(player:getUsername() .. " sawed " .. logsRemoved .. " logs into " .. totalPlanks .. " planks")
end

---------------------------------------------------------
-- PickUp: any Metal Bandsaw (map-found or player-placed) -> carried item
---------------------------------------------------------
local function handlePickUp(player, args)
    if not args or not args.x or not args.y or not args.z then return end
    local square = getCell():getGridSquare(args.x, args.y, args.z)
    if not square then return end

    if not playerIsNearSquare(player, square) then
        dbg(player:getUsername() .. " PickUp rejected: not near square")
        return
    end
    if not hasCrowbar(player) then
        dbg(player:getUsername() .. " PickUp rejected: no crowbar")
        return
    end

    local obj = findBandsawAt(square)
    if not obj then
        dbg(player:getUsername() .. " PickUp rejected: no bandsaw at square")
        return
    end

    removeBandsawFromSquare(square, obj)
    giveItem(player, "WorkingBandsaw.BandsawItem")
    dbg(player:getUsername() .. " picked up a bandsaw at " .. args.x .. "," .. args.y .. "," .. args.z)
end

---------------------------------------------------------
-- Place: carried item -> real Metal Bandsaw entity
---------------------------------------------------------
local function handlePlace(player, args)
    if not args or not args.x or not args.y or not args.z or not args.direction then return end
    local spriteName = WorkingBandsaw.SPRITES[args.direction]
    if not spriteName then return end

    local square = getCell():getGridSquare(args.x, args.y, args.z)
    if not square then return end

    if not playerIsNearSquare(player, square) then
        dbg(player:getUsername() .. " Place rejected: not near square")
        return
    end
    if findBandsawAt(square) then
        player:Say(getText("IGUI_WorkingBandsaw_Occupied"))
        return
    end

    if not removeOneItem(player, "WorkingBandsaw.BandsawItem") then
        dbg(player:getUsername() .. " Place rejected: no carried bandsaw item")
        return
    end

    local cell = getCell()
    local obj = IsoThumpable.new(cell, square, spriteName, false, {})
    obj:setIsContainer(false)
    obj:setIsDismantable(false)
    obj:setIsThumpable(false)
    obj:setMaxHealth(1000000)
    obj:setHealth(1000000)
    obj:setName(getText("IGUI_WorkingBandsaw_Name"))

    -- Attach the real entity components (UiConfig/CraftBench/SpriteConfig)
    -- so this is a genuine, fully-functional Metal Bandsaw -- not a
    -- decorative lookalike -- same technique vanilla's own
    -- ISBuildIsoEntity/MORainCollectorBarrel use for entity-bearing
    -- furniture.
    local info = SpriteConfigManager.getObjectInfoFromSprite(spriteName)
    if info and info:getScript() and info:getScript():getParent() then
        local gameEntityScript = info:getScript():getParent()
        GameEntityFactory.CreateIsoObjectEntity(obj, gameEntityScript, true)
    else
        dbg("Place: no entity script found for sprite " .. tostring(spriteName))
    end

    square:AddSpecialObject(obj)
    obj:transmitCompleteItemToClients()

    dbg(player:getUsername() .. " placed a bandsaw facing " .. args.direction .. " at " .. args.x .. "," .. args.y .. "," .. args.z)
end

---------------------------------------------------------
-- Dispatch
---------------------------------------------------------
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "WorkingBandsaw" then return end
    if not player then return end

    if command == "SawLogs" then
        handleSawLogs(player, args)
    elseif command == "PickUp" then
        handlePickUp(player, args)
    elseif command == "Place" then
        handlePlace(player, args)
    end
end)
