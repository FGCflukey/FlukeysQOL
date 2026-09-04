require "OrangeBarrelFluid_Shared"

local function OBFLog(...)
    if not OrangeBarrelFluid.DEBUG then return end
    print("[OrangeBarrelFluid]", ...)
end

-- Shared label helper
local function OB_GetConvertLabel()
    local txt = getText("ContextMenu_ConvertToFluidBarrel")
    if not txt or txt == "" or txt == "ContextMenu_ConvertToFluidBarrel" then
        return "Open Barrel"
    end
    return txt
end

local function OB_GetResetLabel()
    return "Reset Barrel"
end

--------------------------------------------------
-- Context menu
--------------------------------------------------

function OrangeBarrelFluid.OnFillWorldObjectContextMenu(player, context, worldobjects)
    OBFLog("OnFillWorldObjectContextMenu called, player =", tostring(player))

    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end

    local targetBarrel = nil

    for _, object in ipairs(worldobjects) do
        if OrangeBarrelFluid.IsOrangeBarrel(object) then
            targetBarrel = object
            break
        end
    end

    if not targetBarrel then
        OBFLog("OnFillWorldObjectContextMenu: no suitable barrel found")
        return
    end

    local wrench = OrangeBarrelFluid.getPlayerWrench(playerObj)

    if not OrangeBarrelFluid.HasFluidComponent(targetBarrel) then
        local label = OB_GetConvertLabel()

        if not wrench then
            local option = context:addOption(label, nil)
            option.notAvailable = true

            -- Tooltip (Option B)
            local tooltip = ISToolTip:new()
            tooltip:initialise()
            tooltip.description = "Requires Pipe Wrench"
            option.toolTip = tooltip

            return
        end

        context:addOption(label, playerObj, OrangeBarrelFluid.OnConvertBarrel, targetBarrel)
        return
    end

    local resetLabel = OB_GetResetLabel()

    if not wrench then
        local option = context:addOption(resetLabel, nil)
        option.notAvailable = true

        -- Tooltip (Option B)
        local tooltip = ISToolTip:new()
        tooltip:initialise()
        tooltip.description = "Requires Pipe Wrench"
        option.toolTip = tooltip

        return
    end

    context:addOption(resetLabel, playerObj, OrangeBarrelFluid.OnResetBarrel, targetBarrel)
end

--------------------------------------------------
-- Reset handler
--------------------------------------------------

function OrangeBarrelFluid.OnResetBarrel(playerObj, barrel)
    OBFLog("OnResetBarrel called")

    if not playerObj or not barrel then return end
    if not barrel:getSquare() then return end

    local wrench = OrangeBarrelFluid.getPlayerWrench(playerObj)
    if not wrench then
        playerObj:Say("I need a pipe wrench to reset this barrel.") -- Option B
        return
    end

    -- SAFETY CHECK BEFORE QUEUING ACTION
    local comp = nil
    local okGet = pcall(function()
        if barrel.getComponent and ComponentType and ComponentType.FluidContainer then
            comp = barrel:getComponent(ComponentType.FluidContainer)
        end
    end)

    if okGet and comp and comp.getAmount then
        local amount = comp:getAmount()
        if amount > 0 then
            playerObj:Say("Empty The Barrel Must Be Empty!")
            return
        end
    end

    if not luautils.walkAdj(playerObj, barrel:getSquare()) then return end

    ISTimedActionQueue.add(OB_ResetBarrelAction:new(playerObj, barrel, wrench))
end

--------------------------------------------------
-- Convert handler
--------------------------------------------------

function OrangeBarrelFluid.OnConvertBarrel(playerObj, barrel)
    OBFLog("OnConvertBarrel called")

    if not playerObj or not barrel then return end
    if not barrel:getSquare() then return end

    local wrench = OrangeBarrelFluid.getPlayerWrench(playerObj)
    if not wrench then
        playerObj:Say("I need a pipe wrench to open this barrel.") -- Option B
        return
    end

    if not luautils.walkAdj(playerObj, barrel:getSquare()) then return end

    ISTimedActionQueue.add(OB_ConvertBarrelAction:new(playerObj, barrel, wrench, true))
end

--------------------------------------------------
-- RIGHT-CLICK Barrel Info Tooltip (REPLACES unsupported hover tooltip)
--------------------------------------------------

Events.OnPreFillWorldObjectContextMenu.Add(function(player, context, worldobjects)
    -- Find the barrel
    local barrel = nil
    for _, obj in ipairs(worldobjects) do
        if OrangeBarrelFluid.IsOrangeBarrel(obj) then
            barrel = obj
            break
        end
    end
    if not barrel then return end

    -- Build tooltip text
    local comp = nil
    local okGet = pcall(function()
        if barrel.getComponent and ComponentType and ComponentType.FluidContainer then
            comp = barrel:getComponent(ComponentType.FluidContainer)
        end
    end)

    local text = "Empty Barrel"
    if comp then
        local amount = comp.getAmount and comp:getAmount() or 0

        -- auto-clear fluid type when empty
        if amount <= 0 then
            if comp and comp.setFluidType then
                pcall(function() comp:setFluidType("") end)
            end
        end

        local capacity = comp.getCapacity and comp:getCapacity() or 200
        local fluid = comp.getFluidType and comp:getFluidType() or "Unknown"

        if amount <= 0 then
            text = "Empty Barrel"
        else
            text = fluid .. " (" .. tostring(amount) .. " / " .. tostring(capacity) .. ")"
        end
    end

    -- Add tooltip to context menu
    local infoOption = context:addOption("Barrel Info", nil)
    local tooltip = ISToolTip:new()
    tooltip:initialise()
    tooltip.description = text
    infoOption.toolTip = tooltip
end)

--------------------------------------------------
-- Event hook
--------------------------------------------------

Events.OnFillWorldObjectContextMenu.Add(OrangeBarrelFluid.OnFillWorldObjectContextMenu)

OBFLog("Orange Barrel Fluid Storage Mod (debug build) loaded!")
