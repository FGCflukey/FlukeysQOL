SimpleLockpicking = SimpleLockpicking or {};

if SimpleLockpicking.ShowRadialMenuOutside == nil then
	SimpleLockpicking.ShowRadialMenuOutside = ISVehicleMenu.showRadialMenuOutside;
end

if SimpleLockpicking.FillMenuOutsideVehicle == nil then
	SimpleLockpicking.FillMenuOutsideVehicle = ISVehicleMenu.FillMenuOutsideVehicle;
end

ISVehicleMenu.showRadialMenuOutside = function(player)
	SimpleLockpicking.ShowRadialMenuOutside(player);
	if not SimpleLockpicking.shouldPickLock(player) then return end;
	
	local vehicle = player:getNearVehicle();
	if not vehicle then return end;
	local door = vehicle:getUseablePart(player);
	if not door or not door:getDoor() or not door:getInventoryItem() then return end;
	
	if door:getId() ~= "EngineDoor" and door:getDoor():isLocked() then
		local playerID = player:getPlayerNum();
		local menu = getPlayerRadialMenu(playerID);
		menu:addSlice(getText("ContextMenu_PickLock"), getTexture("media/ui/vehicles/lockpick.png"), SimpleLockpicking.tryPickLock, playerID, vehicle, door);
	end
end

ISVehicleMenu.FillMenuOutsideVehicle = function(playerID, context, vehicle, test)
	SimpleLockpicking.FillMenuOutsideVehicle(playerID, context, vehicle, test);
	
	local player = getSpecificPlayer(playerID);
	if not SimpleLockpicking.shouldPickLock(player) then return end;
	
	if not vehicle then return end;
	local door = vehicle:getUseablePart(player);
	if not door or not door:getDoor() or not door:getInventoryItem() then return end;
	
	if door:getId() ~= "EngineDoor" and door:getDoor():isLocked() then
		context:addOption(getText("ContextMenu_PickLock"), nil, SimpleLockpicking.tryPickVehicleWorldLock, playerID, door);
	end
end