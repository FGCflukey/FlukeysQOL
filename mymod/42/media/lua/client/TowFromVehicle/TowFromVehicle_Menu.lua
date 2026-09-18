-- TowFromVehicle_Menu.lua
-- Adds "Attach/Detach Trailer" to the in-vehicle (steering wheel)
-- radial menu, so towing can be set up/torn down without getting out
-- of the car. Ported in from the Workshop mod "Tow In Your Car"
-- (SportXAI, Steam id 3473214630) -- this menu-injection part was
-- already working correctly as published (confirmed by a Workshop
-- comment: "it shows up and even does the progress bar"). The real
-- bug was entirely in the timed-action overrides -- see
-- TowFromVehicle_Actions.lua for the actual fix. Ported this file
-- essentially unchanged (only the accidental unlocalized
-- `vehicleTowing` global tidied up -- confirmed unused anywhere else
-- in the original mod, so this changes nothing about behavior).

local vehicleMenu_Data = ISVehicleMenu.showRadialMenu

local function Attach(playerObj, vA, vB, aA, aB)  --Attach timed action
	playerObj:setVariable("IsAttachingInVehicle", true)
	local action = ISAttachTrailerToVehicle:new(playerObj, vA, vB, aA, aB)
	ISTimedActionQueue.add(action)
end

local function Detach(playerObj, vehicle, attach)  --Detach timed action
	playerObj:setVariable("IsAttachingInVehicle", true)
	local action = ISDetachTrailerFromVehicle:new(playerObj, vehicle, attach)
	ISTimedActionQueue.add(action)
end

local function AttachTrailerInVehicle(vehicleB, vehicle, attachmentB, attachmentA)
	local playerObj = getSpecificPlayer(0)
	local menu = getPlayerRadialMenu(playerObj:getPlayerNum())
	local aName = ISVehicleMenu.getVehicleDisplayName(vehicle)
	local bName = ISVehicleMenu.getVehicleDisplayName(vehicleB)
	local attachNameA = getText("IGUI_TrailerAttachName_" .. attachmentB)
	local attachNameB = getText("IGUI_TrailerAttachName_" .. attachmentA)
	local text = getText("ContextMenu_Vehicle_AttachTrailer", aName, bName, attachNameA, attachNameB);
	local vehicleTowing = vehicleB
	menu:addSlice(text, getTexture("media/ui/ZoomIn.png"), Attach, playerObj, vehicleTowing, vehicle, attachmentA, attachmentB)
end

function ISVehicleMenu.showRadialMenu(...)
	vehicleMenu_Data(...)
	local playerObj = getSpecificPlayer(0)
	local vehicle = playerObj:getVehicle()

	if not vehicle then return end

	local menu = getPlayerRadialMenu(playerObj:getPlayerNum())

    if not vehicle:isDriver(playerObj) then return end

    --Attach vehicle
    local attachmentA, attachmentB = "trailer", "trailerfront"
    local vehicleB = ISVehicleTrailerUtils.getTowableVehicleNear(vehicle:getSquare(), vehicle, attachmentA, attachmentB)
    if vehicleB then
        AttachTrailerInVehicle(vehicle, vehicleB, attachmentB, attachmentA)
        return
    end

    attachmentA, attachmentB = "trailerfront", "trailerfront"
    vehicleB = ISVehicleTrailerUtils.getTowableVehicleNear(vehicle:getSquare(), vehicle, attachmentA, attachmentB)
    if vehicleB then
        AttachTrailerInVehicle(vehicle, vehicleB, attachmentB, attachmentA)
        return
    end

    attachmentA, attachmentB = "trailer", "trailer"
    vehicleB = ISVehicleTrailerUtils.getTowableVehicleNear(vehicle:getSquare(), vehicle, attachmentA, attachmentB)
    if vehicleB then
        AttachTrailerInVehicle(vehicle, vehicleB, attachmentA, attachmentB)
        return
    end

    attachmentA, attachmentB = "trailerfront", "trailer"
    vehicleB = ISVehicleTrailerUtils.getTowableVehicleNear(vehicle:getSquare(), vehicle, attachmentA, attachmentB)
    if vehicleB then
        AttachTrailerInVehicle(vehicle, vehicleB, attachmentB, attachmentA)
        return
    end

    --Detach vehicle
    if vehicle:getVehicleTowing() then
        local aName = ISVehicleMenu.getVehicleDisplayName(vehicle:getVehicleTowing())
        local bName = ISVehicleMenu.getVehicleDisplayName(vehicle)
        local text = getText("ContextMenu_Vehicle_DetachTrailer", aName, bName)
        if vehicle:isStopped() and vehicle:getVehicleTowing():isStopped() then
            menu:addSlice(text, getTexture("media/ui/ZoomOut.png"), Detach, playerObj, vehicle, vehicle:getTowAttachmentSelf())
        end
        return
    end

    if vehicle:getVehicleTowedBy() then
        local aName = ISVehicleMenu.getVehicleDisplayName(vehicle:getVehicleTowedBy())
        local bName = ISVehicleMenu.getVehicleDisplayName(vehicle)
        local text = getText("ContextMenu_Vehicle_DetachTrailer", bName, aName)
        if vehicle:isStopped() and vehicle:getVehicleTowedBy():isStopped() then
            menu:addSlice(text, getTexture("media/ui/ZoomOut.png"), Detach, playerObj, vehicle:getVehicleTowedBy(), vehicle:getVehicleTowedBy():getTowAttachmentSelf())
        end
        return
    end
end
