-- WorkingBandsaw_Server.lua
-- Server-authoritative handler for sawing logs into planks at the Metal
-- Bandsaw. The client's request is treated as nothing more than "I'd like
-- to saw up to N logs at square (x,y,z)" -- every fact that actually
-- matters is re-derived here:
--   - the plank-per-log ratio (never trust args.planksPerLog)
--   - that the player is actually near that square
--   - that a real bandsaw object is actually there
--   - that the square actually has electricity
-- The Workshop mod this replaces ("Industrial Saw Mod", id 3702250114)
-- skipped all four checks and took args.planksPerLog straight off the
-- network packet -- a tampered client could request any ratio it liked.

require "WorkingBandsaw_Shared"

local DEBUG = false
local function dbg(msg)
    if DEBUG then
        print("[WorkingBandsaw:Server] " .. tostring(msg))
    end
end

local MAX_INTERACT_DISTANCE = 2
local MAX_LOG_REQUEST = 200 -- sanity cap, independent of what's actually on the map

local function OnClientCommand(module, command, player, args)
    if module ~= "WorkingBandsaw" then return end
    if command ~= "SawLogs" then return end
    if not player then return end

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
    if player:getZ() ~= square:getZ() then
        dbg(player:getUsername() .. " is on the wrong floor for that bandsaw")
        return
    end
    local dist = IsoUtils.DistanceTo(player:getX(), player:getY(), square:getX() + 0.5, square:getY() + 0.5)
    if dist > MAX_INTERACT_DISTANCE then
        dbg(player:getUsername() .. " is too far from that bandsaw (" .. tostring(dist) .. ")")
        return
    end

    -- Re-validate a real bandsaw is actually there.
    local foundBandsaw = false
    local objects = square:getObjects()
    if objects then
        for i = 0, objects:size() - 1 do
            if WorkingBandsaw.IsBandSaw(objects:get(i)) then
                foundBandsaw = true
                break
            end
        end
    end
    if not foundBandsaw then
        dbg(player:getUsername() .. " claimed a bandsaw that isn't there")
        return
    end

    -- Re-validate electricity server-side.
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

Events.OnClientCommand.Add(OnClientCommand)
