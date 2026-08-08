-- Repairable Gloveboxes & Heaters (barebones)
-- Adds heater repair option + restores glovebox fixing recipes.

require "Vehicles/ISUI/ISVehicleMechanics"
require "QOL/HeaterRepairAction"
require "ISUI/ISInventoryPaneContextMenu"

------------------------------------------------------------
-- Restore glovebox fixing recipes (replaces FixingMenuFilter.lua)
------------------------------------------------------------
local originalBuildFixingMenu = ISInventoryPaneContextMenu.buildFixingMenu

ISInventoryPaneContextMenu.buildFixingMenu = function(broken, player, fixing, fixingNum, fixOption, subMenuFix, vehiclePart)
    if vehiclePart and vehiclePart:getId() == "GloveBox" then
        return originalBuildFixingMenu(broken, player, fixing, fixingNum, fixOption, subMenuFix, vehiclePart)
    end
    return originalBuildFixingMenu(broken, player, fixing, fixingNum, fixOption, subMenuFix, vehiclePart)
end

------------------------------------------------------------
-- Heater repair constants
------------------------------------------------------------
local previousPartContextMenu = ISVehicleMechanics.doPartContextMenu

local SHEET_METAL_TYPE        = "Base.SmallSheetMetal"
local BLOWTORCH_TYPE          = "Base.BlowTorch"
local WELDING_MASK_TYPE       = "Base.WeldingMask"
local SHEET_METAL_NEEDED      = 3
local CONDITION_PER_REPAIR    = 34

------------------------------------------------------------
-- Recursive inventory helpers (search ALL bags)
------------------------------------------------------------
local function findBlowtorch(inv)
    if not inv then return nil end
    return inv:getFirstTypeRecurse("Base.BlowTorch")
end

local function findMask(inv)
    if not inv then return nil end
    return inv:getFirstTypeRecurse("Base.WeldingMask")
end

local function countSheetMetal(container)
    if not container then return 0 end

    local count = container:getItemCount("Base.SmallSheetMetal")
    local items = container:getItems()

    for i = 0, items:size() - 1 do
        local obj = items:get(i)
        if obj:IsInventoryContainer() then
            count = count + countSheetMetal(obj:getItemContainer())
        end
    end

    return count
end

local function getMaxCondition(part)
    if part.getConditionMax then
        return part:getConditionMax()
    end
    return 100
end

------------------------------------------------------------
-- Heater repair option (uses overlay context menu)
------------------------------------------------------------
local function addHeaterRepairOption(self, part)
    if not part or part:getId() ~= "Heater" then return end

    local context = self.context
    if not context then return end

    local playerObj = getSpecificPlayer(self.playerNum or 0)
    if not playerObj then return end

    local inv = playerObj:getInventory()
    if not inv then return end

    local currentCond = part:getCondition()
    local maxCond     = getMaxCondition(part)

    if currentCond >= maxCond then return end

    local blowtorch = findBlowtorch(inv)
    local mask      = findMask(inv)
    local sheets    = countSheetMetal(inv)

    local hasTorch  = blowtorch ~= nil
    local hasMask   = mask ~= nil
    local hasSheets = sheets >= SHEET_METAL_NEEDED

    local targetCond = math.min(maxCond, currentCond + CONDITION_PER_REPAIR)

    local label = getText("ContextMenu_Repair") .. " " .. getText("IGUI_VehiclePartHeater")

    if context.options then
        for _, option in ipairs(context.options) do
            if option.name == label then return end
        end
    end

    local option = context:addOption(label, part, function(_, player, part, blowtorch, mask, targetCond)
        local mats = { SmallSheetMetal = SHEET_METAL_NEEDED }
        local duration = 1500

        player:faceThisObject(part:getVehicle())

        ISTimedActionQueue.add(
            QOLHeaterRepairAction:new(player, part, blowtorch, mask, duration, mats, targetCond)
        )
    end, playerObj, part, blowtorch, mask, targetCond)

    if not (hasTorch and hasMask and hasSheets) then
        option.notAvailable = true

        local tooltip = ISToolTip:new()
        tooltip:initialise()
        tooltip:setVisible(false)

        local desc = "Needs: <LINE> <LINE>"

        local function row(ok, text)
            local color = ok and " <RGB:0,1,0>" or " <RGB:1,0,0>"
            desc = desc .. color .. text .. " <LINE>"
        end

        row(hasTorch,  "Blowtorch (10+ uses)")
        row(hasMask,   "Welding Mask")
        row(hasSheets, "Small Sheet Metal " .. tostring(sheets) .. "/" .. tostring(SHEET_METAL_NEEDED))

        tooltip.description = desc
        option.toolTip = tooltip
    end
end

------------------------------------------------------------
-- GloveBox repair affordance (original mod logic)
------------------------------------------------------------
local function refreshGloveBoxAffordance(part)
    if part == nil or part:getId() ~= "GloveBox" then return end

    local installed = part:getInventoryItem()
    if installed == nil then return end

    local list = FixingManager.getFixes(installed)
    if list == nil or list:isEmpty() then return end

    local script = part:getScriptPart()
    if script == nil then return end

    local cond = part:getCondition()
    if cond < 100 and not script:isRepairMechanic() then
        script:setRepairMechanic(true)
    elseif cond >= 100 and script:isRepairMechanic() then
        script:setRepairMechanic(false)
    end
end

------------------------------------------------------------
-- Main part context menu override
------------------------------------------------------------
function ISVehicleMechanics:doPartContextMenu(part, x, y)
    refreshGloveBoxAffordance(part)

    if previousPartContextMenu then
        previousPartContextMenu(self, part, x, y)
    end

    addHeaterRepairOption(self, part)
end
