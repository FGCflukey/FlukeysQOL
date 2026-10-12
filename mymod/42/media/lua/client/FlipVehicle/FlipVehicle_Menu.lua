-- FlipVehicle_Menu.lua
-- Adds a "Flip Vehicle" option to the vehicle radial menu (both the in-
-- vehicle steering-wheel menu and the outside-vehicle interaction menu) when
-- the target vehicle is stopped and tipped over. Informed by reading the
-- Workshop mod "FlipVehicle" (SportXAI, id 3764476627) -- its menu-injection
-- logic and flip detection formula are reused here, but its actual flip
-- (v:setAngles(...) every tick via Events.OnTick, purely client-side, zero
-- server sync) was a real bug: the flip would only ever be visible to the
-- player who triggered it, reverting for everyone else on their next
-- resync. Real fix is server-authoritative (see FlipVehicle_Server.lua) --
-- this file only ever requests.

local FLIP_ICON = getTexture("media/ui/vehicles/flipvehicle.png")
local FLIP_ICON_SIZE = 64

local function isVehicleFlipped(vehicle)
    if not vehicle or not vehicle:isStopped() then return false end
    local script = vehicle:getScript()
    if not script then return false end
    local shape = script:getPhysicsChassisShape()
    if not shape then return false end
    local shapeY = shape:y()
    local vectorDot = vehicle:getUpVectorDot()
    return vectorDot + (vectorDot - shapeY) <= 0
end

local function requestFlip(playerObj, vehicle)
    -- Same real, already-proven vanilla trailer-detach command the source
    -- mod uses, unchanged -- a flipped vehicle still towing/being towed
    -- needs to be detached first.
    if vehicle:getVehicleTowing() then
        sendClientCommand(playerObj, 'vehicle', 'detachTrailer', { vehicle = vehicle:getId() })
    end
    if vehicle:getVehicleTowedBy() then
        sendClientCommand(playerObj, 'vehicle', 'detachTrailer', { vehicle = vehicle:getVehicleTowedBy():getId() })
    end
    sendClientCommand(playerObj, 'FlipVehicle', 'Flip', { vehicleID = vehicle:getId() })
end

local function addFlipSlice(menu, playerObj, vehicle)
    if not isVehicleFlipped(vehicle) then return end
    FLIP_ICON:setWidth(FLIP_ICON_SIZE)
    FLIP_ICON:setHeight(FLIP_ICON_SIZE)
    menu:addSlice(getText("ContextMenu_FlipVehicle"), FLIP_ICON, requestFlip, playerObj, vehicle)
end

---------------------------------------------------------
-- In-vehicle (steering wheel) radial menu
---------------------------------------------------------
local realShowRadialMenu = ISVehicleMenu.showRadialMenu

function ISVehicleMenu.showRadialMenu(...)
    realShowRadialMenu(...)

    local playerObj = getSpecificPlayer(0)
    local vehicle = playerObj:getVehicle()
    if not vehicle then return end
    if not vehicle:isDriver(playerObj) then return end

    local menu = getPlayerRadialMenu(playerObj:getPlayerNum())
    addFlipSlice(menu, playerObj, vehicle)
end

---------------------------------------------------------
-- Outside-vehicle interaction radial menu
---------------------------------------------------------
local realShowRadialMenuOutside = ISVehicleMenu.showRadialMenuOutside

function ISVehicleMenu.showRadialMenuOutside(...)
    realShowRadialMenuOutside(...)

    local playerObj = getSpecificPlayer(0)
    if playerObj:getVehicle() then return end -- inside a vehicle, handled above

    local vehicle = ISVehicleMenu.getVehicleToInteractWith(playerObj)
    if not vehicle then return end

    local menu = getPlayerRadialMenu(playerObj:getPlayerNum())
    addFlipSlice(menu, playerObj, vehicle)
end
