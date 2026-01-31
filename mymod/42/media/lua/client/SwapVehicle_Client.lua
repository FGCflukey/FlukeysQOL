------------------------------------------------------------
-- SwapVehicle Client Command Sender
-- Called by the UI when the player confirms a swap
------------------------------------------------------------

SwapVehicle_Client = {}

------------------------------------------------------------
-- Send swap request to server
------------------------------------------------------------
function SwapVehicle_Client.SendSwapRequest(player, vehicle, newScript)
    if not player or not vehicle or not newScript then
        print("SwapVehicle_Client: Missing data for swap request")
        return
    end

    local args = {
        vehicleId = vehicle:getId(),
        newScript = newScript,
    }

    sendClientCommand(player, "SwapVehicle", "Swap", args)
end

------------------------------------------------------------
-- End of Client Command File
------------------------------------------------------------