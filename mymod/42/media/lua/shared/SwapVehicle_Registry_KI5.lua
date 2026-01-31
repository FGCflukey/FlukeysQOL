------------------------------------------------------------
-- SwapVehicle Registry (KI5 Vehicles)
-- Defines Groups, PartSets, and SwapPairs for KI5 mods
------------------------------------------------------------

SwapVehicleRegistry = SwapVehicleRegistry or {}

------------------------------------------------------------
-- GROUPS
-- Maps KI5 vehicle script → group ID
-- Only includes vehicles with actual alternate vinyls
------------------------------------------------------------
SwapVehicleRegistry.Groups = SwapVehicleRegistry.Groups or {}

-- Example KI5 groups (expand as needed)
SwapVehicleRegistry.Groups["Base.86fordF150"]      = "KI5_F150"
SwapVehicleRegistry.Groups["Base.86fordF150_Ranger"] = "KI5_F150"

SwapVehicleRegistry.Groups["Base.92jeepCherokee"]  = "KI5_Cherokee"
SwapVehicleRegistry.Groups["Base.92jeepCherokee2"] = "KI5_Cherokee"

SwapVehicleRegistry.Groups["Base.91chevyS10"]      = "KI5_S10"
SwapVehicleRegistry.Groups["Base.91chevyS10_Utility"] = "KI5_S10"

-- Add more KI5 variants here as you discover them


------------------------------------------------------------
-- PART SETS
-- KI5 vehicles generally use the same part sets as vanilla
-- but you can override per-group if needed
------------------------------------------------------------
SwapVehicleRegistry.PartSets = SwapVehicleRegistry.PartSets or {}

-- Default is inherited from vanilla registry
-- Override example:
-- SwapVehicleRegistry.PartSets["KI5_F150"] = { ... }


------------------------------------------------------------
-- SWAP PAIRS
-- Defines which KI5 scripts can swap within each group
------------------------------------------------------------
SwapVehicleRegistry.SwapPairs = SwapVehicleRegistry.SwapPairs or {}

SwapVehicleRegistry.SwapPairs["KI5_F150"] = {
    "Base.86fordF150",
    "Base.86fordF150_Ranger",
}

SwapVehicleRegistry.SwapPairs["KI5_Cherokee"] = {
    "Base.92jeepCherokee",
    "Base.92jeepCherokee2",
}

SwapVehicleRegistry.SwapPairs["KI5_S10"] = {
    "Base.91chevyS10",
    "Base.91chevyS10_Utility",
}

-- Add more KI5 groups here as needed


------------------------------------------------------------
-- End of KI5 Registry
------------------------------------------------------------