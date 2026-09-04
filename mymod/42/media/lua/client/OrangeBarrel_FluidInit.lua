OrangeBarrelFluid = OrangeBarrelFluid or {}
OrangeBarrelFluid.DEBUG = true

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
-- Utils
--------------------------------------------------

function OrangeBarrelFluid.IsOrangeBarrel(object)
    if not object then
        OBFLog("IsOrangeBarrel: object is nil")
        return false
    end

    local sprite = object.getSprite and object:getSprite() or nil
    if not sprite then
        OBFLog("IsOrangeBarrel: no sprite")
        return false
    end

    local spriteName = sprite.getName and sprite:getName() or nil
    if not spriteName then
        OBFLog("IsOrangeBarrel: sprite has no name")
        return false
    end

    OBFLog("IsOrangeBarrel: spriteName =", spriteName)

    return spriteName == "crafted_01_32"
        or spriteName == "location_military_generic_01_14"
        or spriteName == "location_military_generic_01_15"
        or spriteName == "location_military_generic_01_6"
        or spriteName == "location_military_generic_01_7"
        or spriteName == "industry_01_22"
        or spriteName == "industry_01_23"
end

local function isNotBroken(item)
    return item and (not item.isBroken or not item:isBroken())
end

-- GLOBAL wrench helper used by context + timed actions
function OrangeBarrelFluid.getPlayerWrench(playerObj)
    if not playerObj then
        OBFLog("getPlayerWrench: playerObj is nil")
        return nil
    end
    local inv = playerObj:getInventory()
    if not inv then
        OBFLog("getPlayerWrench: no inventory")
        return nil
    end
    local wrench = inv:getFirstTypeEvalRecurse("Base.PipeWrench", isNotBroken)
    OBFLog("getPlayerWrench: found wrench =", tostring(wrench))
    return wrench
end

--------------------------------------------------
-- Fluid component helpers
--------------------------------------------------

function OrangeBarrelFluid.HasFluidComponent(barrel)
    if not barrel then
        OBFLog("HasFluidComponent: barrel is nil")
        return false
    end

    -- Engine component check — must be OUR component, not another mod's
    -- (e.g. LG Extended Plumbing attaches its own FluidContainer to the
    -- same vanilla barrel sprites for its water network)
    local ok, res = pcall(function()
        if ComponentType and ComponentType.FluidContainer and barrel.hasComponent and barrel.getComponent then
            if barrel:hasComponent(ComponentType.FluidContainer) then
                local comp = barrel:getComponent(ComponentType.FluidContainer)
                if comp and comp.getContainerName then
                    return comp:getContainerName() == "OrangeBarrel"
                end
            end
        end
        return false
    end)

    if ok and res then
        OBFLog("HasFluidComponent: engine reports OUR fluid component present")
        return true
    elseif ok then
        OBFLog("HasFluidComponent: engine component present but NOT ours (or none)")
    end

    -- Fallback modData
    local md = barrel:getModData()
    if md and md.OB_IsFluidBarrel then
        OBFLog("HasFluidComponent: modData fallback true")
        return true
    end

    OBFLog("HasFluidComponent: no component, no modData flag")
    return false
end

local function tryAttachEngineFluidComponent(barrel)
    if not barrel then
        OBFLog("tryAttachEngineFluidComponent: barrel is nil")
        return false
    end

    if not ComponentType or not ComponentType.FluidContainer then
        OBFLog("tryAttachEngineFluidComponent: no ComponentType.FluidContainer")
        return false
    end

    local component = nil
    local okCreate, errCreate = pcall(function()
        component = ComponentType.FluidContainer:CreateComponent()
    end)
    if not okCreate or not component then
        OBFLog("tryAttachEngineFluidComponent: CreateComponent failed:", errCreate)
        return false
    end

    OBFLog("tryAttachEngineFluidComponent: component created:", tostring(component))

    pcall(function() component:setCapacity(200.0) end)
    pcall(function() component:setContainerName("OrangeBarrel") end)
    pcall(function() component:setInputLocked(false) end)
    pcall(function() component:setCanPlayerEmpty(true) end)

    -- ⭐ NEW: default fluid type
    if component.setFluidType then
        pcall(function() component:setFluidType("Gasoline") end)
    end

    local okAttach, errAttach = pcall(function()
        GameEntityFactory.AddComponent(barrel, true, component)
    end)
    if not okAttach then
        OBFLog("tryAttachEngineFluidComponent: AddComponent failed:", errAttach)
        return false
    end

    OBFLog("tryAttachEngineFluidComponent: component attached")

    pcall(function()
        if barrel.transmitCompleteItemToServer then
            barrel:transmitCompleteItemToServer()
        end
    end)

    return true
end

--------------------------------------------------
-- Add component
--------------------------------------------------

function OrangeBarrelFluid.AddFluidComponent(barrel)
    OBFLog("AddFluidComponent called, barrel =", tostring(barrel))

    if OrangeBarrelFluid.HasFluidComponent(barrel) then
        OBFLog("AddFluidComponent: already has component")
        return true
    end

    local engineOK = tryAttachEngineFluidComponent(barrel)
    if not engineOK then
        local md = barrel:getModData()
        md.OB_IsFluidBarrel = true
        md.OB_FluidCapacity = 200.0
        md.OB_FluidName = "OrangeBarrel"
        barrel:transmitModData()
        OBFLog("AddFluidComponent: fallback modData applied")
    end

    return true
end

--------------------------------------------------
-- Reset (modData only)
--------------------------------------------------

function OrangeBarrelFluid.RemoveFluidComponent(barrel)
    OBFLog("RemoveFluidComponent called [Test B + Safety Check], barrel =", tostring(barrel))

    if not barrel then
        OBFLog("RemoveFluidComponent: barrel is nil")
        return false
    end

    -- Get the FluidContainer component
    local comp = nil
    local okGet, errGet = pcall(function()
        if barrel.getComponent and ComponentType and ComponentType.FluidContainer then
            comp = barrel:getComponent(ComponentType.FluidContainer)
        end
    end)

    if not okGet then
        OBFLog("RemoveFluidComponent: getComponent errored:", errGet)
    elseif comp then
        OBFLog("RemoveFluidComponent: got FluidContainer component:", tostring(comp))
    else
        OBFLog("RemoveFluidComponent: no FluidContainer component found")
    end

    --------------------------------------------------
    -- SAFETY CHECK: Prevent reset if fluid > 0
    --------------------------------------------------
    if comp and comp.getAmount then
        local amount = comp:getAmount()
        OBFLog("RemoveFluidComponent: fluid amount =", tostring(amount))

        if amount > 0 then
            OBFLog("RemoveFluidComponent: ABORT — barrel not empty!")
            if isClient() then
                getPlayer():Say("Empty The Barrel Must Be Empty!")
            else
                print("[OrangeBarrelFluid] Empty The Barrel Must Be Empty!")
            end
            return false
        end
    end

    --------------------------------------------------
    -- Remove component using the ONLY working API
    --------------------------------------------------
    if comp then
        -- ⭐ NEW: clear fluid type before removal
        if comp and comp.setFluidType then
            pcall(function() comp:setFluidType("") end)
        end

        local okB, errB = pcall(function()
            GameEntityFactory.RemoveComponent(barrel, comp)
        end)
        if okB then
            OBFLog("RemoveFluidComponent: removed via GameEntityFactory.RemoveComponent")
        else
            OBFLog("RemoveFluidComponent: GameEntityFactory.RemoveComponent errored:", errB)
        end
    end

    --------------------------------------------------
    -- Clear fallback modData
    --------------------------------------------------
    local md = barrel:getModData()
    md.OB_IsFluidBarrel = nil
    md.OB_FluidCapacity = nil
    md.OB_FluidName = nil
    OBFLog("RemoveFluidComponent: cleared modData fallback")

    --------------------------------------------------
    -- Sync
    --------------------------------------------------
    pcall(function()
        if barrel.transmitCompleteItemToServer then
            barrel:transmitCompleteItemToServer()
        elseif barrel.transmitModData then
            barrel:transmitModData()
        end
    end)

    OBFLog("RemoveFluidComponent: sync OK")
    return true
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

        -- ⭐ NEW: auto-clear fluid type when empty
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
