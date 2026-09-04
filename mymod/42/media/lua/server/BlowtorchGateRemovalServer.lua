-- Blowtorch Gate Removal - Server Authority

local GateSprites = {
    ["location_shop_mall_01_18"] = true,
    ["location_shop_mall_01_19"] = true,
}

---------------------------------------------------------
-- Recursive inventory search
---------------------------------------------------------
local function findItemRecursive(container, itemType)
    if not container then return nil end

    local item = container:getFirstType(itemType)
    if item then return item end

    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local obj = items:get(i)
        if obj:IsInventoryContainer() then
            local found = findItemRecursive(obj:getItemContainer(), itemType)
            if found then return found end
        end
    end

    return nil
end

---------------------------------------------------------
-- Gate detection
---------------------------------------------------------
local function isGateTile(obj)
    if not obj or not obj:getSprite() then return false end
    return GateSprites[obj:getSprite():getName()] == true
end

local function getGateObject(square)
    if not square then return nil end

    local objs = square:getObjects()
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if isGateTile(obj) then
            return obj
        end
    end

    return nil
end

---------------------------------------------------------
-- Requirement check (never trust the client's own validation)
---------------------------------------------------------
local function playerHasRequirements(player)
    local inv = player:getInventory()

    local torch = findItemRecursive(inv, "BlowTorch")
    local mask = findItemRecursive(inv, "WeldingMask")
    local level = player:getPerkLevel(Perks.MetalWelding)

    if not torch or not mask then return false end
    if level < 2 then return false end

    return true
end

---------------------------------------------------------
-- Proximity check
---------------------------------------------------------
local function playerIsNearSquare(player, square)
    local playerSquare = player:getSquare()
    if not playerSquare or not square then return false end
    if playerSquare:getZ() ~= square:getZ() then return false end

    local dx = math.abs(playerSquare:getX() - square:getX())
    local dy = math.abs(playerSquare:getY() - square:getY())
    return dx <= 1 and dy <= 1
end

---------------------------------------------------------
-- OnClientCommand handler
---------------------------------------------------------
local function OnClientCommand(module, command, player, args)
    if module ~= "BlowtorchGateRemoval" then return end
    if command ~= "cutGate" then return end

    if not player or not args or not args.x or not args.y or not args.z then
        print("[BlowtorchGateRemoval] Rejected: missing player or coordinates")
        return
    end

    local square = getCell():getGridSquare(args.x, args.y, args.z)
    if not square then
        print("[BlowtorchGateRemoval] Rejected: invalid square")
        return
    end

    if not playerIsNearSquare(player, square) then
        print("[BlowtorchGateRemoval] Rejected: " .. player:getUsername() .. " not near target square")
        return
    end

    local gateObj = getGateObject(square)
    if not gateObj then
        -- Already removed by another player, or bogus target
        print("[BlowtorchGateRemoval] Rejected: no gate object found (already removed?)")
        return
    end

    if not playerHasRequirements(player) then
        print("[BlowtorchGateRemoval] Rejected: " .. player:getUsername() .. " missing requirements")
        return
    end

    -- Remove gate server-side so it replicates to everyone
    square:transmitRemoveItemFromSquare(gateObj)
    square:RemoveTileObject(gateObj)

    -- Scrap metal drop (0-5)
    local dropCount = ZombRand(0, 6)
    for i = 1, dropCount do
        square:AddWorldInventoryItem("Base.ScrapMetal", 0, 0, 0)
    end

    print("[BlowtorchGateRemoval] Gate removed by " .. player:getUsername() .. " at " .. args.x .. "," .. args.y .. "," .. args.z)
end

Events.OnClientCommand.Add(OnClientCommand)