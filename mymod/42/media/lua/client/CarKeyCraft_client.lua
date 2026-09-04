require "TimedActions/ISBaseTimedAction"

ISCarKeyCraftCutAction = ISBaseTimedAction:derive("ISCarKeyCraftCutAction")

function ISCarKeyCraftCutAction:isValid()
    return self.character:getVehicle() == self.vehicle
end

function ISCarKeyCraftCutAction:update() end
function ISCarKeyCraftCutAction:start() end

function ISCarKeyCraftCutAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISCarKeyCraftCutAction:perform()
    sendClientCommand(self.character, "CarKeyCraft", "cutKey", {})
    ISBaseTimedAction.perform(self)
end

function ISCarKeyCraftCutAction:new(character, vehicle)
    local o = ISBaseTimedAction.new(self, character)
    o.vehicle = vehicle
    o.maxTime = 300
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end

local original_showRadialMenu = ISVehicleMenu.showRadialMenu

ISVehicleMenu.showRadialMenu = function(playerObj)
    original_showRadialMenu(playerObj)

    local vehicle = playerObj:getVehicle()
    if not vehicle then return end
    if not vehicle:isDriver(playerObj) then return end
    if vehicle:isEngineStarted() or vehicle:isEngineRunning() then return end

    if CarKeyCraft.getKeyBlank(playerObj) and CarKeyCraft.getCutTool(playerObj)
       and CarKeyCraft.meetsCutSkill(playerObj) then
        local menu = getPlayerRadialMenu(playerObj:getPlayerNum())
        menu:addSlice("Cut Key Blank", getTexture("media/ui/vehicles/vehicle_ignitionON.png"),
            function() ISTimedActionQueue.add(ISCarKeyCraftCutAction:new(playerObj, vehicle)) end, nil)
    end
end