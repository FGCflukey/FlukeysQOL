------------------------------------------------------------
-- WINDOW CLIMB
------------------------------------------------------------
local originalWindowPerform = ISClimbThroughWindow.perform

function ISClimbThroughWindow:perform()
    local player = self.character
    local primary = player:getPrimaryHandItem()
    local secondary = player:getSecondaryHandItem()

    -- setXHandItem(nil) rather than removeFromHands(item): removeFromHands
    -- re-evaluates whether the item still fits in normal inventory capacity
    -- once unequipped and, if not (e.g. a WeightReduction container like the
    -- Hand Dolly/Toy Wagon, whose true weight only applies while unequipped),
    -- can leave it needing to be dropped to the world instead of restored --
    -- confirmed via vanilla's own ISTransferAction.lua, which names that
    -- return value "addToWorld". setXHandItem(nil) just clears the hand-slot
    -- reference; the item stays exactly where it already was in the backing
    -- inventory container the whole time, so there's nothing to drop.
    if primary and primary:IsInventoryContainer() then
        player:setPrimaryHandItem(nil)
    end
    if secondary and secondary:IsInventoryContainer() then
        player:setSecondaryHandItem(nil)
    end

    originalWindowPerform(self)

    if primary then player:setPrimaryHandItem(primary) end
    if secondary then player:setSecondaryHandItem(secondary) end
    if primary or secondary then sendEquip(player) end
end

------------------------------------------------------------
-- SHORT FENCE CLIMB
------------------------------------------------------------
if ISClimbOverFence then
    local originalFencePerform = ISClimbOverFence.perform

    function ISClimbOverFence:perform()
        local player = self.character
        local primary = player:getPrimaryHandItem()
        local secondary = player:getSecondaryHandItem()

        -- See the matching comment in ISClimbThroughWindow:perform() above --
        -- setXHandItem(nil), not removeFromHands(item).
        if primary and primary:IsInventoryContainer() then
            player:setPrimaryHandItem(nil)
        end
        if secondary and secondary:IsInventoryContainer() then
            player:setSecondaryHandItem(nil)
        end

        originalFencePerform(self)

        if primary then player:setPrimaryHandItem(primary) end
        if secondary then player:setSecondaryHandItem(secondary) end
        if primary or secondary then sendEquip(player) end
    end
end