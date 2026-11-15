-- PaintVehicle_Shared.lua
-- Everything the paint menu (client), the paint action (client) and the server handler
-- all need, kept in one place so the three can't drift apart.

PaintVehicle = PaintVehicle or {}

-----------------------------------------------------
-- COLORS
-----------------------------------------------------
-- Color name -> spraycan item type + the HSV it paints (each 0..1).
-- NAMES is the menu order (alphabetical).
PaintVehicle.COLORS = {
    Black        = { item = "Base.SpraycanBlack",        hsv = { 0.00, 0.00, 0.10 } },
    Blue         = { item = "Base.SpraycanBlue",         hsv = { 0.60, 1.00, 0.71 } },
    Brown        = { item = "Base.SpraycanBrown",        hsv = { 0.07, 0.75, 0.45 } },
    Cyan         = { item = "Base.SpraycanCyan",         hsv = { 0.50, 0.94, 0.86 } },
    DarkGray     = { item = "Base.SpraycanDarkGray",     hsv = { 0.00, 0.00, 0.32 } },
    ForestGreen  = { item = "Base.SpraycanForestGreen",  hsv = { 0.33, 1.00, 0.57 } },
    Gray         = { item = "Base.SpraycanGray",         hsv = { 0.00, 0.00, 0.50 } },
    Green        = { item = "Base.SpraycanGreen",        hsv = { 0.33, 0.88, 0.45 } },
    Mauve        = { item = "Base.SpraycanMauve",        hsv = { 0.00, 0.59, 0.52 } },
    Olive        = { item = "Base.SpraycanOlive",        hsv = { 0.20, 0.62, 0.48 } },
    Orange       = { item = "Base.SpraycanOrange",       hsv = { 0.05, 1.00, 1.00 } },
    PastelBlue   = { item = "Base.SpraycanPastelBlue",   hsv = { 0.58, 0.64, 0.55 } },
    PastelGreen  = { item = "Base.SpraycanPastelGreen",  hsv = { 0.39, 0.88, 0.67 } },
    PastelPink   = { item = "Base.SpraycanPastelPink",   hsv = { 0.95, 0.50, 0.88 } },
    PastelYellow = { item = "Base.SpraycanPastelYellow", hsv = { 0.15, 0.84, 0.78 } },
    Pink         = { item = "Base.SpraycanPink",         hsv = { 0.92, 0.88, 1.00 } },
    Purple       = { item = "Base.SpraycanPurple",       hsv = { 0.76, 1.00, 0.90 } },
    Red          = { item = "Base.SpraycanRed",          hsv = { 0.00, 1.00, 0.76 } },
    Tan          = { item = "Base.SpraycanTan",          hsv = { 0.12, 0.67, 0.86 } },
    White        = { item = "Base.SpraycanWhite",        hsv = { 0.00, 0.00, 1.00 } },
    Yellow       = { item = "Base.SpraycanYellow",       hsv = { 0.15, 1.00, 0.84 } },
}

PaintVehicle.NAMES = {}
for name in pairs(PaintVehicle.COLORS) do table.insert(PaintVehicle.NAMES, name) end
table.sort(PaintVehicle.NAMES)

-- Item type -> color name, so the server can tell which color a spraycan really paints
PaintVehicle.BY_ITEM = {}
for name, c in pairs(PaintVehicle.COLORS) do PaintVehicle.BY_ITEM[c.item] = name end

PaintVehicle.SANDING_BLOCK = "Base.SandingBlock"

-----------------------------------------------------
-- BLOCKED (commercial / faction) VEHICLES
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

function PaintVehicle.isBlockedCommercial(vehicle)
    local script = vehicle and vehicle:getScript()
    local name = script and script:getName() or ""
    for _, keyword in ipairs(blockedKeywords) do
        if string.find(name, keyword, 1, true) then return true, name end
    end
    return false, name
end

-----------------------------------------------------
-- OWNERSHIP (same rule as the vinyl swap system)
-----------------------------------------------------
-- A vehicle with no key system (keyId -1) can't be gated this way, so it's allowed through.
-- haveThisKeyId is the same check vanilla uses (VehicleUtils.RequiredKeyNotFound).
function PaintVehicle.hasVehicleKey(character, vehicle)
    local keyId = vehicle:getKeyId()
    if not keyId or keyId == -1 then return true end
    return character:getInventory():haveThisKeyId(keyId)
end

-----------------------------------------------------
-- WEATHER / LIGHT / CLEANLINESS
-----------------------------------------------------
function PaintVehicle.isBadWeather()
    local climate = getClimateManager()
    if climate:getRainIntensity() > 0 then return true end
    if climate:getSnowIntensity() > 0 then return true end
    if climate:getFogIntensity() > 0 then return true end
    local storm = climate:getThunderStorm()
    if storm and storm.active then return true end
    return false
end

function PaintVehicle.hasEnoughLight(character)
    local square = character:getSquare()
    if not square then return false end
    local playerIndex = character:getPlayerNum()

    -- Indoors: must have some light
    if not square:isOutside() then
        return square:getLightLevel(playerIndex) > 0.3
    end

    -- Outdoors: daytime is always fine, at night it needs strong artificial light
    if getClimateManager():getNightStrength() <= 0.5 then return true end
    return square:getLightLevel(playerIndex) > 0.6
end

function PaintVehicle.isBloody(vehicle)
    if not vehicle or not vehicle.getBloodIntensity then return false end
    for _, side in ipairs({ "Front", "Rear", "Left", "Right" }) do
        if vehicle:getBloodIntensity(side) > 0 then return true end
    end
    return false
end

-----------------------------------------------------
-- PAINT TIME (scales with vehicle size)
-----------------------------------------------------
-- A regular car takes BASE_TIME; bigger/smaller vehicles scale by their footprint
-- (width x length) compared to a vanilla Base.CarNormal, clamped to MIN..MAX.
-- Comparing against a real vanilla car keeps this right whatever units getExtents() uses.
local BASE_TIME, MIN_TIME, MAX_TIME = 600, 400, 1200
local refFootprint = nil

local function footprint(script)
    local ext = script and script:getExtents()
    if not ext then return nil end
    local a = ext:x() * ext:z()
    if a > 0 then return a end
    return nil
end

function PaintVehicle.getPaintTime(vehicle)
    if refFootprint == nil then
        refFootprint = false
        local scripts = getScriptManager():getAllVehicleScripts()
        for i = 0, scripts:size() - 1 do
            local s = scripts:get(i)
            if s:getFullName() == "Base.CarNormal" then
                refFootprint = footprint(s) or false
                break
            end
        end
    end
    local area = footprint(vehicle and vehicle:getScript())
    if not area or not refFootprint then return BASE_TIME end
    local t = math.floor(BASE_TIME * area / refFootprint + 0.5)
    return math.max(MIN_TIME, math.min(MAX_TIME, t))
end

-----------------------------------------------------
-- NOISE (attracts zombies while spraying)
-----------------------------------------------------
PaintVehicle.NOISE_RADIUS   = 20      -- tiles
PaintVehicle.NOISE_VOLUME   = 20
PaintVehicle.NOISE_EVERY_MS = 3000    -- re-emit while the action runs
