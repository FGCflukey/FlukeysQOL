-- ClothingBreakdown_Action.lua

-- require "TimedActions.ISBaseTimedAction"
-- require "ClothingBreakdown_Definitions"
-- require "ClothingBreakdown_Material"

local BaseAction   = ISBaseTimedAction
local Definitions  = ClothingBreakdown_Definitions
local Material     = ClothingBreakdown_Material

print("DEBUG: ClothingBreakdown_Action.lua LOADED")

ClothingBreakdownAction = ISBaseTimedAction:derive("ClothingBreakdownAction")

-------------------------------------------------
-- VALIDATION
-------------------------------------------------
function ClothingBreakdownAction:isValid()
    if not self.item then return false end

    -- Block equipped items (never recycle worn clothing)
    if self.character:isEquipped(self.item) then
        return false
    end

    -- Allow items in ANY player-owned container
    if self.character:getInventory():containsRecursive(self.item) then
        return true
    end

    -- Allow world items (cupboards, floor, crates, etc.)
    return true
end

-------------------------------------------------
-- UPDATE
-------------------------------------------------
function ClothingBreakdownAction:update()
    self.item:setJobDelta(self:getJobDelta())
end

-------------------------------------------------
-- START
-------------------------------------------------
function ClothingBreakdownAction:start()
    -- Auto-transfer world items into player inventory
    if self.item:getWorldItem() then
        self.item:getWorldItem():getSquare():transmitRemoveItemFromSquare(self.item:getWorldItem())
        self.item:setWorldItem(nil)
    end

    self.character:getInventory():AddItem(self.item)

    self.item:setJobType("Recycling")
    self.item:setJobDelta(0.0)
    self:setActionAnim("RipSheets")

    -- *** PLAY SOUND ***
    self.sound = self.character:playSound("ClothesRipping")
end

-------------------------------------------------
-- STOP
-------------------------------------------------
function ClothingBreakdownAction:stop()
    ISBaseTimedAction.stop(self)
    self.item:setJobDelta(0.0)

    -- Stop sound if still playing
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
end

-------------------------------------------------
-- PERFORM
-------------------------------------------------
function ClothingBreakdownAction:perform()
    if not self.item then
        print("ERROR: ClothingBreakdownAction missing item reference")
        ISBaseTimedAction.perform(self)
        return
    end

    -- Stop sound if still playing
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end

    local fullType = self.item:getFullType()
    print("DEBUG FULLTYPE:", fullType)

    self.item:setJobDelta(0.0)

    -- Item-specific override
    local def = ClothingBreakdown[fullType]

    -- Category fallback
    if not def then
        local rawBodyLoc = self.item:getBodyLocation()
        local bodyLoc = rawBodyLoc and tostring(rawBodyLoc):lower() or nil
        def = ClothingBreakdown[bodyLoc]
    end

    if def then
        -- Material detection (override → name → fallback)
        local material = ClothingBreakdown_Material.detect(self.item, def.material)

        local returns

        -- Item override: single returns table
        if def.returns.item then
            returns = def.returns
        else
            -- Category: multi-material returns
            returns = def.returns[material] or def.returns.cotton
        end

        if not returns then
            print("ERROR: No valid returns table for material:", material)
            ISBaseTimedAction.perform(self)
            return
        end

        local result = returns.item
        local min = returns.min
        local max = returns.max
        local amount = ZombRand(min, max + 1)

        for i = 1, amount do
            self.character:getInventory():AddItem(result)
        end
    else
        print("ERROR: No definition found for item or category")
    end

    -- Remove original item
    self.character:getInventory():Remove(self.item)

    ISBaseTimedAction.perform(self)
end

-------------------------------------------------
-- CONSTRUCTOR
-------------------------------------------------
function ClothingBreakdownAction:new(character, item, time)
    local o = ISBaseTimedAction.new(self, character)

    o.character = character
    o.item = item
    o.maxTime = time or 80

    o.stopOnWalk = true
    o.stopOnRun = true
    o.forceProgressBar = true

    return o
end