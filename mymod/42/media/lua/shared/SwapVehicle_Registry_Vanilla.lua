------------------------------------------------------------
-- SwapVehicle Registry (Vanilla)
-- Defines Groups, PartSets, and SwapPairs for vanilla cars
------------------------------------------------------------

SwapVehicleRegistry = SwapVehicleRegistry or {}

------------------------------------------------------------
-- GROUPS
-- Maps vehicle script → group ID
------------------------------------------------------------
SwapVehicleRegistry.Groups = {
    -- Taxi
    ["Base.CarTaxi"]      = "Taxi",
    ["Base.CarTaxi2"]     = "Taxi",

    -- Police
    ["Base.CarPolice"]    = "Police",
    ["Base.CarPolice2"]   = "Police",

    -- Ranger
    ["Base.PickUpVanLights"]  = "Ranger",
    ["Base.PickUpVanLights2"] = "Ranger",

    -- News
    ["Base.VanRadio"]     = "News",
    ["Base.VanRadio2"]    = "News",

    -- Postal
    ["Base.VanMail"]      = "Postal",
    ["Base.VanMail2"]     = "Postal",

    -- Ambulance
    ["Base.VanAmbulance"]  = "Ambulance",
    ["Base.VanAmbulance2"] = "Ambulance",

    -- Fire Department
    ["Base.PickUpVanLightsFire"]  = "FireDept",
    ["Base.PickUpVanLightsFire2"] = "FireDept",

    -- Utility (Spiffo)
    ["Base.VanSpiffo"]    = "Spiffo",
    ["Base.VanSpiffo2"]   = "Spiffo",
}

------------------------------------------------------------
-- PART SETS
-- Defines which parts to preserve during swap
-- These are shared across all groups unless overridden
------------------------------------------------------------
SwapVehicleRegistry.PartSets = {

    Default = {
        "TrunkDoor","TruckBed",
        "SeatFrontLeft","SeatFrontRight","SeatRearLeft","SeatRearRight",
        "GloveBox","Radio","PassengerCompartment",
        "GasTank","Battery","Engine","Muffler","EngineDoor","Heater",
        "Windshield","WindshieldRear",
        "WindowFrontLeft","WindowFrontRight","WindowRearLeft","WindowRearRight",
        "DoorFrontLeft","DoorFrontRight","DoorRearLeft","DoorRearRight",
        "TireFrontLeft","TireFrontRight","TireRearLeft","TireRearRight",
        "BrakeFrontLeft","BrakeFrontRight","BrakeRearLeft","BrakeRearRight",
        "SuspensionFrontLeft","SuspensionFrontRight",
        "SuspensionRearLeft","SuspensionRearRight",
        "HeadlightLeft","HeadlightRight","HeadlightRearLeft","HeadlightRearRight"
    },

    -- If any group needs overrides later, add them here:
    -- Taxi = { ... },
    -- Police = { ... },
}

------------------------------------------------------------
-- SWAP PAIRS
-- Defines which scripts can swap within each group
------------------------------------------------------------
SwapVehicleRegistry.SwapPairs = {

    Taxi = {
        "Base.CarTaxi",
        "Base.CarTaxi2",
    },

    Police = {
        "Base.CarPolice",
        "Base.CarPolice2",
    },

    Ranger = {
        "Base.PickUpVanLights",
        "Base.PickUpVanLights2",
    },

    News = {
        "Base.VanRadio",
        "Base.VanRadio2",
    },

    Postal = {
        "Base.VanMail",
        "Base.VanMail2",
    },

    Ambulance = {
        "Base.VanAmbulance",
        "Base.VanAmbulance2",
    },

    FireDept = {
        "Base.PickUpVanLightsFire",
        "Base.PickUpVanLightsFire2",
    },

    Spiffo = {
        "Base.VanSpiffo",
        "Base.VanSpiffo2",
    },
}

------------------------------------------------------------
-- End of Vanilla Registry
------------------------------------------------------------