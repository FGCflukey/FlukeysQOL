if isClient() then return end

local function RP_log(msg)
    print("[RefillPropane-Server] " .. tostring(msg))
end

local function findItemById(playerObj, itemID)
    local candidates = RefillPropane.getAllRefillableItems(playerObj)
    for _, item in ipairs(candidates) do
        if item:getID() == itemID then
            return item
        end
    end
    return nil
end

local Commands = {}

function Commands.refill(player, args)
    local pumpObj = RefillPropane.findNearbyPump(player:getSquare())
    if not pumpObj then
        RP_log("rejected: no pump adjacent to " .. tostring(player:getUsername()))
        return
    end

    local item = findItemById(player, args.itemID)
    if not item then
        RP_log("rejected: item " .. tostring(args.itemID) .. " not found for " .. tostring(player:getUsername()))
        return
    end

    local max = item:getMaxUses()
    if not max then
        RP_log("rejected: item has no maxUses, type " .. tostring(item:getType()))
        return
    end

    item:setCurrentUses(max)
    item:syncItemFields()

    RP_log("refilled " .. tostring(item:getType()) .. " for " .. tostring(player:getUsername()))
end

local function OnClientCommand(module, command, player, args)
    if module ~= "RefillPropane" then return end
    if Commands[command] then
        Commands[command](player, args or {})
    end
end

Events.OnClientCommand.Add(OnClientCommand)