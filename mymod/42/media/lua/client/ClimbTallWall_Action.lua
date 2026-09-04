local ProtectedItems = {
    ["Base.HCHanddolly"] = true,
    ["Base.HCToywagon"] = true,
}

-- How many consecutive OnTick checks "not near fence" must hold true
-- before we restore the item. This prevents a single bad getDir()/turn
-- glitch from triggering a premature restore mid-climb.
local RESTORE_DEBOUNCE_TICKS = 8

-- Safety valve: if somehow the debounce condition never clears (e.g. an
-- edge case where isFenceNearby never resolves), force a restore after
-- this many ticks so the item can never be lost/stuck forever.
local MAX_TICKS_BEFORE_FORCE_RESTORE = 300 -- ~5 real seconds at 60 ticks/s, generous on purpose

---------------------------------------------------------
-- Helper: check if a single tile contains a fence
---------------------------------------------------------
local function isFenceTile(square, label)
    label = label or "UNKNOWN"

    if not square then
        return false
    end

    -- Check floor
    local floor = square:getFloor()
    if floor then
        local spr = floor:getSprite()
        if spr and spr.getName then
            local name = spr:getName()
            if name and name:sub(1, 7) == "fencing" then
                return true
            end
        end
    end

    -- Check objects
    local objects = square:getObjects()
    if objects then
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            if obj then
                local spr = obj:getSprite()
                if spr and spr.getName then
                    local name = spr:getName()
                    if name and name:sub(1, 7) == "fencing" then
                        return true
                    end
                end
            end
        end
    end

    return false
end

---------------------------------------------------------
-- Combined check: current tile OR any of the 4 adjacent tiles
--
-- IMPORTANT: this deliberately does NOT rely on player:getDir().
-- getDir() can lag or misreport for a tick while the character is
-- turning/moving fast, which was letting isFenceNearby() return
-- false at exactly the wrong moment (both on entry AND on restore).
-- Checking all 4 neighbours instead removes that race entirely.
---------------------------------------------------------
local function isFenceNearby(player)
    local square = player:getSquare()
    if not square then
        return false
    end

    if isFenceTile(square, "CURRENT") then
        return true
    end

    local x, y, z = square:getX(), square:getY(), square:getZ()
    local cell = getCell()

    local neighbours = {
        cell:getGridSquare(x,     y - 1, z), -- N
        cell:getGridSquare(x,     y + 1, z), -- S
        cell:getGridSquare(x + 1, y,     z), -- E
        cell:getGridSquare(x - 1, y,     z), -- W
    }

    for _, sq in ipairs(neighbours) do
        if isFenceTile(sq, "ADJACENT") then
            return true
        end
    end

    return false
end

---------------------------------------------------------
-- Key Press Handler (E)
---------------------------------------------------------
local function OnKeyPressed(key)
    if key ~= 18 then return end  -- Only E key

    local player = getPlayer()
    if not player then return end

    -- Already holding a protected item mid-sequence? Don't double-trigger.
    local md = player:getModData()
    if md.StoredPrimaryClimbItem or md.StoredSecondaryClimbItem then
        -- print("### E PRESSED WHILE ALREADY PROTECTING - SKIPPING RE-TRIGGER")
        return
    end

    if not isFenceNearby(player) then
        -- print("DEBUG: E pressed but no fence detected on current/adjacent tiles")
        return
    end

    local primary   = player:getPrimaryHandItem()
    local secondary = player:getSecondaryHandItem()

    if not secondary then
        -- print("DEBUG: No item in secondary hand")
        return
    end

    local fullType = secondary:getFullType()
    if not ProtectedItems[fullType] then
        -- print("DEBUG: Secondary item not protected:", fullType)
        return
    end

-- print("DEBUG: Protecting items: " .. primaryTypeStr .. " " .. secondaryTypeStr)

    local inv = player:getInventory()
    if not inv then
        -- print("DEBUG: No inventory found on player - aborting protection")
        return
    end

    -- Store both items + bookkeeping for the debounce/timeout logic
    md.StoredPrimaryClimbItem   = primary
    md.StoredSecondaryClimbItem = secondary
    md.ClimbNotNearFenceCount   = 0
    md.ClimbProtectionTickAge   = 0

    -- Unequip both
    player:setPrimaryHandItem(nil)
    player:setSecondaryHandItem(nil)

    -- Remove from inventory
    if primary then inv:Remove(primary) end
    inv:Remove(secondary)

    -- print("### PRE-CLIMB REMOVE:", fullType)
end

Events.OnKeyPressed.Add(OnKeyPressed)

---------------------------------------------------------
-- Restore items after climb (debounced)
---------------------------------------------------------
local function OnTick()
    local player = getPlayer()
    if not player then return end

    local md = player:getModData()
    local primary   = md.StoredPrimaryClimbItem
    local secondary = md.StoredSecondaryClimbItem

    if not primary and not secondary then return end

    md.ClimbProtectionTickAge = (md.ClimbProtectionTickAge or 0) + 1

    local nearFence = isFenceNearby(player)
    local forceRestore = md.ClimbProtectionTickAge >= MAX_TICKS_BEFORE_FORCE_RESTORE

    if forceRestore then
        print("### SAFETY TIMEOUT HIT - FORCING RESTORE REGARDLESS OF FENCE PROXIMITY")
    end

    if nearFence and not forceRestore then
        -- Still near a fence tile - reset the debounce counter and wait.
        md.ClimbNotNearFenceCount = 0
        return
    end

    md.ClimbNotNearFenceCount = (md.ClimbNotNearFenceCount or 0) + 1

    if md.ClimbNotNearFenceCount < RESTORE_DEBOUNCE_TICKS and not forceRestore then
        -- Not near a fence, but not consistently long enough yet - could
        -- still be a mid-turn glitch during the climb. Keep waiting.
        return
    end

    local inv = player:getInventory()
    if inv then
        if primary then
            inv:AddItem(primary)
            player:setPrimaryHandItem(primary)
            -- print("### RESTORED PRIMARY AFTER CLIMB:", primary:getFullType())
        end

        if secondary then
            inv:AddItem(secondary)
            player:setSecondaryHandItem(secondary)
            -- print("### RESTORED SECONDARY AFTER CLIMB:", secondary:getFullType())
        end
    else
        -- print("### ERROR: NO INVENTORY AVAILABLE TO RESTORE ITEMS INTO")
    end

    md.StoredPrimaryClimbItem   = nil
    md.StoredSecondaryClimbItem = nil
    md.ClimbNotNearFenceCount   = nil
    md.ClimbProtectionTickAge   = nil
end

Events.OnTick.Add(OnTick)

Events.OnGameStart.Add(function()
    print("### FENCE-CLIMB PROTECTION LOADED (hardened) ###")
end)