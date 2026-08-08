--[[
    Repairable Gloveboxes & Heaters
    Server handler for the heater-repair client command.

    The client has already validated the player's skills, materials, and
    tooling before sending us the message — we just apply the effects and
    sync them back. The work is broken into small pure helpers so the
    handler body reads top-to-bottom as a sequence of steps.
]]

if isClient() then return end

local NET_MODULE = "QOL_vehicle"

----------------------------------------------------------------
-- Utility helpers
----------------------------------------------------------------

-- Try a list of "getters" against a list of subjects until one returns a
-- positive number. Pulls the conditionMax from either the part or
-- its installed inventory item, whichever exposes the API.
local function firstPositive(subjects, methodName, fallback)
    for s = 1, #subjects do
        local subject = subjects[s]
        local fn      = subject and subject[methodName]
        if fn then
            local ok, value = pcall(fn, subject)
            if ok and type(value) == "number" and value > 0 then
                return value
            end
        end
    end
    return fallback
end

local function maxConditionOf(part)
    if part == nil then return 100 end
    return firstPositive({ part, part:getInventoryItem() }, "getConditionMax", 100)
end

-- Drain `amount` uses from whatever drainable the player is currently
-- holding. Stops early if the item exhausted.
local function drainHeldDrainable(player, amount)
    local held = player:getPrimaryHandItem()
    if held == nil or held.Use == nil then
        held = player:getSecondaryHandItem()
    end
    if held == nil or held.Use == nil then return end

    for _ = 1, amount do
        local lo = held.getCurrentUses      and held:getCurrentUses()
                or held.getDrainableUsesInt and held:getDrainableUsesInt()
                or 0
        if lo <= 0 then break end
        held:Use()
    end

    if held.syncItemFields then held:syncItemFields() end
end

-- Pull `count` instances of `fullType` out of the player's inventory
-- (recursively, including sub-bags), removing each through its actual
-- container so the client mirrors the change.
local function consumeFromInventory(player, fullType, count)
    if count == nil or count < 1 then return end

    local inv = player:getInventory()
    if inv == nil then return end

    local pool = ArrayList.new()
    inv:getAllTypeRecurse(fullType, pool)

    local removed = 0
    for idx = 0, pool:size() - 1 do
        if removed >= count then break end

        local item       = pool:get(idx)
        local home       = item and item:getContainer()
        if home then
            home:Remove(item)
            if sendRemoveItemFromContainer then
                sendRemoveItemFromContainer(home, item)
            end
            removed = removed + 1
        end
    end
end

-- Grant the same amount of XP to both perks. addXp is a server-side
-- helper that exists on most builds; fall back to PerkFactory direct
-- calls if it's missing.
local function grantPerkXp(player, perkList, amount)
    if amount == nil or amount <= 0 or player == nil then return end

    if addXp ~= nil then
        for i = 1, #perkList do
            addXp(player, perkList[i], amount)
        end
        return
    end

    local xps = player.getXp and player:getXp()
    if xps == nil or xps.AddXP == nil then return end
    for i = 1, #perkList do
        xps:AddXP(perkList[i], amount)
    end
end

-- B42.14+ replaced the magic string "mechanicActionDone" with an enum
-- constant on IsoObjectChange. Detect at call time so the same file
-- works on 42.0–42.13, 42.14+, and B41.
local function mechanicActionDoneKey()
    if IsoObjectChange and IsoObjectChange.MECHANIC_ACTION_DONE then
        return IsoObjectChange.MECHANIC_ACTION_DONE
    end
    return "mechanicActionDone"
end

----------------------------------------------------------------
-- Step functions
----------------------------------------------------------------

local function applyConditionTo(part, requested)
    local cap   = maxConditionOf(part)
    local final = math.min(cap, tonumber(requested) or cap)
    part:setCondition(final)

    local installed = part:getInventoryItem()
    if installed then
        if installed.setCondition  then installed:setCondition(final) end
        if installed.syncItemFields then installed:syncItemFields()    end
    end
end

local function consumeMaterials(player, materialMap)
    if type(materialMap) ~= "table" then return end
    for fullType, quantity in pairs(materialMap) do
        consumeFromInventory(player, fullType, tonumber(quantity) or 0)
    end
end

local function broadcastPartChange(vehicle, part)
    vehicle:updatePartStats()
    vehicle:updateBulletStats()
    vehicle:transmitPartCondition(part)
    vehicle:transmitPartItem(part)
    vehicle:transmitPartModData(part)
end

local function notifyMenuComplete(player, vehicle, part)
    player:sendObjectChange(mechanicActionDoneKey(), {
        success    = true,
        vehicleId  = vehicle:getId(),
        partId     = part:getId(),
        itemId     = -1,
        installing = true,
    })
end

----------------------------------------------------------------
-- Command dispatch table
----------------------------------------------------------------
local Commands = {}

function Commands.repairHeater(player, args)
    if args == nil then return end

    local vehicle = getVehicleById(args.vehicle)
    if vehicle == nil then return end

    local part = vehicle:getPartById("Heater")
    if part == nil then return end

    applyConditionTo(part, args.targetCondition)
    consumeMaterials(player, args.repairParts)
    drainHeldDrainable(player, 10)
    broadcastPartChange(vehicle, part)
    grantPerkXp(player, { Perks.MetalWelding, Perks.Mechanics }, ZombRand(3, 6))
    notifyMenuComplete(player, vehicle, part)
end

----------------------------------------------------------------
-- Wire up the network listener
----------------------------------------------------------------
local function onClientCommand(module, command, player, args)
    if module ~= NET_MODULE then return end
    local handler = Commands[command]
    if handler == nil then return end
    handler(player, args or {})
end

Events.OnClientCommand.Add(onClientCommand)
