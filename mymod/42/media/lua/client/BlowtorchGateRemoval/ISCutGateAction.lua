-- Blowtorch Gate Cutting - Production Version

ISCutGateAction = ISBaseTimedAction:derive("ISCutGateAction")

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
-- Validation
---------------------------------------------------------
function ISCutGateAction:isValid()
    return self.obj ~= nil and self.character ~= nil
end

---------------------------------------------------------
-- Update
---------------------------------------------------------
function ISCutGateAction:update()
    self.character:faceThisObject(self.obj)
    self.character:setMetabolicTarget(Metabolics.HeavyWork)
end

---------------------------------------------------------
-- Start
---------------------------------------------------------
function ISCutGateAction:start()
    -- Blowtorch
    self.torch = findItemRecursive(self.character:getInventory(), "BlowTorch")
    if self.torch then
        self.originalContainer = self.torch:getContainer()
    end

    -- Welding mask (clothing)
    local mask = findItemRecursive(self.character:getInventory(), "WeldingMask")
    if mask then
        self.character:setWornItem(mask:getBodyLocation(), mask)
    end

    -- Welding animation
    self:setActionAnim("BlowTorch")
    self:setOverrideHandModels(self.torch, nil)

    -- Sparks + stance
    self.character:reportEvent("EventBlowTorch")

    -- Sound
    self.sound = self.character:playSound("BlowTorch")
end

---------------------------------------------------------
-- Stop
---------------------------------------------------------
function ISCutGateAction:stop()
    ISBaseTimedAction.stop(self)
    if self.sound then
        self.character:stopOrTriggerSound(self.sound)
    end
end

---------------------------------------------------------
-- Perform
---------------------------------------------------------
function ISCutGateAction:perform()
    if self.sound then
        self.character:stopOrTriggerSound(self.sound)
    end

    -- Fuel
    if self.torch then
        self.torch:Use()
    end

    -- Remove gate
    self.square:transmitRemoveItemFromSquare(self.obj)
    self.square:RemoveTileObject(self.obj)

    -- Scrap metal drop (0–5)
    local dropCount = ZombRand(0, 6)
    for i = 1, dropCount do
        self.square:AddWorldInventoryItem("Base.ScrapMetal", 0, 0, 0)
    end

    -- Return blowtorch
    if self.torch and self.originalContainer then
        if self.torch:getContainer() ~= self.originalContainer then
            self.originalContainer:AddItem(self.torch)
        end
    end

    -- XP
    self.character:getXp():AddXP(Perks.MetalWelding, 5)

    ISBaseTimedAction.perform(self)
end

---------------------------------------------------------
-- Constructor
---------------------------------------------------------
function ISCutGateAction:new(character, square, obj, time)
    local o = ISBaseTimedAction.new(self, character)
    o.square = square
    o.obj = obj
    o.maxTime = time
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end