------------------------------------------------------------
-- Flip This Car - client
-- Right-click / vehicle radial option -> 3 heaves (vanilla shove animation +
-- thump) -> ask the server. When the server accepts, this player's game also
-- turns the car upright, since it now owns the car's physics.
------------------------------------------------------------

require "FlipThisCar/FlipThisCar_Shared"

local function dbg(msg) FlipThisCar.dbg("Client", msg) end

local ICON = "media/ui/Sidebar/64/Furniture_Rotate_64.png"   -- vanilla icon

------------------------------------------------------------
-- Heaving: a few vanilla shoves before the car goes over
------------------------------------------------------------
local heave = nil   -- { player, vehicle, count, nextAt }

local function playThump(vehicle)
    local sq = vehicle and vehicle:getSquare()
    if sq then sq:playSound(FlipThisCar.SOUND) end
end

-- Same calls Push Vehicle uses to play the real hand-to-hand shove animation
local function shove(player, vehicle)
    player:faceThisObject(vehicle)
    player:setDoShove(true)
    player:setDoGrapple(false)
    player:setAimAtFloor(false)
    player:AttemptAttack(0.0)
end

local function sendRequest(player, vehicle)
    local args = { vehicle = vehicle:getId() }
    if isClient() then
        sendClientCommand(player, FlipThisCar.MODULE, "requestFlip", args)
    elseif FlipThisCar.serverRequest then
        FlipThisCar.serverRequest(player, args)   -- single-player: the server code runs here
    end
end

local function heaveTick()
    if not heave then return end
    local p, v = heave.player, heave.vehicle
    if not p or p:isDead() or p:getVehicle() or not v or v:isRemovedFromWorld()
            or not FlipThisCar.isNear(p, v) then
        if p and not p:isDead() then p:Say(getText("Tooltip_FlipThisCar_Cancelled")) end
        dbg("heave cancelled")
        heave = nil
        Events.OnTick.Remove(heaveTick)
        return
    end
    if getTimestampMs() < heave.nextAt then return end

    heave.count = heave.count + 1
    shove(p, v)
    playThump(v)
    dbg("heave " .. tostring(heave.count) .. "/" .. tostring(FlipThisCar.HEAVES))

    if heave.count >= FlipThisCar.HEAVES then
        heave = nil
        Events.OnTick.Remove(heaveTick)
        sendRequest(p, v)
    else
        heave.nextAt = getTimestampMs() + FlipThisCar.HEAVE_MS
    end
end

local function startFlip(player, vehicle)
    local ok, reason = FlipThisCar.check(player, vehicle)
    if not ok then
        player:Say(getText(reason))
        return
    end
    if heave then return end
    dbg("start heaving vehicle " .. tostring(vehicle:getId()) .. " upDot=" .. tostring(vehicle:getUpVectorDot()))
    heave = { player = player, vehicle = vehicle, count = 0, nextAt = 0 }
    Events.OnTick.Add(heaveTick)
end

------------------------------------------------------------
-- Turning the car on this game once the server says go (MP only)
------------------------------------------------------------
local turning = {}       -- vehicleId -> { vehicle, startedAt }
local turningCount = 0   -- PZ's Kahlua has no next()

local function turnTick()
    local now = getTimestampMs()
    local done = {}
    for id, t in pairs(turning) do
        local v = t.vehicle
        if not v or v:isRemovedFromWorld() then
            table.insert(done, id)
        elseif FlipThisCar.turnStep(v) then
            dbg("vehicle " .. tostring(id) .. " upright on client, angleY=" .. tostring(v:getAngleY()))
            table.insert(done, id)
        elseif now - t.startedAt > FlipThisCar.TIMEOUT_MS then
            v:setPhysicsActive(true, true)
            dbg("vehicle " .. tostring(id) .. " timed out turning on client, upDot=" .. tostring(v:getUpVectorDot()))
            table.insert(done, id)
        end
    end
    for _, id in ipairs(done) do
        turning[id] = nil
        turningCount = turningCount - 1
    end
    if turningCount <= 0 then
        turningCount = 0
        Events.OnTick.Remove(turnTick)
    end
end

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= FlipThisCar.MODULE or not args then return end
    local player = getPlayer()

    if command == "rejected" then
        if player and args.reason then player:Say(getText(args.reason)) end
        return
    end

    if command == "startFlip" then
        local v = getVehicleById(tonumber(args.vehicle) or -1)
        if not v then return end
        playThump(v)
        if not player or player:getOnlineID() ~= args.requester then return end
        -- Mirror the physics ownership the server just gave us (as Push Vehicle does)
        v:authorizationClientCollide(player)
        dbg("server accepted flip of vehicle " .. tostring(args.vehicle) .. ", turning it here too")
        if not turning[v:getId()] then
            if turningCount == 0 then Events.OnTick.Add(turnTick) end
            turningCount = turningCount + 1
        end
        turning[v:getId()] = { vehicle = v, startedAt = getTimestampMs() }
    end
end)

------------------------------------------------------------
-- Menus
------------------------------------------------------------
local function getTargetVehicle(player)
    local v = nil
    if IsoObjectPicker and IsoObjectPicker.Instance then
        v = IsoObjectPicker.Instance:PickVehicle(getMouseXScaled(), getMouseYScaled())
    end
    return v or ISVehicleMenu.getVehicleToInteractWith(player)
end

-- Upright, burnt, or gone: no option at all. Anything else: shown, greyed if not possible.
local function isRelevant(vehicle)
    return vehicle and not vehicle:isRemovedFromWorld()
        and FlipThisCar.needsFlip(vehicle) and not FlipThisCar.isBurnt(vehicle)
end

local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    local player = getSpecificPlayer(playerNum)
    if not player or player:getVehicle() then return end
    local vehicle = getTargetVehicle(player)
    if not isRelevant(vehicle) or not FlipThisCar.isNear(player, vehicle) then return end
    if test then return true end

    local ok, reason = FlipThisCar.check(player, vehicle)
    local option = context:addOption(getText("ContextMenu_FlipThisCar"), player, startFlip, vehicle)

    local tip = ISToolTip:new()
    tip:initialise()
    tip:setVisible(false)
    local strength = player:getPerkLevel(Perks.Strength)
    local need = FlipThisCar.getMinStrength()
    local color = strength >= need and " <RGB:1,1,1> " or " <RGB:1,0.3,0.3> "
    tip.description = getText("Tooltip_FlipThisCar_Desc") .. " <LINE>" .. color
        .. getText("Tooltip_FlipThisCar_Strength", tostring(strength), tostring(need))
    if not ok then
        option.notAvailable = true
        if reason ~= "Tooltip_FlipThisCar_TooWeak" then
            tip.description = tip.description .. " <LINE> <RGB:1,0.3,0.3> " .. getText(reason)
        end
    end
    option.toolTip = tip
end

-- Vehicle radial menu (V key / controller) while standing outside, wrapped the
-- same way Push Vehicle does it: let vanilla build it, then add our slice.
if ISVehicleMenu and ISVehicleMenu.showRadialMenuOutside and not ISVehicleMenu._FlipThisCarHooked then
    ISVehicleMenu._FlipThisCarHooked = true
    local original = ISVehicleMenu.showRadialMenuOutside
    ISVehicleMenu.showRadialMenuOutside = function(player, ...)
        local menu = getPlayerRadialMenu(player:getPlayerNum())
        local wasVisible = menu:isReallyVisible()   -- vanilla toggles: it was closing
        original(player, ...)
        if wasVisible or player:getVehicle() then return end
        local vehicle = ISVehicleMenu.getVehicleToInteractWith(player)
        if not isRelevant(vehicle) or not FlipThisCar.isNear(player, vehicle) then return end
        menu:addSlice(getText("ContextMenu_FlipThisCar"), getTexture(ICON), startFlip, player, vehicle)
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
