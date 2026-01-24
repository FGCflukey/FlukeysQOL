-- RefillPropane.lua
-- Single-file implementation: context menu + timed action + refill logic
-- Author: Tom & Copilot (Production Version, Recursive + Auto-Return)

-------------------------------------------------
-- Minimal Debug Helper (only critical logs)
-------------------------------------------------

local function RP_log(msg)
    print("[RefillPropane] " .. tostring(msg))
end

-------------------------------------------------
-- Pump detection
-------------------------------------------------

local function isPropanePumpObject(obj)
    if not obj then return false end
    local sprite = obj:getSprite()
    if not sprite then return false end

    local name = sprite:getName() or ""
    local lower = string.lower(name)

    return
        string.find(lower, "shop_fossoil_01", 1, true) or
        string.find(lower, "shop_gas2go_01", 1, true)
end

local function getPropanePump(square)
    if not square then return nil end

    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        if isPropanePumpObject(objects:get(i)) then
            return objects:get(i)
        end
    end

    return nil
end

-- Vanilla-style: search adjacent squares too
local function findNearbyPump(square)
    for dx = -1, 1 do
        for dy = -1, 1 do
            local sq = getCell():getGridSquare(square:getX()+dx, square:getY()+dy, square:getZ())
            if sq then
                local pump = getPropanePump(sq)
                if pump then return pump end
            end
        end
    end
    return nil
end

-------------------------------------------------
-- Adjacency check
-------------------------------------------------

local function isAdjacentToSquare(playerObj, targetSquare)
    if not playerObj or not targetSquare then return false end
    return playerObj:getSquare():isAdjacentTo(targetSquare)
end

-------------------------------------------------
-- Recursive inventory search
-------------------------------------------------

local function collectRefillableItemsRecursive(container, results)
    if not container then return end

    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)

        -- Blowtorch
        if item:getType() == "BlowTorch"
        and instanceof(item, "Drainable")
        and item:getCurrentUses() < item:getMaxUses() then
            table.insert(results, item)
        end

        -- Propane Tank
        if item:getType() == "PropaneTank"
        and instanceof(item, "Drainable")
        and item:getCurrentUses() < item:getMaxUses() then
            table.insert(results, item)
        end

        -- Nested container
        if item:IsInventoryContainer() then
            collectRefillableItemsRecursive(item:getItemContainer(), results)
        end
    end
end

local function getAllRefillableItems(playerObj)
    local results = {}
    collectRefillableItemsRecursive(playerObj:getInventory(), results)
    return results
end

-------------------------------------------------
-- Refill logic
-------------------------------------------------

local function refillItem(item)
    if not item then
        RP_log("ERROR: refillItem called with nil item")
        return
    end

    local max = item:getMaxUses()
    if not max then
        RP_log("ERROR: item has no maxUses:", item:getType())
        return
    end

    item:setCurrentUses(max)
end

-------------------------------------------------
-- Timed action
-------------------------------------------------

ISRefillPropaneAction = ISBaseTimedAction:derive("ISRefillPropaneAction")

function ISRefillPropaneAction:isValid()
    if not self.item or not self.pumpObj then
        return false
    end

    if not self.pumpObj:getSquare() then
        return false
    end

    return isAdjacentToSquare(self.character, self.pumpObj:getSquare())
end

function ISRefillPropaneAction:update()
    self.item:setJobDelta(self:getJobDelta())

    if self.sound ~= 0 and not self.character:getEmitter():isPlaying(self.sound) then
        self.sound = self.character:playSound("BlowTorch")
    end
end

function ISRefillPropaneAction:start()
    RP_log("TimedAction START: " .. self.item:getType())

    self.item:setJobType("Refilling")
    self.item:setJobDelta(0.0)

    -- Store original container for auto-return
    self.originalContainer = self.item:getContainer()

    self:setActionAnim("Loot")
    self:setOverrideHandModels(self.item, nil)
    self.character:SetVariable("LootPosition", "Mid")

    self.character:faceThisObject(self.pumpObj)
    self.sound = self.character:playSound("VehicleAddFuelFromGasPump")
end

function ISRefillPropaneAction:stop()
    RP_log("TimedAction STOP: " .. self.item:getType())

    if self.sound ~= 0 then
        self.character:getEmitter():stopSound(self.sound)
    end

    self.item:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function ISRefillPropaneAction:perform()
    RP_log("TimedAction PERFORM: " .. self.item:getType())

    if self.sound ~= 0 then
        self.character:getEmitter():stopSound(self.sound)
    end

    self.item:setJobDelta(0.0)
    refillItem(self.item)

    -- Auto-return to original container
    if self.originalContainer
    and self.item:getContainer() ~= self.originalContainer then
        self.originalContainer:AddItem(self.item)
    end

    ISBaseTimedAction.perform(self)
end

function ISRefillPropaneAction:new(playerObj, item, pumpObj)
    local o = ISBaseTimedAction.new(self, playerObj)
    o.item = item
    o.pumpObj = pumpObj
    o.maxTime = 600
    o.stopOnWalk = true
    o.stopOnRun = true
    o.useProgressBar = true
    return o
end

-------------------------------------------------
-- Context menu hook
-------------------------------------------------

local function RP_onFillWorldObjectContextMenu(player, context, worldobjects, test)
    if test then return end

    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end

    local firstObj = worldobjects[1]
    local square = firstObj and firstObj:getSquare()
    if not square then return end

    local pumpObj = findNearbyPump(square)
    if not pumpObj then return end

    if not isAdjacentToSquare(playerObj, pumpObj:getSquare()) then
        RP_log("Player not adjacent to propane pump")
        return
    end

    -- Recursive search for refillable items
    local refillables = getAllRefillableItems(playerObj)
    if #refillables == 0 then
        RP_log("No refillable blowtorch or propane tank found")
        return
    end

    -- Add one option per refillable item
    for _, item in ipairs(refillables) do
        local optionText = "Refill " .. item:getName()

        context:addOption(
            optionText,
            worldobjects,
            function()
                ISTimedActionQueue.add(ISRefillPropaneAction:new(playerObj, item, pumpObj))
            end
        )
    end
end

Events.OnFillWorldObjectContextMenu.Add(RP_onFillWorldObjectContextMenu)