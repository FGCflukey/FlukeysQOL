--
-- PaintVehicle_Context.lua
-- Context menu + spraycan-based repaint integration
--

require "PaintVehicle_Action"

local function OnFillWorldObjectContextMenu_PaintVehicle(playerNum, context, worldobjects, test)
    if test then return end

    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return end

    local vehicle = ISVehicleMenu.getVehicleToInteractWith(playerObj)
    if not vehicle then return end

    -----------------------------------------------------
    -- Script Name
    -----------------------------------------------------
    local script = vehicle:getScript()
    local scriptName = script and script:getName() or ""

    -----------------------------------------------------
    -- Blocklist (keyword-based)
    -----------------------------------------------------
    local blockedKeywords = {
        "Ambulance","Blacksmith","Burnt","Butchers","Cereal","CraftSupplies",
        "Fire","Florist","Fossoil","_Glass","Genuine_Beer","Gigamart","Greenes",
        "Heralds","Jorgensen","JoyToy","Knox","Landscaping","Laundry","LectroMax",
        "LightsKST","Locksmith","LouisvilleCounty","LouisvillePD","LouisvilleSWAT",
        "Lumber","Mail","Masonry","MassGen","MassGenFac","McCoy","Mccoy",
        "MeltingPoint","News","OvoFarm","Plonkies","Police","Postal","Prison",
        "Radio","Ranger","Scarlet","SouthEasternHosp","SouthEasternPaint",
        "Spiffo","Taxi","Trailer","Transit","Trippy","Uncloggers","Utility",
        "YingsWood","Zippee",
    }

    local function isBlockedCommercial(name)
        for _, keyword in ipairs(blockedKeywords) do
            if string.find(name, keyword) then
                return true
            end
        end
        return false
    end

    if isBlockedCommercial(scriptName) then
        print("[VehiclePaint] Blocked repaint for commercial vehicle:", scriptName)
        return
    end

    -----------------------------------------------------
    -- Check for "Vehicle" submenu
    -----------------------------------------------------
    local hasVehicleSubmenu = false
    if context and context.getOptionFromIndex and context.getOptionCount then
        local count = context:getOptionCount()
        if type(count) == "number" then
            for i = 1, count do
                local opt = context:getOptionFromIndex(i)
                if opt and type(opt.name) == "string" and opt.name == "Vehicle" then
                    hasVehicleSubmenu = true
                    break
                end
            end
        end
    end

    -----------------------------------------------------
    -- Fallback: allow repaint if HSV + no texture mask
    -----------------------------------------------------
    local allowRepaint = hasVehicleSubmenu

    if not allowRepaint then
        if type(vehicle.setColorHSV) == "function" then
            local mask = vehicle.getTextureMask and vehicle:getTextureMask()
            if mask == nil or mask == "" then
                allowRepaint = true
            end
        end
    end

    if not allowRepaint then return end

    -----------------------------------------------------
    -- SPRAYCAN LOOKUP TABLE
    -----------------------------------------------------
    local SpraycanItems = {
        White = "Base.SpraycanWhite",
        Black = "Base.SpraycanBlack",
        Gray = "Base.SpraycanGray",
        DarkGray = "Base.SpraycanDarkGray",
        Red = "Base.SpraycanRed",
        Blue = "Base.SpraycanBlue",
        Green = "Base.SpraycanGreen",
        Yellow = "Base.SpraycanYellow",
        Orange = "Base.SpraycanOrange",
        Purple = "Base.SpraycanPurple",
        PastelBlue = "Base.SpraycanPastelBlue",
        PastelPink = "Base.SpraycanPastelPink",
        PastelGreen = "Base.SpraycanPastelGreen",
        PastelYellow = "Base.SpraycanPastelYellow",
        Mauve = "Base.SpraycanMauve",
        Brown = "Base.SpraycanBrown",
        Tan = "Base.SpraycanTan",
        Olive = "Base.SpraycanOlive",
        ForestGreen = "Base.SpraycanForestGreen",
        Pink = "Base.SpraycanPink",
        Cyan = "Base.SpraycanCyan",
    }

    -----------------------------------------------------
    -- Check if player has ANY spraycan
    -----------------------------------------------------
    local inv = playerObj:getInventory()
    local hasAnySpraycan = false

    for _, itemName in pairs(SpraycanItems) do
        if inv:containsTypeRecurse(itemName) then
            hasAnySpraycan = true
            break
        end
    end

    if not hasAnySpraycan then return end

    -----------------------------------------------------
    -- MAIN OPTION
    -----------------------------------------------------
    local mainOption = context:addOption("Repaint Vehicle", worldobjects, nil)
    local repaintMenu = ISContextMenu:getNew(context)
    context:addSubMenu(mainOption, repaintMenu)

    -----------------------------------------------------
    -- COLOR DEFINITIONS
    -----------------------------------------------------
    local ColorValues = {
        White={0.00,0.00,1.00}, Black={0.00,0.00,0.10},
        Gray={0.00,0.00,0.50}, DarkGray={0.00,0.00,0.32},

        Red={0.00,1.00,0.76}, Blue={0.60,1.00,0.71},
        Green={0.33,0.88,0.45}, Yellow={0.15,1.00,0.84},
        Orange={0.05,1.00,1.00}, Purple={0.76,1.00,0.90},

        PastelBlue={0.58,0.64,0.55}, PastelPink={0.95,0.50,0.88},
        PastelGreen={0.39,0.88,0.67}, PastelYellow={0.15,0.84,0.78},
        Mauve={0.00,0.59,0.52},

        Brown={0.07,0.75,0.45}, Tan={0.12,0.67,0.86},
        Olive={0.20,0.62,0.48}, ForestGreen={0.33,1.00,0.57},

        Pink={0.92,0.88,1.00}, Cyan={0.50,0.94,0.86},
    }

    -----------------------------------------------------
    -- CALLBACKS
    -----------------------------------------------------
    local function onChooseColor(_, playerObj, vehicle, hsv, spraycanItem)
        ISTimedActionQueue.add(
            ISPaintVehicleAction:new(playerObj, vehicle, hsv, spraycanItem, scriptName)
        )
    end

    local function onChooseRandom(_, playerObj, vehicle)
        local hsv = {
            ZombRandFloat(0.0,1.0),
            ZombRandFloat(0.5,1.0),
            ZombRandFloat(0.5,1.0)
        }
        ISTimedActionQueue.add(
            ISPaintVehicleAction:new(playerObj, vehicle, hsv, nil, scriptName)
        )
    end

    -----------------------------------------------------
    -- FLAT LIST OF COLORS
    -----------------------------------------------------
    for colorName, hsv in pairs(ColorValues) do
        local sprayItemType = SpraycanItems[colorName]
        if sprayItemType then
            local spraycanItem = inv:getFirstTypeRecurse(sprayItemType)
            if spraycanItem then
                repaintMenu:addOption(
                    colorName,
                    nil,
                    onChooseColor,
                    playerObj,
                    vehicle,
                    hsv,
                    spraycanItem
                )
            end
        end
    end

    repaintMenu:addOption("Random Color", nil, onChooseRandom, playerObj, vehicle)
end

Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu_PaintVehicle)