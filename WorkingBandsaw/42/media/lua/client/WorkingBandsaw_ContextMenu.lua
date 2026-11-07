-- WorkingBandsaw_ContextMenu.lua
-- Context menu + client-side timed action for sawing logs into planks at
-- the Metal Bandsaw. This file only ever decides what to SHOW and when to
-- SEND a request -- every number that actually matters (plank ratio, search
-- range, and whether the request is even legitimate) is re-decided
-- server-side in WorkingBandsaw_Server.lua.

require "WorkingBandsaw_Shared"
require "ISUI/ISWorldObjectContextMenu"
require "TimedActions/ISBaseTimedAction"

WorkingBandsaw.SawAction = ISBaseTimedAction:derive("WorkingBandsaw.SawAction")

function WorkingBandsaw.SawAction:new(player, bandsaw, square, logCount)
    local o = ISBaseTimedAction.new(self, player)

    o.bandsaw = bandsaw
    o.square = square
    o.logCount = logCount

    local ticksPerLog = WorkingBandsaw.GetOption("TicksPerLog", 40)
    o.maxTime = ticksPerLog * logCount
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = false

    return o
end

function WorkingBandsaw.SawAction:isValid()
    if not self.bandsaw or not self.square then return false end
    if not WorkingBandsaw.HasElectricity(self.square) then return false end
    local _, _, _, totalCount = WorkingBandsaw.CountLogs(self.character, self.square)
    return totalCount >= 1
end

function WorkingBandsaw.SawAction:start()
    self.character:faceThisObject(self.bandsaw)
    self:setActionAnim("Loot")
end

function WorkingBandsaw.SawAction:stop()
    ISBaseTimedAction.stop(self)
end

function WorkingBandsaw.SawAction:perform()
    -- Only ever a *request*: how many logs, and where. The server decides
    -- the plank ratio and re-validates everything before honoring it.
    sendClientCommand(self.character, "WorkingBandsaw", "SawLogs", {
        logCount = self.logCount,
        squareX = self.square:getX(),
        squareY = self.square:getY(),
        squareZ = self.square:getZ(),
    })

    ISBaseTimedAction.perform(self)
end

-- ============================================
-- CONTEXT MENU
-- ============================================

local function OnFillWorldObjectContextMenu(playerNum, context, worldObjects, test)
    if test then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    local bandsaw, sawSquare = nil, nil
    for _, obj in ipairs(worldObjects) do
        if WorkingBandsaw.IsBandSaw(obj) then
            bandsaw = obj
            sawSquare = obj:getSquare()
            break
        end
    end
    if not bandsaw or not sawSquare then return end

    local hasElectricity = WorkingBandsaw.HasElectricity(sawSquare)
    local _, _, _, totalCount = WorkingBandsaw.CountLogs(player, sawSquare)
    local planksPerLog = WorkingBandsaw.GetOption("PlanksPerLog", 3)

    local mainText = getText("ContextMenu_WorkingBandsaw_SawPlanks")
    local mainOption = context:addOption(mainText, nil, nil)
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(mainOption, subMenu)

    local tooltipText = nil
    local isEnabled = true
    if not hasElectricity then
        tooltipText = getText("Tooltip_WorkingBandsaw_NoElectricity")
        isEnabled = false
    elseif totalCount < 1 then
        tooltipText = getText("Tooltip_WorkingBandsaw_NoLogs")
        isEnabled = false
    end

    local quantities = {
        {qty = 1, key = "ContextMenu_WorkingBandsaw_Saw1"},
        {qty = 5, key = "ContextMenu_WorkingBandsaw_Saw5"},
        {qty = 10, key = "ContextMenu_WorkingBandsaw_Saw10"},
    }

    for _, q in ipairs(quantities) do
        local planks = q.qty * planksPerLog
        local optionText = getText(q.key, tostring(planks))
        local option = subMenu:addOption(optionText, player, WorkingBandsaw.OnSawPlanks, bandsaw, sawSquare, q.qty)

        if not isEnabled then
            option.notAvailable = true
            local tooltip = ISWorldObjectContextMenu.addToolTip()
            tooltip:setName(optionText)
            tooltip.description = tooltipText
            option.toolTip = tooltip
        elseif totalCount < q.qty then
            option.notAvailable = true
            local tooltip = ISWorldObjectContextMenu.addToolTip()
            tooltip:setName(optionText)
            tooltip.description = getText("Tooltip_WorkingBandsaw_NotEnoughLogs", tostring(q.qty), tostring(totalCount))
            option.toolTip = tooltip
        end
    end

    if totalCount > 0 and isEnabled then
        local totalPlanks = totalCount * planksPerLog
        local allText = getText("ContextMenu_WorkingBandsaw_SawAll", tostring(totalCount), tostring(totalPlanks))
        subMenu:addOption(allText, player, WorkingBandsaw.OnSawPlanks, bandsaw, sawSquare, totalCount)
    end

    if not isEnabled then
        mainOption.notAvailable = true
        local tooltip = ISWorldObjectContextMenu.addToolTip()
        tooltip:setName(mainText)
        tooltip.description = tooltipText
        mainOption.toolTip = tooltip
    end
end

function WorkingBandsaw.OnSawPlanks(player, bandsaw, square, logCount)
    if not player or not bandsaw or not square then return end
    if not WorkingBandsaw.HasElectricity(square) then return end

    local _, _, _, totalCount = WorkingBandsaw.CountLogs(player, square)
    if totalCount < 1 then return end
    logCount = math.min(logCount, totalCount)

    if luautils.walkAdj(player, square) then
        ISTimedActionQueue.add(WorkingBandsaw.SawAction:new(player, bandsaw, square, logCount))
    end
end

Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu)
