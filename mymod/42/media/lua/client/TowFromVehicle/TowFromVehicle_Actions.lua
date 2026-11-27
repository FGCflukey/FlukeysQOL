-- TowFromVehicle_Actions.lua
-- Attach / detach a trailer while sitting in the driver's seat.
--
-- Our own timed actions (vanilla's ISAttachTrailerToVehicle /
-- ISDetachTrailerFromVehicle are left untouched). They send the same
-- vanilla server commands ('vehicle' 'attachTrailer' / 'detachTrailer',
-- server/Vehicles/VehicleCommands.lua), so the hitch itself is done and
-- synced by the game exactly as it is from outside the car.

require "TimedActions/ISBaseTimedAction"

TowFromVehicle = TowFromVehicle or {}

local DEBUG = true
local function dbg(msg)
	if DEBUG then print("[TowFromVehicle] " .. tostring(msg)) end
end
TowFromVehicle.dbg = dbg

local ACTION_TIME = 100   -- same length as vanilla's hitch actions

-- The player must be sitting in one of the two vehicles, and it must be stopped.
local function seatedInStopped(character, vehicleA, vehicleB)
	local seat = character:getVehicle()
	if not seat or (seat ~= vehicleA and seat ~= vehicleB) then return false end
	return seat:isStopped()
end

local function stopSound(action)
	if action.sound and action.character:getEmitter():isPlaying(action.sound) then
		action.character:stopOrTriggerSound(action.sound)
	end
	action.sound = nil
end

---------------------------------------------------------
-- Attach
---------------------------------------------------------
TowFromVehicle.AttachAction = ISBaseTimedAction:derive("TowFromVehicle_AttachAction")

function TowFromVehicle.AttachAction:new(character, vehicleA, vehicleB, attachmentA, attachmentB)
	local o = ISBaseTimedAction.new(self, character)
	o.vehicleA = vehicleA
	o.vehicleB = vehicleB
	o.attachmentA = attachmentA
	o.attachmentB = attachmentB
	o.stopOnWalk = false
	o.stopOnRun = false
	o.maxTime = character:isTimedActionInstant() and 1 or ACTION_TIME
	return o
end

function TowFromVehicle.AttachAction:isValid()
	local a, b = self.vehicleA, self.vehicleB
	if not a or not b or a:isRemovedFromWorld() or b:isRemovedFromWorld() then return false end
	local towing = a:getVehicleTowing()
	if towing ~= nil and towing ~= b then return false end
	return seatedInStopped(self.character, a, b)
end

function TowFromVehicle.AttachAction:waitToStart()
	return false   -- seated: nothing to turn and face
end

function TowFromVehicle.AttachAction:start()
	self.sound = self.character:getEmitter():playSound("VehicleTowAttach")
	-- Same order as vanilla: start the hitch now, undo it in stop() if cancelled.
	self.vehicleA:beginAttachingTrailer()
	local found = ISVehicleTrailerUtils.getTowableVehicleNear(
		self.vehicleA:getCurrentSquare(), self.vehicleA, self.attachmentA, self.attachmentB)
	if found == self.vehicleB then
		sendClientCommand(self.character, "vehicle", "attachTrailer", {
			vehicleA = self.vehicleA:getId(), vehicleB = self.vehicleB:getId(),
			attachmentA = self.attachmentA, attachmentB = self.attachmentB,
		})
		self.sent = true
		dbg("attach sent: " .. tostring(self.vehicleA:getId()) .. " -> " .. tostring(self.vehicleB:getId())
			.. " (" .. tostring(self.attachmentA) .. "/" .. tostring(self.attachmentB) .. ")")
	else
		dbg("attach: vehicle B no longer in reach, nothing sent")
	end
end

function TowFromVehicle.AttachAction:update()
	if not seatedInStopped(self.character, self.vehicleA, self.vehicleB) then
		self:forceStop()
	end
end

function TowFromVehicle.AttachAction:stop()
	self.vehicleA:stopAttachingTrailer()
	if self.sent then
		sendClientCommand(self.character, "vehicle", "detachTrailer", { vehicle = self.vehicleA:getId() })
		dbg("attach cancelled, hitch undone")
	end
	stopSound(self)
	ISBaseTimedAction.stop(self)
end

function TowFromVehicle.AttachAction:perform()
	self.vehicleA:stopAttachingTrailer()
	stopSound(self)
	dbg("attach finished, towing=" .. tostring(self.vehicleA:getVehicleTowing() ~= nil))
	ISBaseTimedAction.perform(self)
end

---------------------------------------------------------
-- Detach
---------------------------------------------------------
TowFromVehicle.DetachAction = ISBaseTimedAction:derive("TowFromVehicle_DetachAction")

function TowFromVehicle.DetachAction:new(character, vehicle)
	local o = ISBaseTimedAction.new(self, character)
	o.vehicle = vehicle
	o.stopOnWalk = false
	o.stopOnRun = false
	o.maxTime = character:isTimedActionInstant() and 1 or ACTION_TIME
	return o
end

function TowFromVehicle.DetachAction:isValid()
	local v = self.vehicle
	if not v or v:isRemovedFromWorld() then return false end
	local towed = v:getVehicleTowing()
	if not towed then return false end
	return seatedInStopped(self.character, v, towed)
end

function TowFromVehicle.DetachAction:waitToStart()
	return false
end

function TowFromVehicle.DetachAction:start()
	self.sound = self.character:getEmitter():playSound("VehicleTowDetach")
end

function TowFromVehicle.DetachAction:update()
	if not seatedInStopped(self.character, self.vehicle, self.vehicle:getVehicleTowing()) then
		self:forceStop()
	end
end

function TowFromVehicle.DetachAction:stop()
	stopSound(self)
	ISBaseTimedAction.stop(self)
end

function TowFromVehicle.DetachAction:perform()
	stopSound(self)
	-- Seated in one of the two linked vehicles, so no hitch-distance check is needed.
	sendClientCommand(self.character, "vehicle", "detachTrailer", { vehicle = self.vehicle:getId() })
	dbg("detach sent for vehicle " .. tostring(self.vehicle:getId()))
	ISBaseTimedAction.perform(self)
end
