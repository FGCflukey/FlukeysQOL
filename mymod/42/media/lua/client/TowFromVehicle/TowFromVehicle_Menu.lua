-- TowFromVehicle_Menu.lua
-- Adds "Attach/Detach Trailer" to the in-vehicle (steering wheel) radial
-- menu, for the driver of a stopped vehicle.
--
-- Which options appear is decided by vanilla itself: we run vanilla's
-- ISVehicleMenu.doTowingMenu (the outside-the-car towing menu) against a
-- stand-in menu that only records the slices, then add those same slices
-- here, pointed at our seated actions instead of vanilla's walk-to-hitch
-- ones. So vanilla's hitch rules and the server's DisableTrailerTowing /
-- DisableVehicleTowing / DisableBurntTowing options all apply unchanged.

require "Vehicles/ISUI/ISVehicleMenu"
require "TowFromVehicle/TowFromVehicle_Actions"

local dbg = TowFromVehicle.dbg

-- These W900 Semi-Truck mod tractors have their own in-cab tow handling, so
-- ours would be a duplicate option. The other W900 trucks (SemiTruckBox,
-- SemiTruckBox_mil, Oshkosh M911/M911B) and all trailers still use ours.
local OWN_TOWING_TRUCKS = {
	SemiTruck     = true,
	SemiTruckLite = true,
	SemiTruck_mil = true,
}

local function hasOwnTowing(vehicle)
	local script = vehicle:getScript()
	return script ~= nil and OWN_TOWING_TRUCKS[script:getName()] == true
end

local function onAttach(playerObj, vehicleA, attachmentA, attachmentB)
	local vehicleB = ISVehicleTrailerUtils.getTowableVehicleNear(
		vehicleA:getCurrentSquare(), vehicleA, attachmentA, attachmentB)
	if not vehicleB then return end
	ISTimedActionQueue.add(TowFromVehicle.AttachAction:new(playerObj, vehicleA, vehicleB, attachmentA, attachmentB))
end

local function onDetach(playerObj, vehicle)
	ISTimedActionQueue.add(TowFromVehicle.DetachAction:new(playerObj, vehicle))
end

-- Records what vanilla's towing menu would offer, without showing anything.
local function collectTowingSlices(playerObj, vehicle)
	local recorder = { slices = {} }
	function recorder:addSlice(text, texture, fn, a1, a2, a3, a4)
		table.insert(self.slices, { text = text, texture = texture, fn = fn, a1 = a1, a2 = a2, a3 = a3, a4 = a4 })
	end
	local ok, err = pcall(ISVehicleMenu.doTowingMenu, playerObj, vehicle, recorder)
	if not ok then dbg("doTowingMenu failed: " .. tostring(err)) end
	return recorder.slices
end

local function addTowingSlices(playerObj, vehicle, menu)
	for _, s in ipairs(collectTowingSlices(playerObj, vehicle)) do
		if s.fn == ISVehicleMenu.onAttachTrailer then
			-- vanilla args: (playerObj, vehicleA, attachmentA, attachmentB)
			menu:addSlice(s.text, s.texture, onAttach, playerObj, s.a2, s.a3, s.a4)
			dbg("offered attach: " .. tostring(s.text))
		elseif s.fn == ISVehicleMenu.onDetachTrailer then
			-- vanilla args: (playerObj, towingVehicle, attachment)
			menu:addSlice(s.text, s.texture, onDetach, playerObj, s.a2)
			dbg("offered detach: " .. tostring(s.text))
		end
	end
end

if ISVehicleMenu and ISVehicleMenu.showRadialMenu and not ISVehicleMenu._TowFromVehicleHooked then
	ISVehicleMenu._TowFromVehicleHooked = true
	local original = ISVehicleMenu.showRadialMenu
	ISVehicleMenu.showRadialMenu = function(playerObj, ...)
		local menu = playerObj and getPlayerRadialMenu(playerObj:getPlayerNum())
		local wasVisible = menu and menu:isReallyVisible()   -- vanilla toggles: it was closing
		original(playerObj, ...)
		if not menu or wasVisible or not menu:isReallyVisible() then return end

		local vehicle = playerObj:getVehicle()
		if not vehicle or not vehicle:isDriver(playerObj) or not vehicle:isStopped() then return end
		if hasOwnTowing(vehicle) then return end
		addTowingSlices(playerObj, vehicle, menu)
	end
end
