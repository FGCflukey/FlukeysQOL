-- UnhotwireVehicle_Menu.lua
-- Adds "Remove Hotwire" to the in-vehicle (steering wheel) radial menu for the driver
-- of a hotwired car. Shows a locked slice (no action) when skills are too low, the same
-- way vanilla shows its locked hotwire hint. Logic and the timed action live in
-- shared/TimedActions/UnhotwireVehicle_Action.lua.

require "Vehicles/ISUI/ISVehicleMenu"
require "TimedActions/UnhotwireVehicle_Action"

local originalShowRadialMenu = ISVehicleMenu.showRadialMenu

local function onUnhotwire(playerObj)
    ISTimedActionQueue.add(UnhotwireVehicleAction:new(playerObj))
end

function ISVehicleMenu.showRadialMenu(playerObj, ...)
    originalShowRadialMenu(playerObj, ...)

    if not playerObj then return end
    local vehicle = playerObj:getVehicle()
    if not UnhotwireVehicle.canShow(playerObj, vehicle) then return end

    local menu = getPlayerRadialMenu(playerObj:getPlayerNum())
    if not menu then return end

    local elec, mech = UnhotwireVehicle.getRequirements()
    if UnhotwireVehicle.hasSkills(playerObj) then
        menu:addSlice(getText("UI_UnhotwireVehicle"),
            getTexture("media/ui/vehicles/vehicle_ignitionOFF.png"), onUnhotwire, playerObj)
    else
        menu:addSlice(getText("UI_UnhotwireVehicleLocked", elec, mech),
            getTexture("media/ui/vehicles/vehicle_ignitionOFF.png"), nil, playerObj)
    end
end
