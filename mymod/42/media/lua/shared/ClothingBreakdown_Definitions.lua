-- ClothingBreakdown_Definitions.lua

ClothingBreakdown = {
    -- CATEGORY DEFAULTS
    ["base:shoes"] = {
        returns = {
            leather = { item = "Base.LeatherStrips", min = 1, max = 3 },
            denim   = { item = "Base.DenimStrips",   min = 1, max = 2 },
            cotton  = { item = "Base.RippedSheets",  min = 1, max = 3 },
        }
    },

    ["base:jacket"] = {
        returns = {
            leather = { item = "Base.LeatherStrips", min = 2, max = 5 },
            denim   = { item = "Base.DenimStrips",   min = 2, max = 4 },
            cotton  = { item = "Base.RippedSheets",  min = 2, max = 5 },
        }
    },

    ["base:jacketsuit"] = {
        returns = {
            leather = { item = "Base.LeatherStrips", min = 2, max = 5 },
            denim   = { item = "Base.DenimStrips",   min = 2, max = 4 },
            cotton  = { item = "Base.RippedSheets",  min = 2, max = 5 },
        }
    },

    ["base:jacket_bulky"] = {
        returns = {
            leather = { item = "Base.LeatherStrips", min = 2, max = 5 },
            denim   = { item = "Base.DenimStrips",   min = 2, max = 4 },
            cotton  = { item = "Base.RippedSheets",  min = 2, max = 5 },
        }
    },

    ["base:hat"] = {
        returns = {
            cotton = { item = "Base.RippedSheets", min = 1, max = 2 },
            denim  = { item = "Base.DenimStrips",  min = 1, max = 1 },
            leather = { item = "Base.LeatherStrips", min = 1, max = 1 },
        }
    },

    ["base:socks"] = {
        returns = {
            cotton = { item = "Base.RippedSheets", min = 1, max = 2 },
            denim  = { item = "Base.DenimStrips",  min = 1, max = 1 },
            leather = { item = "Base.LeatherStrips", min = 1, max = 1 },
        }
    },

    ["base:hands"] = {
        returns = {
            cotton = { item = "Base.RippedSheets", min = 1, max = 2 },
            denim  = { item = "Base.DenimStrips",  min = 1, max = 1 },
            leather = { item = "Base.LeatherStrips", min = 1, max = 1 },
        }
    },

    ["base:underwearbottom"] = {
        returns = {
            cotton = { item = "Base.RippedSheets", min = 1, max = 2 },
            denim  = { item = "Base.DenimStrips",  min = 1, max = 1 },
            leather = { item = "Base.LeatherStrips", min = 1, max = 1 },
        }
    },

    ["base:underweartop"] = {
        returns = {
            cotton = { item = "Base.RippedSheets", min = 1, max = 2 },
            denim  = { item = "Base.DenimStrips",  min = 1, max = 1 },
            leather = { item = "Base.LeatherStrips", min = 1, max = 1 },
        }
    },

    ["base:underwearextra1"] = {
        returns = {
            cotton = { item = "Base.RippedSheets", min = 1, max = 2 },
            denim  = { item = "Base.DenimStrips",  min = 1, max = 1 },
            leather = { item = "Base.LeatherStrips", min = 1, max = 1 },
        }
    },

    -- ITEM‑SPECIFIC OVERRIDES
    ["Base.Hat_Cowboy_CowHide"] = {
        material = "leather",
        returns = { item = "Base.LeatherStrips", min = 1, max = 3 }
    },

    ["Base.Shoes_ArmyBoots"] = {
        material = "leather",
        returns = { item = "Base.LeatherStrips", min = 1, max = 3 }
    },

    ["Base.Shoes_ArmyBootsDesert"] = {
        material = "leather",
        returns = { item = "Base.LeatherStrips", min = 1, max = 3 }
    },

}