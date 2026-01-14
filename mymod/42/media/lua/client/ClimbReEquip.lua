------------------------------------------------------------
-- WINDOW CLIMB
------------------------------------------------------------
local originalWindowPerform = ISClimbThroughWindow.perform

function ISClimbThroughWindow:perform()
    local player = self.character
    local primary = player:getPrimaryHandItem()
    local secondary = player:getSecondaryHandItem()

    if primary and primary:IsInventoryContainer() then
        player:removeFromHands(primary)
    end
    if secondary and secondary:IsInventoryContainer() then
        player:removeFromHands(secondary)
    end

    originalWindowPerform(self)

    if primary then player:setPrimaryHandItem(primary) end
    if secondary then player:setSecondaryHandItem(secondary) end
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

        if primary and primary:IsInventoryContainer() then
            player:removeFromHands(primary)
        end
        if secondary and secondary:IsInventoryContainer() then
            player:removeFromHands(secondary)
        end

        originalFencePerform(self)

        if primary then player:setPrimaryHandItem(primary) end
        if secondary then player:setSecondaryHandItem(secondary) end
    end
end