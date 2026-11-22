-- ===================================================================
--  Paint My W900 - shared definitions (client + server)
-- ===================================================================
--  Repaint the W900 Semi-Truck (Workshop 3409472393) and its trailers
--  by switching between the skins that mod already ships with, paid
--  for with vanilla paint cans. Our own build, styled after "Paint my
--  KI5" (3782524328): switch skin index + transmit, server-side.
--
--  Cost rules (a vanilla paint can = 10 uses):
--    truck   = 1 can total  -> one colour: 1 can, two-tone: 1/2 can each
--    trailer = 2 cans total -> one colour: 2 cans, two-tone: 1 can each
--    a colour with no matching vanilla can is mixed: 1 full can of
--    each colour it's mixed from (truck or trailer).
--
--  Skin indexes come straight from the W900 mod's vehicle scripts
--  (checked against its 42.20 files). Duplicate skins on the Lite/Box
--  trucks are left out so each colour appears once. If the W900 mod
--  ever reorders its skins, this table needs updating.
-- ===================================================================

PaintMyW900 = PaintMyW900 or {}

local DEBUG = false
function PaintMyW900.dbg(msg)
    if DEBUG then print("[PaintMyW900] " .. tostring(msg)) end
end

PaintMyW900.USES_PER_CAN = 10
PaintMyW900.EMPTY_CAN = "Base.PaintbucketEmpty"
PaintMyW900.BRUSHES = { "Base.Paintbrush", "Base.PaintbrushCrafted" }

-- Vanilla paint can colour -> item + display name
PaintMyW900.PAINT = {
    Black      = { item = "Base.PaintBlack",      name = "Black" },
    Blue       = { item = "Base.PaintBlue",       name = "Blue" },
    Brown      = { item = "Base.PaintBrown",      name = "Brown" },
    Cyan       = { item = "Base.PaintCyan",       name = "Cyan" },
    Green      = { item = "Base.PaintGreen",      name = "Green" },
    Grey       = { item = "Base.PaintGrey",       name = "Grey" },
    LightBlue  = { item = "Base.PaintLightBlue",  name = "Light Blue" },
    LightBrown = { item = "Base.PaintLightBrown", name = "Light Brown" },
    Orange     = { item = "Base.PaintOrange",     name = "Orange" },
    Pink       = { item = "Base.PaintPink",       name = "Pink" },
    Purple     = { item = "Base.PaintPurple",     name = "Purple" },
    Red        = { item = "Base.PaintRed",        name = "Red" },
    Turquoise  = { item = "Base.PaintTurquoise",  name = "Turquoise" },
    White      = { item = "Base.PaintWhite",      name = "White" },
    Yellow     = { item = "Base.PaintYellow",     name = "Yellow" },
}

---------------------------------------------------------
-- Colours. kind:
--   single = one can colour, uses the whole budget
--   two    = two-tone, budget split evenly
--   mix    = no matching can, 1 full can of each listed colour
---------------------------------------------------------
local C = {
    white       = { label = "White",          kind = "single", paints = { "White" } },
    black       = { label = "Black",          kind = "single", paints = { "Black" } },
    red         = { label = "Red",            kind = "single", paints = { "Red" } },
    blue        = { label = "Blue",           kind = "single", paints = { "Blue" } },
    green       = { label = "Green",          kind = "single", paints = { "Green" } },
    yellow      = { label = "Yellow",         kind = "single", paints = { "Yellow" } },
    skyblue     = { label = "Sky Blue",       kind = "single", paints = { "LightBlue" } },
    amber       = { label = "Amber",          kind = "single", paints = { "Orange" } },
    hotorange   = { label = "Hot Orange",     kind = "single", paints = { "Orange" } },
    crimson     = { label = "Crimson",        kind = "single", paints = { "Red" } },
    lime        = { label = "Lime",           kind = "single", paints = { "Green" } },
    boxwhite    = { label = "White (Box)",    kind = "single", paints = { "White" } },
    cattle1     = { label = "White",          kind = "single", paints = { "White" } },
    cattle2     = { label = "White (Style 2)", kind = "single", paints = { "White" } },

    caspian     = { label = "Caspian Blue",   kind = "mix", paints = { "Blue", "Turquoise" } },
    usmc        = { label = "USMC Green",     kind = "mix", paints = { "Green", "Black" } },
    bronze      = { label = "Bronze",         kind = "mix", paints = { "Brown", "Orange" } },
    magenta     = { label = "Magenta",        kind = "mix", paints = { "Pink", "Purple" } },

    bluepurple  = { label = "Blue / Purple",    kind = "two", paints = { "Blue", "Purple" } },
    blueamber   = { label = "Blue / Amber",     kind = "two", paints = { "Blue", "Orange" } },
    bluecrimson = { label = "Blue / Crimson",   kind = "two", paints = { "Blue", "Red" } },
    bluelime    = { label = "Blue / Lime",      kind = "two", paints = { "Blue", "Green" } },
    bluepink    = { label = "Blue / Neon Pink", kind = "two", paints = { "Blue", "Pink" } },

    camoG1 = { label = "Green Camo 1",  kind = "mix", paints = { "Green", "Brown", "Black" } },
    camoG2 = { label = "Green Camo 2",  kind = "mix", paints = { "Green", "Brown", "Black" } },
    camoG3 = { label = "Green Camo 3",  kind = "mix", paints = { "Green", "Brown", "Black" } },
    camoD1 = { label = "Desert Camo 1", kind = "mix", paints = { "LightBrown", "Brown", "White" } },
    camoD2 = { label = "Desert Camo 2", kind = "mix", paints = { "LightBrown", "Brown", "White" } },
    camoD3 = { label = "Desert Camo 3", kind = "mix", paints = { "LightBrown", "Brown", "White" } },
    camoG  = { label = "Green Camo",    kind = "mix", paints = { "Green", "Brown", "Black" } },
    camoD  = { label = "Desert Camo",   kind = "mix", paints = { "LightBrown", "Brown", "White" } },
}
PaintMyW900.COLORS = C

---------------------------------------------------------
-- Vehicles: script name -> { trailer = bool, skins = { {index, colour}, ... } }
-- Listed in menu order.
---------------------------------------------------------
local TRUCK_STD = {
    { 0, "white" }, { 1, "black" }, { 2, "red" }, { 3, "blue" }, { 4, "caspian" },
    { 5, "yellow" }, { 6, "green" }, { 7, "usmc" }, { 8, "bluepurple" }, { 9, "bronze" },
    { 10, "blueamber" }, { 11, "bluecrimson" }, { 12, "bluelime" }, { 13, "skyblue" },
    { 14, "bluepink" },
}
-- Lite/Box list 4 skins twice (8-11); those duplicates are skipped.
local TRUCK_LITE = {
    { 0, "white" }, { 1, "black" }, { 2, "red" }, { 3, "blue" }, { 4, "caspian" },
    { 5, "yellow" }, { 6, "green" }, { 7, "usmc" }, { 12, "bluepurple" }, { 13, "bronze" },
    { 14, "blueamber" }, { 15, "bluecrimson" }, { 16, "bluelime" }, { 17, "skyblue" },
    { 18, "bluepink" },
}
local TRUCK_BOX = {
    { 0, "boxwhite" }, { 1, "white" }, { 2, "black" }, { 3, "red" }, { 4, "blue" },
    { 5, "caspian" }, { 6, "yellow" }, { 7, "green" }, { 11, "usmc" }, { 12, "bluepurple" },
    { 13, "bronze" }, { 14, "blueamber" }, { 15, "bluecrimson" }, { 16, "bluelime" },
    { 17, "skyblue" }, { 18, "bluepink" },
}
local CAMO6 = {
    { 0, "camoG1" }, { 1, "camoG2" }, { 2, "camoG3" },
    { 3, "camoD1" }, { 4, "camoD2" }, { 5, "camoD3" },
}
local CONTAINER4 = { { 0, "red" }, { 1, "yellow" }, { 2, "green" }, { 3, "blue" } }

PaintMyW900.VEHICLES = {
    SemiTruck        = { trailer = false, skins = TRUCK_STD },
    SemiTruckLite    = { trailer = false, skins = TRUCK_LITE },
    SemiTruckBox     = { trailer = false, skins = TRUCK_BOX },
    SemiTruck_mil    = { trailer = false, skins = CAMO6 },
    SemiTruckBox_mil = { trailer = false, skins = { { 0, "camoG" }, { 1, "camoD" } } },

    SemiTrailerVan = { trailer = true, skins = {
        { 0, "white" }, { 1, "black" }, { 2, "red" }, { 3, "blue" }, { 4, "green" },
        { 5, "yellow" }, { 6, "usmc" }, { 7, "magenta" }, { 8, "amber" }, { 9, "crimson" },
        { 10, "lime" }, { 11, "hotorange" },
    } },
    SemiTrailerVanCattle = { trailer = true, skins = { { 0, "cattle1" }, { 1, "cattle2" } } },
    SemiTrailerVan_mil   = { trailer = true, skins = CAMO6 },
    SemiTrailerContainer = { trailer = true, skins = CONTAINER4 },
    W900_Container       = { trailer = true, skins = CONTAINER4 },
    SemiTrailerCistern   = { trailer = true, skins = { { 0, "white" }, { 1, "black" } } },
}

---------------------------------------------------------
-- Lookups
---------------------------------------------------------
function PaintMyW900.getVehicleDef(vehicle)
    local script = vehicle and vehicle:getScript()
    local name = script and script:getName()
    return name and PaintMyW900.VEHICLES[name] or nil, name
end

-- Colour key for a skin index on this vehicle, or nil.
function PaintMyW900.getColorKey(vehicle, skinIndex)
    local def = PaintMyW900.getVehicleDef(vehicle)
    if not def or type(skinIndex) ~= "number" then return nil end
    for _, s in ipairs(def.skins) do
        if s[1] == skinIndex then return s[2] end
    end
    return nil
end

-- { {paint = "Blue", uses = 5}, ... } for painting this vehicle that colour.
function PaintMyW900.getCost(vehicle, colorKey)
    local def = PaintMyW900.getVehicleDef(vehicle)
    local color = C[colorKey]
    if not def or not color then return nil end
    local per = PaintMyW900.USES_PER_CAN
    local budget = def.trailer and per * 2 or per
    local cost = {}
    if color.kind == "single" then
        cost[1] = { paint = color.paints[1], uses = budget }
    elseif color.kind == "two" then
        for i, p in ipairs(color.paints) do cost[i] = { paint = p, uses = budget / 2 } end
    else -- mix
        for i, p in ipairs(color.paints) do cost[i] = { paint = p, uses = per } end
    end
    return cost
end

---------------------------------------------------------
-- Paint cans: counting and spending (uses can be split across cans)
---------------------------------------------------------
local function canUses(item)
    local delta = item:getUseDelta()
    if not delta or delta <= 0 then return 0 end
    return math.floor(item:getCurrentUsesFloat() / delta + 0.0001)
end

function PaintMyW900.countUses(character, paintKey)
    local items = character:getInventory():getAllTypeRecurse(PaintMyW900.PAINT[paintKey].item)
    local total = 0
    for i = 0, items:size() - 1 do total = total + canUses(items:get(i)) end
    return total
end

function PaintMyW900.hasPaint(character, cost)
    for _, c in ipairs(cost or {}) do
        if PaintMyW900.countUses(character, c.paint) < c.uses then return false end
    end
    return cost ~= nil
end

function PaintMyW900.hasBrush(character)
    local inv = character:getInventory()
    for _, b in ipairs(PaintMyW900.BRUSHES) do
        if inv:containsTypeRecurse(b) then return true end
    end
    return false
end

-- Server side (or solo). Spends the paint; an emptied can becomes an
-- empty paint bucket. Every change is sent to the client explicitly,
-- including the removal (sendItemStats alone leaves a ghost can).
function PaintMyW900.spendPaint(character, cost)
    for _, c in ipairs(cost) do
        local remaining = c.uses
        local items = character:getInventory():getAllTypeRecurse(PaintMyW900.PAINT[c.paint].item)
        local list = {}
        for i = 0, items:size() - 1 do list[#list + 1] = items:get(i) end
        for _, can in ipairs(list) do
            if remaining <= 0 then break end
            local have = canUses(can)
            local take = math.min(have, remaining)
            if take > 0 then
                remaining = remaining - take
                local container = can:getContainer()
                if have - take <= 0 and container then
                    character:removeFromHands(can)
                    container:Remove(can)
                    sendRemoveItemFromContainer(container, can)
                    local empty = container:AddItem(PaintMyW900.EMPTY_CAN)
                    if empty then sendAddItemToContainer(container, empty) end
                else
                    can:setUsedDelta((have - take) * can:getUseDelta())
                    sendItemStats(can)
                end
            end
        end
        if remaining > 0 then
            PaintMyW900.dbg("spendPaint: short " .. remaining .. " uses of " .. c.paint)
            return false
        end
    end
    return true
end

---------------------------------------------------------
-- Conditions (same spirit as FlukeysQOL's PaintVehicle)
---------------------------------------------------------
function PaintMyW900.hasVehicleKey(character, vehicle)
    local keyId = vehicle:getKeyId()
    if not keyId or keyId == -1 then return true end
    return character:getInventory():haveThisKeyId(keyId)
end

function PaintMyW900.isBadWeather()
    local climate = getClimateManager()
    if climate:getRainIntensity() > 0 or climate:getSnowIntensity() > 0 then return true end
    if climate:getFogIntensity() > 0 then return true end
    local storm = climate:getThunderStorm()
    return storm and storm.active or false
end

-- Client only (light level is per local player).
function PaintMyW900.hasEnoughLight(character)
    local square = character:getSquare()
    if not square then return false end
    local idx = character:getPlayerNum()
    if not square:isOutside() then return square:getLightLevel(idx) > 0.3 end
    if getClimateManager():getNightStrength() <= 0.5 then return true end
    return square:getLightLevel(idx) > 0.6
end

function PaintMyW900.isBloody(vehicle)
    if not vehicle.getBloodIntensity then return false end
    for _, side in ipairs({ "Front", "Rear", "Left", "Right" }) do
        if vehicle:getBloodIntensity(side) > 0 then return true end
    end
    return false
end

-- Long trailers: measured from the vehicle's centre, so allow plenty.
PaintMyW900.MAX_DIST = 10

function PaintMyW900.isNear(character, vehicle)
    local dx, dy = character:getX() - vehicle:getX(), character:getY() - vehicle:getY()
    return dx * dx + dy * dy <= PaintMyW900.MAX_DIST * PaintMyW900.MAX_DIST
end

-- Everything the server re-checks before changing anything.
function PaintMyW900.canPaint(character, vehicle, skinIndex)
    if not character or not vehicle or vehicle:isRemovedFromWorld() then return false, "no vehicle" end
    if character:getVehicle() then return false, "in a vehicle" end
    if math.abs(vehicle:getCurrentSpeedKmHour()) > 0.8 then return false, "moving" end
    local key = PaintMyW900.getColorKey(vehicle, skinIndex)
    if not key then return false, "unknown skin" end
    if skinIndex < 0 or skinIndex >= vehicle:getSkinCount() then return false, "skin out of range" end
    if vehicle:getSkinIndex() == skinIndex then return false, "already that colour" end
    if not PaintMyW900.isNear(character, vehicle) then return false, "too far" end
    if not PaintMyW900.hasVehicleKey(character, vehicle) then return false, "no key" end
    if PaintMyW900.isBloody(vehicle) then return false, "bloody" end
    if not PaintMyW900.hasBrush(character) then return false, "no brush" end
    if not PaintMyW900.hasPaint(character, PaintMyW900.getCost(vehicle, key)) then return false, "not enough paint" end
    return true
end

---------------------------------------------------------
-- Time: trailers take longer
---------------------------------------------------------
function PaintMyW900.getPaintTime(vehicle)
    local def = PaintMyW900.getVehicleDef(vehicle)
    return (def and def.trailer) and 1500 or 1000
end

PaintMyW900.NOISE_RADIUS = 15
PaintMyW900.NOISE_VOLUME = 15
PaintMyW900.NOISE_EVERY_MS = 3000
