-- WorkingBandsaw_Shared.lua
-- Detection, electricity, and log-counting helpers shared by client and server.
--
-- Rebuilt from the "Industrial Saw Mod" Workshop mod (id 3702250114) after
-- reading its source turned up two real server-authority gaps: the server
-- trusted a client-supplied planks-per-log ratio outright, and never
-- re-validated that the player was actually near a real, powered bandsaw
-- before honoring a saw request. See WorkingBandsaw_Server.lua for the fix.

WorkingBandsaw = WorkingBandsaw or {}

-- The Metal Bandsaw entity's 4 real rotation sprites (confirmed against
-- entity_metalbandsaw.txt -- industry_02_264/265/266/267, one per facing).
local BANDSAW_SPRITES = {
    ["industry_02_264"] = true,
    ["industry_02_265"] = true,
    ["industry_02_266"] = true,
    ["industry_02_267"] = true,
}

--- Read a WorkingBandsaw sandbox option, falling back to a default if unset.
---@param name string
---@param default any
---@return any
function WorkingBandsaw.GetOption(name, default)
    local vars = SandboxVars and SandboxVars.WorkingBandsaw
    if vars and vars[name] ~= nil then return vars[name] end
    return default
end

--- Check if an object is the Metal Bandsaw.
---@param object IsoObject
---@return boolean
function WorkingBandsaw.IsBandSaw(object)
    if not object then return false end

    if object.getSprite then
        local sprite = object:getSprite()
        if sprite and sprite.getName then
            local name = sprite:getName()
            if name and BANDSAW_SPRITES[name] then
                return true
            end
        end
    end

    if object.getName then
        local objName = object:getName()
        if objName and string.find(string.lower(objName), "bandsaw") then
            return true
        end
    end

    return false
end

--- Check if a square has electricity, the same pcall-guarded way this pack's
--- PlayArcadeMachines feature does (haveElectricity can be unreliable across
--- square/building contexts, and the ambient-grid-day fallback matches
--- vanilla's own ISWeatherChannel/ElecShutModifier behavior).
---@param square IsoGridSquare
---@return boolean
function WorkingBandsaw.HasElectricity(square)
    if not square then return false end

    local ok, real = pcall(function() return square:haveElectricity() end)
    if ok and real then return true end

    local ok2, gridOn = pcall(function() return square:hasGridPower() end)
    if not (ok2 and gridOn) then return false end

    local ok3, stillOn = pcall(function()
        local shutoffDay = SandboxVars.ElecShutModifier or 14
        if shutoffDay <= -1 then return true end
        local elapsedDays = GameTime:getInstance():getWorldAgeHours() / 24
        return elapsedDays < shutoffDay
    end)
    return ok3 and stillOn
end

--- Count logs in a player's inventory only.
---@param player IsoPlayer
---@return number
function WorkingBandsaw.CountLogsInventory(player)
    if not player then return 0 end
    local inv = player:getInventory()
    if not inv then return 0 end
    local logs = inv:getItemsFromFullType("Base.Log")
    return logs and logs:size() or 0
end

--- Count logs on the ground within range of a square.
---@param square IsoGridSquare
---@param range number
---@return number
function WorkingBandsaw.CountLogsOnGround(square, range)
    if not square then return 0 end
    local count = 0
    local sx, sy, sz = square:getX(), square:getY(), square:getZ()

    for dx = -range, range do
        for dy = -range, range do
            local checkSquare = getCell():getGridSquare(sx + dx, sy + dy, sz)
            if checkSquare then
                local objects = checkSquare:getObjects()
                if objects then
                    for i = 0, objects:size() - 1 do
                        local obj = objects:get(i)
                        if obj and instanceof(obj, "IsoWorldInventoryObject") then
                            local item = obj:getItem()
                            if item and item:getFullType() == "Base.Log" then
                                count = count + 1
                            end
                        end
                    end
                end
            end
        end
    end

    return count
end

--- Count logs in containers (crates, vehicle parts, etc.) within range of a square.
---@param square IsoGridSquare
---@param range number
---@return number
function WorkingBandsaw.CountLogsInContainers(square, range)
    if not square then return 0 end
    local count = 0
    local sx, sy, sz = square:getX(), square:getY(), square:getZ()
    local processedContainers = {}

    for dx = -range, range do
        for dy = -range, range do
            local checkSquare = getCell():getGridSquare(sx + dx, sy + dy, sz)
            if checkSquare then
                local objects = checkSquare:getObjects()
                if objects then
                    for i = 0, objects:size() - 1 do
                        local obj = objects:get(i)
                        if obj and obj.getContainer then
                            local container = obj:getContainer()
                            if container and not processedContainers[container] then
                                processedContainers[container] = true
                                local logs = container:getItemsFromFullType("Base.Log")
                                if logs then count = count + logs:size() end
                            end
                        end
                    end
                end

                local vehicle = checkSquare:getVehicleContainer()
                if vehicle then
                    for partIndex = 0, vehicle:getPartCount() - 1 do
                        local part = vehicle:getPartByIndex(partIndex)
                        if part and part:getItemContainer() then
                            local container = part:getItemContainer()
                            if not processedContainers[container] then
                                processedContainers[container] = true
                                local logs = container:getItemsFromFullType("Base.Log")
                                if logs then count = count + logs:size() end
                            end
                        end
                    end
                end
            end
        end
    end

    return count
end

--- Count total logs (inventory + ground + containers) available to a player
--- at a square.
---@param player IsoPlayer
---@param square IsoGridSquare
---@param range number|nil
---@return number invCount, number groundCount, number containerCount, number totalCount
function WorkingBandsaw.CountLogs(player, square, range)
    range = range or WorkingBandsaw.GetOption("SearchRange", 5)
    local invCount = WorkingBandsaw.CountLogsInventory(player)
    local groundCount = square and WorkingBandsaw.CountLogsOnGround(square, range) or 0
    local containerCount = square and WorkingBandsaw.CountLogsInContainers(square, range) or 0
    return invCount, groundCount, containerCount, invCount + groundCount + containerCount
end
