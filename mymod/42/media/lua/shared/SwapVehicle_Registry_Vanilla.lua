------------------------------------------------------------
-- SwapVehicle Registry (Vanilla - Updated)
-- Same structure as original. Only Groups + SwapPairs updated.
------------------------------------------------------------

SwapVehicleRegistry = SwapVehicleRegistry or {}

------------------------------------------------------------
-- GROUPS
-- Maps vehicle script → group ID
------------------------------------------------------------
SwapVehicleRegistry.Groups = {

    --------------------------------------------------------
    -- PoliceLights (classic police sedans)
    --------------------------------------------------------
    ["Base.CarLightsBulletinSheriff"] = "PoliceLights",
    ["Base.CarLightsKST"]              = "PoliceLights",
    ["Base.CarLightsLouisvilleCounty"] = "PoliceLights",
    ["Base.CarLightsMuldraughPolice"]  = "PoliceLights",
    ["Base.CarLightsPolice"]           = "PoliceLights",
    ["Base.CarLightsRanger"]           = "PoliceLights",

    --------------------------------------------------------
    -- PoliceLightsModern (modern police sedans)
    --------------------------------------------------------
    ["Base.ModernCarLightsCityLouisvillePD"] = "PoliceLightsModern",
    ["Base.ModernCarLightsMeadeSheriff"]     = "PoliceLightsModern",
    ["Base.ModernCarLightsWestPoint"]        = "PoliceLightsModern",

    --------------------------------------------------------
    -- Taxi
    --------------------------------------------------------
    ["Base.CarTaxi"]  = "Taxi",
    ["Base.CarTaxi2"] = "Taxi",

    --------------------------------------------------------
    -- PickupTruck (non-lightbar pickups)
    --------------------------------------------------------
    ["Base.PickUpTruckJPLandscaping"] = "PickupTruck",
    ["Base.PickUpTruckMccoy"]         = "PickupTruck",
    ["Base.PickUpTruck_Camo"]         = "PickupTruck",

    --------------------------------------------------------
    -- PickupTruckLights (lightbar pickups)
    --------------------------------------------------------
    ["Base.PickUpTruckLightsAirport"]         = "PickupTruckLights",
    ["Base.PickUpTruckLightsAirportSecurity"] = "PickupTruckLights",
    ["Base.PickUpTruckLightsFire"]            = "PickupTruckLights",
    ["Base.PickUpTruckLightsFossoil"]         = "PickupTruckLights",
    ["Base.PickUpTruckLightsRanger"]          = "PickupTruckLights",

    --------------------------------------------------------
    -- PickupVan (non-lightbar pickup vans)
    --------------------------------------------------------
    ["Base.PickUpVanBrickingIt"]       = "PickupVan",
    ["Base.PickUpVanBuilder"]          = "PickupVan",
    ["Base.PickUpVanCallowayLandscaping"] = "PickupVan",
    ["Base.PickUpVanHeltonMetalWorking"]  = "PickupVan",
    ["Base.PickUpVanKimbleKonstruction"]  = "PickupVan",
    ["Base.PickUpVanMccoy"]            = "PickupVan",
    ["Base.PickUpVanMetalworker"]      = "PickupVan",
    ["Base.PickUpVanWeldingbyCamille"] = "PickupVan",
    ["Base.PickUpVanYingsWood"]        = "PickupVan",
    ["Base.PickUpVan_Camo"]            = "PickupVan",

    --------------------------------------------------------
    -- PickupVanLights (lightbar pickup vans)
    --------------------------------------------------------
    ["Base.PickUpVanLightsCarpenter"]       = "PickupVanLights",
    ["Base.PickUpVanLightsFire"]            = "PickupVanLights",
    ["Base.PickUpVanLightsFossoil"]         = "PickupVanLights",
    ["Base.PickUpVanLightsKentuckyLumber"]  = "PickupVanLights",
    ["Base.PickUpVanLightsLouisvilleCounty"] = "PickupVanLights",
    ["Base.PickUpVanLightsPolice"]          = "PickupVanLights",
    ["Base.PickUpVanLightsRanger"]          = "PickupVanLights",
    ["Base.PickUpVanLightsStatePolice"]     = "PickupVanLights",
    ["Base.PickUpVanMarchRidgeConstruction"] = "PickupVanLights",

    --------------------------------------------------------
    -- VanBase (standard cargo vans)
    --------------------------------------------------------
    ["Base.VanBeckmans"] = "VanBase",
    ["Base.VanBrewsterHarbin"] = "VanBase",
    ["Base.VanBuilder"] = "VanBase",
    ["Base.VanCarpenter"] = "VanBase",
    ["Base.VanCoastToCoast"] = "VanBase",
    ["Base.VanDeerValley"] = "VanBase",
    ["Base.VanFossoil"] = "VanBase",
    ["Base.VanGardenGods"] = "VanBase",
    ["Base.VanGardener"] = "VanBase",
    ["Base.VanGreenes"] = "VanBase",
    ["Base.VanJohnMcCoy"] = "VanBase",
    ["Base.VanJonesFabrication"] = "VanBase",
    ["Base.VanKerrHomes"] = "VanBase",
    ["Base.VanKnobCreekGas"] = "VanBase",
    ["Base.VanKnoxCom"] = "VanBase",
    ["Base.VanKorshunovs"] = "VanBase",
    ["Base.VanLouisvilleLandscaping"] = "VanBase",
    ["Base.VanMccoy"] = "VanBase",
    ["Base.VanMechanic"] = "VanBase",
    ["Base.VanMeltingPointMetal"] = "VanBase",
    ["Base.VanMetalheads"] = "VanBase",
    ["Base.VanMetalworker"] = "VanBase",
    ["Base.VanMicheles"] = "VanBase",
    ["Base.VanMobileMechanics"] = "VanBase",
    ["Base.VanMooreMechanics"] = "VanBase",
    ["Base.VanOldMill"] = "VanBase",
    ["Base.VanOvoFarm"] = "VanBase",
    ["Base.VanPennSHam"] = "VanBase",
    ["Base.VanPlattAuto"] = "VanBase",
    ["Base.VanPluggedInElectrics"] = "VanBase",
    ["Base.VanRadio"] = "VanBase",
    ["Base.VanRadio_3N"] = "VanBase",
    ["Base.VanRiversideFabrication"] = "VanBase",
    ["Base.VanRosewoodworking"] = "VanBase",
    ["Base.VanSchwabSheetMetal"] = "VanBase",
    ["Base.VanSpiffo"] = "VanBase",
    ["Base.VanTreyBaines"] = "VanBase",
    ["Base.VanUncloggers"] = "VanBase",
    ["Base.VanWPCarpentry"] = "VanBase",
    ["Base.Van_Blacksmith"] = "VanBase",
    ["Base.Van_BugWipers"] = "VanBase",
    ["Base.Van_Charlemange_Beer"] = "VanBase",
    ["Base.Van_CraftSupplies"] = "VanBase",
    ["Base.Van_Glass"] = "VanBase",
    ["Base.Van_HeritageTailors"] = "VanBase",
    ["Base.Van_KnoxDisti"] = "VanBase",
    ["Base.Van_Leather"] = "VanBase",
    ["Base.Van_LectroMax"] = "VanBase",
    ["Base.Van_Locksmith"] = "VanBase",
    ["Base.Van_Masonry"] = "VanBase",
    ["Base.Van_MassGenFac"] = "VanBase",
    ["Base.Van_Perfick_Potato"] = "VanBase",
    ["Base.Van_Transit"] = "VanBase",
    ["Base.Van_VoltMojo"] = "VanBase",

    --------------------------------------------------------
    -- VanAmbulance
    --------------------------------------------------------
    ["Base.VanAmbulance"] = "VanAmbulance",

    --------------------------------------------------------
    -- VanMail
    --------------------------------------------------------
    ["Base.VanMail"] = "VanMail",

    --------------------------------------------------------
    -- VanShuttle (multi-seat)
    --------------------------------------------------------
    ["Base.VanSeats"] = "VanShuttle",
    ["Base.VanSeatsAirportShuttle"] = "VanShuttle",
    ["Base.VanSeats_Prison"] = "VanShuttle",

    --------------------------------------------------------
    -- VanTwoSeat (decorative)
    --------------------------------------------------------
    ["Base.VanSeats_Creature"] = "VanTwoSeat",
    ["Base.VanSeats_LadyDelighter"] = "VanTwoSeat",
    ["Base.VanSeats_Mural"] = "VanTwoSeat",
    ["Base.VanSeats_Space"] = "VanTwoSeat",
    ["Base.VanSeats_Trippy"] = "VanTwoSeat",
    ["Base.VanSeats_Valkyrie"] = "VanTwoSeat",

    --------------------------------------------------------
    -- StepVan
    --------------------------------------------------------
    ["Base.StepVanAirportCatering"] = "StepVan",
    ["Base.StepVanMail"] = "StepVan",
    ["Base.StepVan_Blacksmith"] = "StepVan",
    ["Base.StepVan_Butchers"] = "StepVan",
    ["Base.StepVan_Cereal"] = "StepVan",
    ["Base.StepVan_Citr8"] = "StepVan",
    ["Base.StepVan_CompleteRepairShop"] = "StepVan",
    ["Base.StepVan_Florist"] = "StepVan",
    ["Base.StepVan_Genuine_Beer"] = "StepVan",
    ["Base.StepVan_Glass"] = "StepVan",
    ["Base.StepVan_Heralds"] = "StepVan",
    ["Base.StepVan_HuangsLaundry"] = "StepVan",
    ["Base.StepVan_Jorgensen"] = "StepVan",
    ["Base.StepVan_LouisvilleMotorShop"] = "StepVan",
    ["Base.StepVan_LouisvilleSWAT"] = "StepVan",
    ["Base.StepVan_MarineBites"] = "StepVan",
    ["Base.StepVan_Masonry"] = "StepVan",
    ["Base.StepVan_Mechanic"] = "StepVan",
    ["Base.StepVan_MobileLibrary"] = "StepVan",
    ["Base.StepVan_Plonkies"] = "StepVan",
    ["Base.StepVan_Propane"] = "StepVan",
    ["Base.StepVan_RandisPlants"] = "StepVan",
    ["Base.StepVan_Scarlet"] = "StepVan",
    ["Base.StepVan_SmartKut"] = "StepVan",
    ["Base.StepVan_SouthEasternHosp"] = "StepVan",
    ["Base.StepVan_SouthEasternPaint"] = "StepVan",
    ["Base.StepVan_USL"] = "StepVan",
    ["Base.StepVan_Zippee"] = "StepVan",

    --------------------------------------------------------
    -- Trailers
    --------------------------------------------------------
    ["Base.Trailer"] = "TrailerBase",

    ["Base.TrailerAdvert"] = "TrailerAdvert",
    ["Base.TrailerCover"]  = "TrailerAdvert",

    ["Base.Trailer_Horsebox"] = "TrailerAnimal",
    ["Base.Trailer_Livestock"] = "TrailerAnimal",
}

------------------------------------------------------------
-- PART SETS
-- (Unchanged from your original)
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

    StepVan = {
        "DoorRear",
        "DoorFrontLeft","DoorFrontRight",
        "TruckBed",
        "Windshield","WindshieldRear",
        "WindowFrontLeft","WindowFrontRight",
        "SeatFrontLeft","SeatFrontRight",
        "GloveBox","Radio","PassengerCompartment",
        "GasTank","Battery","Engine","Muffler","EngineDoor","Heater",
        "TireFrontLeft","TireFrontRight","TireRearLeft","TireRearRight",
        "BrakeFrontLeft","BrakeFrontRight","BrakeRearLeft","BrakeRearRight",
        "SuspensionFrontLeft","SuspensionFrontRight",
        "SuspensionRearLeft","SuspensionRearRight",
        "HeadlightLeft","HeadlightRight",
        "HeadlightRearLeft","HeadlightRearRight"
    }


}


------------------------------------------------------------
-- SWAP PAIRS
-- Manually defined lists per group (original structure)
------------------------------------------------------------
SwapVehicleRegistry.SwapPairs = {

    PoliceLights = {
        "Base.CarLightsBulletinSheriff",
        "Base.CarLightsKST",
        "Base.CarLightsLouisvilleCounty",
        "Base.CarLightsMuldraughPolice",
        "Base.CarLightsPolice",
        "Base.CarLightsRanger",
    },

    PoliceLightsModern = {
        "Base.ModernCarLightsCityLouisvillePD",
        "Base.ModernCarLightsMeadeSheriff",
        "Base.ModernCarLightsWestPoint",
    },

    Taxi = {
        "Base.CarTaxi",
        "Base.CarTaxi2",
    },

    PickupTruck = {
        "Base.PickUpTruckJPLandscaping",
        "Base.PickUpTruckMccoy",
        "Base.PickUpTruck_Camo",
    },

    PickupTruckLights = {
        "Base.PickUpTruckLightsAirport",
        "Base.PickUpTruckLightsAirportSecurity",
        "Base.PickUpTruckLightsFire",
        "Base.PickUpTruckLightsFossoil",
        "Base.PickUpTruckLightsRanger",
    },

    PickupVan = {
        "Base.PickUpVanBrickingIt",
        "Base.PickUpVanBuilder",
        "Base.PickUpVanCallowayLandscaping",
        "Base.PickUpVanHeltonMetalWorking",
        "Base.PickUpVanKimbleKonstruction",
        "Base.PickUpVanMarchRidgeConstruction",
        "Base.PickUpVanMccoy",
        "Base.PickUpVanMetalworker",
        "Base.PickUpVanWeldingbyCamille",
        "Base.PickUpVanYingsWood",
        "Base.PickUpVan_Camo",
    },

    PickupVanLights = {
        "Base.PickUpVanLightsCarpenter",
        "Base.PickUpVanLightsFire",
        "Base.PickUpVanLightsFossoil",
        "Base.PickUpVanLightsKentuckyLumber",
        "Base.PickUpVanLightsLouisvilleCounty",
        "Base.PickUpVanLightsPolice",
        "Base.PickUpVanLightsRanger",
        "Base.PickUpVanLightsStatePolice",
    },

    VanBase = {
        "Base.VanBeckmans",
        "Base.VanBrewsterHarbin",
        "Base.VanBuilder",
        "Base.VanCarpenter",
        "Base.VanCoastToCoast",
        "Base.VanDeerValley",
        "Base.VanFossoil",
        "Base.VanGardenGods",
        "Base.VanGardener",
        "Base.VanGreenes",
        "Base.VanJohnMcCoy",
        "Base.VanJonesFabrication",
        "Base.VanKerrHomes",
        "Base.VanKnobCreekGas",
        "Base.VanKnoxCom",
        "Base.VanKorshunovs",
        "Base.VanLouisvilleLandscaping",
        "Base.VanMccoy",
        "Base.VanMechanic",
        "Base.VanMeltingPointMetal",
        "Base.VanMetalheads",
        "Base.VanMetalworker",
        "Base.VanMicheles",
        "Base.VanMobileMechanics",
        "Base.VanMooreMechanics",
        "Base.VanOldMill",
        "Base.VanOvoFarm",
        "Base.VanPennSHam",
        "Base.VanPlattAuto",
        "Base.VanPluggedInElectrics",
        "Base.VanRadio",
        "Base.VanRadio_3N",
        "Base.VanRiversideFabrication",
        "Base.VanRosewoodworking",
        "Base.VanSchwabSheetMetal",
        "Base.VanSpiffo",
        "Base.VanTreyBaines",
        "Base.VanUncloggers",
        "Base.VanWPCarpentry",
        "Base.Van_Blacksmith",
        "Base.Van_BugWipers",
        "Base.Van_Charlemange_Beer",
        "Base.Van_CraftSupplies",
        "Base.Van_Glass",
        "Base.Van_HeritageTailors",
        "Base.Van_KnoxDisti",
        "Base.Van_Leather",
        "Base.Van_LectroMax",
        "Base.Van_Locksmith",
        "Base.Van_Masonry",
        "Base.Van_MassGenFac",
        "Base.Van_Perfick_Potato",
        "Base.Van_Transit",
        "Base.Van_VoltMojo",
    },

    VanAmbulance = {
        "Base.VanAmbulance",
    },

    VanMail = {
        "Base.VanMail",
    },

    VanShuttle = {
        "Base.VanSeats",
        "Base.VanSeatsAirportShuttle",
        "Base.VanSeats_Prison",
    },

    VanTwoSeat = {
        "Base.VanSeats_Creature",
        "Base.VanSeats_LadyDelighter",
        "Base.VanSeats_Mural",
        "Base.VanSeats_Space",
        "Base.VanSeats_Trippy",
        "Base.VanSeats_Valkyrie",
    },

    StepVan = {
        "Base.StepVanAirportCatering",
        "Base.StepVanMail",
        "Base.StepVan_Blacksmith",
        "Base.StepVan_Butchers",
        "Base.StepVan_Cereal",
        "Base.StepVan_Citr8",
        "Base.StepVan_CompleteRepairShop",
        "Base.StepVan_Florist",
        "Base.StepVan_Genuine_Beer",
        "Base.StepVan_Glass",
        "Base.StepVan_Heralds",
        "Base.StepVan_HuangsLaundry",
        "Base.StepVan_Jorgensen",
        "Base.StepVan_LouisvilleMotorShop",
        "Base.StepVan_LouisvilleSWAT",
        "Base.StepVan_MarineBites",
        "Base.StepVan_Masonry",
        "Base.StepVan_Mechanic",
        "Base.StepVan_MobileLibrary",
        "Base.StepVan_Plonkies",
        "Base.StepVan_Propane",
        "Base.StepVan_RandisPlants",
        "Base.StepVan_Scarlet",
        "Base.StepVan_SmartKut",
        "Base.StepVan_SouthEasternHosp",
        "Base.StepVan_SouthEasternPaint",
        "Base.StepVan_USL",
        "Base.StepVan_Zippee",
    },

    TrailerBase = {
        "Base.Trailer",
    },

    TrailerAdvert = {
        "Base.TrailerAdvert",
        "Base.TrailerCover",
    },

    TrailerAnimal = {
        "Base.Trailer_Horsebox",
        "Base.Trailer_Livestock",
    },
}

------------------------------------------------------------
-- End of Vanilla Registry (Updated)
------------------------------------------------------------
