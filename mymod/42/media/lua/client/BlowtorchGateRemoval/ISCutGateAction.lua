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

    -- Welding mask (clothing) -- remembers whatever was worn in that
    -- slot before so it can be restored instead of just being dropped,
    -- and syncs the change so it doesn't desync from the server's view
    -- of the character (see restoreMask below for the other half of this).
    self.mask = findItemRecursive(self.character:getInventory(), "WeldingMask")
    if self.mask then
        self.maskLocation = self.mask:getBodyLocation()
        self.previousMask = self.character:getWornItem(self.maskLocation)
        self.character:setWornItem(self.maskLocation, self.mask)
        sendEquip(self.character)
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
-- Restore whatever was worn before we put the mask on
-- (called from both stop() and perform() so it's cleaned
-- up whether the action finishes or gets interrupted).
---------------------------------------------------------
function ISCutGateAction:restoreMask()
    if not self.mask or self.maskRestored then return end
    self.maskRestored = true

    if self.character:getWornItem(self.maskLocation) == self.mask then
        self.character:setWornItem(self.maskLocation, self.previousMask)
        sendEquip(self.character)
    end
end

---------------------------------------------------------
-- Stop
---------------------------------------------------------
function ISCutGateAction:stop()
    ISBaseTimedAction.stop(self)
    if self.sound then
        self.character:stopOrTriggerSound(self.sound)
    end
    self:restoreMask()
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

    -- Request server-authoritative gate removal (fixes MP desync)
    sendClientCommand(self.character, "BlowtorchGateRemoval", "cutGate", {
        x = self.square:getX(),
        y = self.square:getY(),
        z = self.square:getZ(),
    })

    -- Return blowtorch
    if self.torch and self.originalContainer then
        if self.torch:getContainer() ~= self.originalContainer then
            self.originalContainer:AddItem(self.torch)
        end
    end

    -- XP
    self.character:getXp():AddXP(Perks.MetalWelding, 5)

    self:restoreMask()

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