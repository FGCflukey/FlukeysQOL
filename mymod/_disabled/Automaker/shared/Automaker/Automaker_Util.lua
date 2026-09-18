-- Automaker_Util.lua
-- Shared logic for the Automaker vehicle-building feature. Ported
-- from the original B41 "Auto Maker" mod (UGAM) and re-verified
-- against the current game install -- every native call this file
-- uses (addVehicleDebug, buildUtil.*, getScriptManager():
-- getAllVehicleScripts(), Script:getMechanicType()) was confirmed
-- still present in vanilla B42 source before porting.

Automaker_Util = {}

-----------------------------------------------------
-- Vehicles that aren't really "buildable cars" -- special
-- vehicles, trailers, boats, RVs -- plus a couple of specific
-- exclusions the original mod authors carved out for vehicles
-- added by other mods they were running at the time. Left as-is
-- from the original; harmless to keep even if you're not running
-- those specific mods.
-----------------------------------------------------
function Automaker_Util.isBlacklisted(vehicleID)
    local blacklist = {
        ATAArmyBus = true, ATAPrisonBus = true, ATASchoolBus = true,
        BoatMotor = true, BoatMotor_Ground = true,
        BoatSailingYacht = true, BoatSailingYacht_Ground = true,
        ["86bounder"] = true, ["86econolinerv"] = true,
        schoolbus = true, schoolbusshort = true,
        Trailercamperscamp = true, TrailerHome = true,
        TrailerHomeExplorer = true, TrailerHomeHartman = true,
        TrailerWithBoatMotor = true, TrailerWithBoatSailingYacht = true,
        BoatZeroPatient = true, TrailerAMCWaverunner = true,
        AMC_Waverunner = true, TrailerAMCWaverunnerWithBody = true,
        TrailerWithBoat = true, BoatSailingYacht_shipwreckland = true,
    }

    if blacklist[vehicleID] then return true end

    -- Expanded Helicopter Events mod vehicles
    if string.find(vehicleID, "Bell206") then return true end
    if string.find(vehicleID, "SupplyDrop") then return true end
    if string.find(vehicleID, "UH1H") then return true end
    if string.find(vehicleID, "UH60") then return true end

    return false
end

-----------------------------------------------------
-- Cosmetic display-name overrides for specific vanilla
-- vehicle variants that don't have a friendly translated
-- name of their own. Anything not listed falls back to the
-- normal IGUI_VehicleName<ID> translation.
-----------------------------------------------------
local RealNames = {
    CarTaxi = "Yellow Taxi",
    CarTaxi2 = "Green Taxi",
    CarLightsPolice = "Chevalier Nyala: Police",
    TrailerAdvert = "Advert Trailer",
    TrailerCover = "Small Covered Trailer",
    ["92crownvicRavenCreek"] = "1992 Crown Vic Raven Creek PD",
    ["92crownvicMetroAirport"] = "1992 Crown Vic Metro Airport PD",
    ["85vicKnoxSheriff"] = "1985 Crown Vic Knox County Sheriff",
    ["92crownvicMatthews"] = "1992 Crown Vic St. Matthews PD",
    ["92crownvicUSAF"] = "1992 Crown Vic USAF",
    Trailer = "Small Open Trailer",
    ["92crownvicLDOC"] = "1992 Crown Vic Louisville Corrections",
    CarLights = "Kentucky Ranger",
    ["92crownvicWestPointSpecial"] = "1992 Crown Vic West Point PD 'special'",
    ["92crownvicWestPoint"] = "1992 Crown Vic West Point PD",
    ["92crownvicBlackwood"] = "1992 Crown Vic Blackwood PD",
    ["92crownvicRavenCreekTransit"] = "1992 Crown Vic Raven Creek Transit PD",
    ["92crownvicLynnview"] = "1992 Crown Vic Lynnview PD",
    ["85vicUK"] = "1985 Crown Vic University of Kentucky",
}

function Automaker_Util.getVehicleRealName(vehicleID)
    return RealNames[vehicleID] or getText("IGUI_VehicleName" .. vehicleID)
end

-----------------------------------------------------
-- Display names for the build materials, since the raw type
-- strings (matching getMaterialReq's keys) aren't what the
-- player sees on the item itself. Confirmed against the real
-- translation file (shared/Translate/EN/ItemName.json), not
-- guessed.
-----------------------------------------------------
local MaterialLabels = {
    SheetMetal = "Steel Sheet",
    MetalBar = "Steel Rod",
    ElectronicsScrap = "Scrap Electronics",
    ElectricWire = "Electrical Wire",
    EngineParts = "Spare Engine Parts",
}

function Automaker_Util.getMaterialLabel(materialType)
    return MaterialLabels[materialType] or materialType
end

-----------------------------------------------------
-- Material + skill requirements per mechanic tier.
-- Script:getMechanicType() -- 1=standard 2=heavy duty 3=sports.
-- Anything else (our added "Other Models" bucket, for vehicles
-- from mods that never set a mechanic type at all) falls through
-- to the toughest tier on purpose -- better an expensive build
-- than a free one for unclassified vehicles.
-----------------------------------------------------
function Automaker_Util.getMaterialReq(mechanictype, buildCheat)
    if buildCheat then
        return { SheetMetal = 0, MetalBar = 0, ElectronicsScrap = 0, ElectricWire = 0, EngineParts = 0 }
    end

    local ret
    if mechanictype == 1 then
        ret = { SheetMetal = 50, MetalBar = 35, ElectronicsScrap = 30, ElectricWire = 30, EngineParts = 40 }
    elseif mechanictype == 2 then
        ret = { SheetMetal = 80, MetalBar = 45, ElectronicsScrap = 30, ElectricWire = 35, EngineParts = 50 }
    elseif mechanictype == 3 then
        ret = { SheetMetal = 60, MetalBar = 40, ElectronicsScrap = 40, ElectricWire = 35, EngineParts = 60 }
    else
        ret = { SheetMetal = 80, MetalBar = 80, ElectronicsScrap = 80, ElectricWire = 80, EngineParts = 80 }
    end

    if not SandboxVars.Automaker.fullbuild then
        for k, v in pairs(ret) do
            ret[k] = math.floor(v / 3)
        end
    end

    return ret
end

function Automaker_Util.getSkillReq(player, mechanictype)
    if isAdmin() and player:isBuildCheat() then
        return 0, 0, 0
    elseif mechanictype == 1 then
        return 5, 5, 6
    elseif mechanictype == 2 then
        return 7, 7, 6
    elseif mechanictype == 3 then
        return 9, 9, 6
    else
        return 11, 11, 11
    end
end

function Automaker_Util.recipeForType(mechanictype)
    if mechanictype == 1 then return "Automaker Basics"
    elseif mechanictype == 2 then return "Automaker Intermediate"
    elseif mechanictype == 3 then return "Automaker Expert"
    else return "Automaker Expert" -- toughest recipe gate for the Other bucket too
    end
end

-----------------------------------------------------
-- Full eligibility check -- used both client-side (to
-- enable/disable the Build button) and server-side (skill
-- + recipe knowledge only; see Automaker_Server.lua for why
-- the material-on-ground check isn't duplicated there).
-----------------------------------------------------
function Automaker_Util.canBuild(player, mechanictype)
    local buildCheat = isAdmin() and player:isBuildCheat()

    local mechanicReq, metalworkReq, electricalReq = Automaker_Util.getSkillReq(player, mechanictype)
    if player:getPerkLevel(Perks.Mechanics) < mechanicReq then return false, "skill" end
    if player:getPerkLevel(Perks.MetalWelding) < metalworkReq then return false, "skill" end
    if player:getPerkLevel(Perks.Electricity) < electricalReq then return false, "skill" end

    if not player:getKnownRecipes():contains(Automaker_Util.recipeForType(mechanictype)) then
        return false, "recipe"
    end

    if not buildCheat then
        local materialReqs = Automaker_Util.getMaterialReq(mechanictype, false)
        local groundItems = buildUtil.getMaterialOnGround(player:getSquare())
        local groundItemCounts = buildUtil.getMaterialOnGroundCounts(groundItems)
        local playerInv = player:getInventory()

        for k, v in pairs(materialReqs) do
            local nbOfItem = playerInv:getCountTypeEvalRecurse(k, buildUtil.predicateMaterial)
            if groundItemCounts[k] then
                nbOfItem = nbOfItem + groundItemCounts[k]
            end
            if nbOfItem < v then
                return false, "materials"
            end
        end
    end

    return true, nil
end

-----------------------------------------------------
-- Consumes materials for a build. Server-side, authoritative --
-- written from scratch rather than delegating to vanilla's
-- buildUtil.consumeMaterial, which turned out broken in both
-- directions that were tried:
--   * called server-side, it crashed outright: a NullPointerException
--     inside vanilla's own sendRemoveItemFromContainer, because
--     item:getContainer() comes back nil the moment it's re-checked
--     immediately after Remove() has already cleared it.
--   * called client-side (the original B41 round-trip), it hit the
--     exact same nil-after-remove case silently instead of crashing:
--     the local/predicted removal looked fine client-side (no error,
--     items visually gone), but the resulting sendRemoveItemFromContainer
--     call never reached the server with a valid container, so the
--     server's real inventory never actually lost the items -- proven
--     by them all reappearing intact on reconnect (a classic
--     client-predicted-but-never-synced desync).
-- This version captures each item's container BEFORE removing it, so
-- the sync call always gets a valid, non-nil container, and it runs
-- authoritatively on the server like everything else in this pack.
--
-- All materials use the "Base." module prefix -- ElectricWire is
-- declared under `module Base` in vanilla's normal.txt like every
-- other material here; a leftover "Radio." prefix ported from the
-- B41 original meant it could never be found/consumed.
-----------------------------------------------------
function Automaker_Util.takeMaterials(player, mechanictype)
    local buildCheat = player:isBuildCheat()
    local materials = Automaker_Util.getMaterialReq(mechanictype, buildCheat)
    local playerInv = player:getInventory()

    for m, needCount in pairs(materials) do
        local itemFullType = "Base." .. m
        local remaining = needCount

        local items = playerInv:getSomeTypeEvalRecurse(itemFullType, buildUtil.predicateMaterial, remaining)
        for i = 1, items:size() do
            if remaining <= 0 then break end
            local item = items:get(i - 1)
            local container = item:getContainer()
            player:removeFromHands(item)
            if container then
                container:Remove(item)
                sendRemoveItemFromContainer(container, item)
            else
                playerInv:Remove(item)
                sendRemoveItemFromContainer(playerInv, item)
            end
            remaining = remaining - 1
        end

        if remaining > 0 then
            local groundItems = buildUtil.getMaterialOnGround(player:getSquare())
            local onGround = groundItems[itemFullType]
            if onGround then
                local count = math.min(remaining, #onGround)
                for i = 1, count do
                    local worldObj = onGround[i]:getWorldItem()
                    worldObj:getSquare():transmitRemoveItemFromSquare(worldObj)
                end
                remaining = remaining - count
            end
        end

        if remaining > 0 then
            print("[Automaker] WARNING: could not find all required " .. m .. " for " .. tostring(player:getUsername()))
        end
    end
end

-----------------------------------------------------
-- Every non-wreck, non-blacklisted vehicle script, bucketed
-- by mechanic type. mechanictype 0 = "Other" -- anything a
-- mod added that never set a real mechanic type, so it isn't
-- silently invisible to the whole feature.
-----------------------------------------------------
function Automaker_Util.collectBuildableVehicles()
    local buckets = { [1] = {}, [2] = {}, [3] = {}, [0] = {} }

    local allScripts = getScriptManager():getAllVehicleScripts()
    for i = 1, allScripts:size() do
        local script = allScripts:get(i - 1)
        local name = script:getName()

        if not Automaker_Util.isBlacklisted(name)
            and not string.find(name, "Smashed")
            and not string.find(name, "Burnt")
            and not string.find(name, "shipwreck") then

            local mt = script:getMechanicType()
            if mt ~= 1 and mt ~= 2 and mt ~= 3 then
                mt = 0
            end

            table.insert(buckets[mt], { fullName = script:getFullName(), name = name })
        end
    end

    return buckets
end
