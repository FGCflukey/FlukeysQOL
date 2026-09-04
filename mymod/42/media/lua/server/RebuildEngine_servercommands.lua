local Commands = {}
Commands.RebuildEngine = {}

-----------------------------------------------------
-- RECURSIVE ITEM-OF-TYPE SEARCH (server-side)
--
-- Same pattern used by EZPZ Banking (confirmed working in B42.20
-- MP) for finding Money/MoneyBundle across bags, worn clothing,
-- and hand items. Returns {item, container} pairs so each item
-- can be removed from the exact container that actually holds it.
-----------------------------------------------------
local function collectItemsOfType(container, typeName, results)
	if not container then return end
	local items = container:getItems()
	for i = 0, items:size() - 1 do
		local item = items:get(i)
		if item:getType() == typeName then
			table.insert(results, { item = item, container = container })
		end
		if item:IsInventoryContainer() then
			collectItemsOfType(item:getInventory(), typeName, results)
		end
	end
end

Commands.RebuildEngine.RepairEngine = function( player, args)

	if isClient() then return end
	if not player or player:isDead() then return end

	local vehicle = getVehicleById( tonumber( args.vehicle))

	--just in case something goes wrong.
	if vehicle == nil then
		print( "Warning: no vehicle found while rebuilding engine.")
		return
	end

	local part = vehicle:getPartById( args.part)
	if not part or part:getId() ~= "Engine" then
		print( "Warning: invalid or non-Engine part while rebuilding engine.")
		return
	end

	-----------------------------------------------------
	-- SERVER-SIDE VALIDATION
	--
	-- The client already gates the context menu option on these
	-- same checks, but that's cosmetic only -- a modified client
	-- could send this command directly and skip them. Re-check
	-- everything here so the server never grants a repair (or
	-- consumes parts) based on unverified client state.
	-----------------------------------------------------

	-- Recompute the required skill/parts from the vehicle's own
	-- script server-side -- never trust a count sent by the client.
	local engineRepairLevel = vehicle:getScript():getEngineRepairLevel()
	local requiredEngineParts = engineRepairLevel * 5

	if player:getPerkLevel(Perks.Mechanics) < engineRepairLevel then
		print( "Warning: player lacks required Mechanics skill to rebuild engine.")
		return
	end

	if part:getCondition() < 90 then
		print( "Warning: engine condition too low to rebuild.")
		return
	end

	if vehicle:getEngineQuality() >= 100 then
		print( "Warning: engine quality already maxed.")
		return
	end

	local inv = player:getInventory()
	if not inv:contains("Wrench") then
		print( "Warning: player has no wrench for engine rebuild.")
		return
	end

	local parts = {}
	collectItemsOfType(inv, "EngineParts", parts)

	if #parts < requiredEngineParts then
		print( "Warning: player does not have enough Engine Parts to rebuild engine (has " .. #parts .. ", needs " .. requiredEngineParts .. ").")
		return
	end

	-----------------------------------------------------
	-- CONSUME PARTS -- authoritative removal, synced to the client
	-----------------------------------------------------
	for i = 1, requiredEngineParts do
		local entry = parts[i]
		entry.container:Remove(entry.item)
		sendRemoveItemFromContainer(entry.container, entry.item)
	end

	-----------------------------------------------------
	-- APPLY THE REPAIR
	-----------------------------------------------------
	--set Engine Condition to 100
	part:setCondition( 100)
	--set Engine Quality to 100
	vehicle:setEngineFeature( 100, vehicle:getEngineLoudness(), vehicle:getEnginePower())

end

local onClientCommand = function( module, command, player, args)

	if Commands[module] and Commands[module][command] then
		Commands[module][command]( player, args)
	end
end

Events.OnClientCommand.Add(onClientCommand)