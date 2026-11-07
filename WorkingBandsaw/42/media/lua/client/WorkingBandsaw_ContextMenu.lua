-- WorkingBandsaw_ContextMenu.lua
-- Context menu + client-side timed action for sawing logs into planks at
-- the Metal Bandsaw. This file only ever decides what to SHOW and when to
-- SEND a request -- every number that actually matters (plank ratio, search
-- range, and whether the request is even legitimate) is re-decided
-- server-side in WorkingBandsaw_Server.lua.
--
-- Whatever quantity the player picks (1/5/10/All) is cut one log at a
-- time, not as a single lump timer: WorkingBandsaw.SawAction only ever
-- processes ONE log, and on completion re-checks availability/power and
-- queues the next one itself if more remain -- a self-chaining action,
-- the same idea the "Table Saw" Workshop mod (id 3540297822) uses for its
-- own log-by-log cutting loop, adapted to our existing quantity-picker
-- menu instead of its separate persistent panel.

require "WorkingBandsaw_Shared"
require "ISUI/ISWorldObjectContextMenu"
require "TimedActions/ISBaseTimedAction"

WorkingBandsaw.SawAction = ISBaseTimedAction:derive("WorkingBandsaw.SawAction")

--- @param remainingLogs integer how many more logs this chain should cut,
---        including the one this action itself is about to cut
function WorkingBandsaw.SawAction:new(player, bandsaw, square, remainingLogs)
    local o = ISBaseTimedAction.new(self, player)

    o.bandsaw = bandsaw
    o.square = square
    o.remainingLogs = remainingLogs

    local secondsPerLog = WorkingBandsaw.GetOption("SecondsPerLog", 5)
    o.maxTime = secondsPerLog * 30 -- 30 ticks/sec, confirmed via MPBS's own tested heavy-lift action
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
    -- Only ever a *request* for ONE log, and where. The server decides the
    -- plank ratio and re-validates everything before honoring it.
    sendClientCommand(self.character, "WorkingBandsaw", "SawLogs", {
        logCount = 1,
        squareX = self.square:getX(),
        squareY = self.square:getY(),
        squareZ = self.square:getZ(),
    })

    local remaining = self.remainingLogs - 1
    if remaining > 0 then
        local _, _, _, totalCount = WorkingBandsaw.CountLogs(self.character, self.square)
        if totalCount >= 1 and WorkingBandsaw.HasElectricity(self.square) then
            ISTimedActionQueue.add(WorkingBandsaw.SawAction:new(self.character, self.bandsaw, self.square, remaining))
        end
    end

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

-- ============================================
-- PICK UP: any Metal Bandsaw (map-found or player-placed) -> carried item
-- ============================================

local function hasCrowbar(player)
    local inv = player:getInventory()
    if inv:getFirstTypeRecurse("Base.Crowbar") then return true end

    local primary = player:getPrimaryHandItem()
    if primary and primary:getFullType() == "Base.Crowbar" then return true end

    local secondary = player:getSecondaryHandItem()
    if secondary and secondary:getFullType() == "Base.Crowbar" then return true end

    return false
end

local function onPickUp(obj, player)
    ISTimedActionQueue.add(ISWorkingBandsawHeavyLiftAction:new(player, obj, function(character, liftedObj)
        local sq = liftedObj:getSquare()
        if not sq then return end
        sendClientCommand(character, "WorkingBandsaw", "PickUp", { x = sq:getX(), y = sq:getY(), z = sq:getZ() })
    end))
end

Events.OnFillWorldObjectContextMenu.Add(function(playerNum, context, worldObjects, test)
    if test then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    for _, obj in ipairs(worldObjects) do
        if WorkingBandsaw.IsBandSaw(obj) then
            if hasCrowbar(player) then
                context:addOption(getText("ContextMenu_WorkingBandsaw_PickUp"), obj, onPickUp, player)
            else
                local opt = context:addOption(getText("ContextMenu_WorkingBandsaw_PickUp"), nil, nil)
                opt.notAvailable = true
                local tooltip = ISWorldObjectContextMenu.addToolTip()
                tooltip:setName(getText("ContextMenu_WorkingBandsaw_PickUp"))
                tooltip.description = getText("Tooltip_WorkingBandsaw_NeedCrowbar")
                opt.toolTip = tooltip
            end
            return
        end
    end
end)

-- ============================================
-- PLACE: carried item -> real Metal Bandsaw, 4-direction submenu
-- ============================================

local DIRECTION_LABELS = {
    N = "ContextMenu_WorkingBandsaw_FaceNorth",
    E = "ContextMenu_WorkingBandsaw_FaceEast",
    S = "ContextMenu_WorkingBandsaw_FaceSouth",
    W = "ContextMenu_WorkingBandsaw_FaceWest",
}

local function onPlace(item, player, direction)
    local sq = player:getSquare()
    if not sq then return end
    local target = sq:getAdjacentSquare(player:getDir())
    if not target then return end
    sendClientCommand(player, "WorkingBandsaw", "Place", {
        x = target:getX(), y = target:getY(), z = target:getZ(),
        direction = direction,
    })
end

local function addPlaceOption(context, item, player)
    local mainOption = context:addOption(getText("ContextMenu_WorkingBandsaw_Place"), item, nil)
    local submenu = ISContextMenu:getNew(context)
    context:addSubMenu(mainOption, submenu)

    for _, dir in ipairs(WorkingBandsaw.DIRECTIONS) do
        submenu:addOption(getText(DIRECTION_LABELS[dir]), item, function()
            onPlace(item, player, dir)
        end)
    end
end

Events.OnFillInventoryObjectContextMenu.Add(function(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then return end

    for _, item in ipairs(items) do
        local actual = item.items and item.items[1] or item
        if actual and actual.getFullType and actual:getFullType() == "WorkingBandsaw.BandsawItem" then
            addPlaceOption(context, actual, player)
            return
        end
    end
end)
