require "TimedActions/ISBaseTimedAction"

ISRebuildEngine = ISBaseTimedAction:derive("ISRebuildEngine")

function ISRebuildEngine:isValid()
--	return self.vehicle:isInArea(self.part:getArea(), self.character)
	return true;
end

function ISRebuildEngine:waitToStart()
	self.character:faceThisObject(self.vehicle)
	return self.character:shouldBeTurning()
end

function ISRebuildEngine:update()
	self.character:faceThisObject(self.vehicle)
	self.item:setJobDelta(self:getJobDelta())

    self.character:setMetabolicTarget(Metabolics.MediumWork);
end

function ISRebuildEngine:start()
	self.item:setJobType(getText("IGUI_EER_RebuildEngine"))
	self:setActionAnim("VehicleWorkOnMid")
end

function ISRebuildEngine:stop()
	self.item:setJobDelta(0)
	ISBaseTimedAction.stop(self)
end

function ISRebuildEngine:perform()
	ISBaseTimedAction.perform(self)
	self.item:setJobDelta(0)

	--this sends the request to the server to rebuild the engine.
	-- Server is now authoritative for everything: it re-validates skill,
	-- parts, wrench, and condition itself (never trusts the client), and
	-- removes the Engine Parts from the player's inventory server-side,
	-- syncing the removal properly via sendRemoveItemFromContainer.
	-- See RebuildEngine_servercommands.lua.
	--
	-- We no longer touch the player's inventory here -- the old
	-- inventory:RemoveOneOf("EngineParts") loop was client-only and
	-- never actually debited the server's copy, which meant parts could
	-- reappear on reconnect and the repair could effectively be
	-- duplicated for free.
	sendClientCommand(self.character, "RebuildEngine", "RepairEngine", { vehicle = self.part:getVehicle():getId(), part = self.part:getId() });

	--these two lines are fake!  it only effects the local version of the car to update the mechanics UI
	self.part:getVehicle():setEngineFeature( 100, self.part:getVehicle():getEngineLoudness(), self.part:getVehicle():getEnginePower())
	self.part:setCondition( 100)

	self.character:getXp():AddXP(Perks.Mechanics, 50);
end

function ISRebuildEngine:new(character, part, item, time)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.vehicle = part:getVehicle()
	o.part = part
	o.item = item
	o.maxTime = time
	o.jobType = getText("IGUI_EER_RebuildEngine")
	return o
end