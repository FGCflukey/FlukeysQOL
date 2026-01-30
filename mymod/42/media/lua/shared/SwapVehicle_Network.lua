SwapVehicle = {}
SwapVehicle.packetName = "SwapVehicle_Request"

Events.OnServerCommand.Add(function(module, command, args)
    if module == "SwapVehicle" and command == "SwapVehicle_Request" then
        SwapVehicle_Server_Handle(args)
    end
end)
