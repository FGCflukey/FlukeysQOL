-- Blowtorch Gate Removal - Production Version

BlowtorchGateRemoval = {}

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
-- Requirement check
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
-- Context menu hook
---------------------------------------------------------
function BlowtorchGateRemoval.onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    local player = getSpecificPlayer(playerNum)
    if not player then return end

    local currentSquare = player:getSquare()
    local facingSquare = currentSquare and currentSquare:getAdjacentSquare(player:getDir())

    local gateObj = getGateObject(currentSquare)
    if not gateObj and facingSquare then
        gateObj = getGateObject(facingSquare)
    end

    if gateObj and playerHasRequirements(player) then
        context:addOption("Cut Through Gate", worldobjects, BlowtorchGateRemoval.startCutting, player, player:getSquare(), gateObj)
    end
end

---------------------------------------------------------
-- Start timed action
---------------------------------------------------------
function BlowtorchGateRemoval.startCutting(worldobjects, player, square, gateObj)
    ISTimedActionQueue.add(ISCutGateAction:new(player, player:getSquare(), gateObj, 150))
end

Events.OnFillWorldObjectContextMenu.Add(BlowtorchGateRemoval.onFillWorldObjectContextMenu)