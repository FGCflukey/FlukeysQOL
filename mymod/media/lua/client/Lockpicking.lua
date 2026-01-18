SimpleLockpicking = SimpleLockpicking or {};

function SimpleLockpicking.shouldPickLock(player)
	if getSandboxOptions():getOptionByName("simpleLockpicking.RequireBurglar"):getValue() then
		if not player:HasTrait("Burglar") then
			return false;
		end
	end
	
	return true;
end

function SimpleLockpicking.pickLock(playerID, player, vehicle, door, tools)
	if vehicle or luautils.walkAdjWindowOrDoor(player, door:getSquare(), door) then
		ISWorldObjectContextMenu.equip(player, player:getPrimaryHandItem(), tools["paperclip"], true, false);
		ISWorldObjectContextMenu.equip(player, player:getSecondaryHandItem(), tools["screwdriver"], false, false);
		ISTimedActionQueue.add(LockpickTimedAction:new(playerID, door, vehicle));
	end
end

function SimpleLockpicking.tryPickLock(playerID, vehicle, door)
	local player = getSpecificPlayer(playerID);
	local inventory = player:getInventory();
	local screwdriver = inventory:getFirstTagRecurse("Screwdriver");
	local paperclip = inventory:getFirstTypeRecurse("Paperclip");
	
	if not (screwdriver or paperclip) then
		player:Say(getText("IGUI_NeedScrewAndClip"));
		return;
	elseif not screwdriver then
		player:Say(getText("IGUI_NeedScrew"));
		return;
	elseif not paperclip then
		player:Say(getText("IGUI_NeedClip"));
		return;
	end
	
	SimpleLockpicking.pickLock(playerID, player, vehicle, door, {screwdriver = screwdriver, paperclip = paperclip});
end

function SimpleLockpicking.tryPickWorldLock(worldObjects, playerID, door)
	SimpleLockpicking.tryPickLock(playerID, nil, door);
end

function SimpleLockpicking.tryPickVehicleWorldLock(worldObjects, playerID, door)
	SimpleLockpicking.tryPickLock(playerID, door:getVehicle(), door);
end

local function lockPickContextMenu(playerID, context, worldObjects, test)
	local player = getSpecificPlayer(playerID);
	if not SimpleLockpicking.shouldPickLock(player) then return end;
	
	for _, obj in ipairs(worldObjects) do
		local isDoor = instanceof(obj, "IsoDoor") or (instanceof(obj, "IsoThumpable") and obj:isDoor());
		if isDoor and (obj:isLockedByKey() or obj:isLocked()) then
			context:addOption(getText("ContextMenu_PickLock"), worldObjects, SimpleLockpicking.tryPickWorldLock, playerID, obj);
			break;
		end
	end
end

Events.OnFillWorldObjectContextMenu.Add(lockPickContextMenu);