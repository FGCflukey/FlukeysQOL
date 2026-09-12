-- Automaker_Client.lua
-- Consumes build materials in response to the server's TakeMaterials
-- confirmation, sent only after it has already spawned the vehicle --
-- same round-trip the original mod used (see Automaker_Util.lua's
-- takeMaterials for why this isn't done server-side directly).

local function OnServerCommand(module, command, args)
    if module ~= "Automaker" then return end
    if command ~= "TakeMaterials" then return end

    Automaker_Util.takeMaterials(tonumber(args.MechanicType) or 0)
end

Events.OnServerCommand.Add(OnServerCommand)
