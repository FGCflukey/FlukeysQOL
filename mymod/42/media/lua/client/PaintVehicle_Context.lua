-- PaintVehicle_Context.lua
-- Right-click "Repaint Vehicle" menu: one option per spraycan color the player carries.

require "PaintVehicle_Shared"
require "PaintVehicle_Action"

local DEBUG = false
local function dbg(msg) if DEBUG then print("[PaintVehicle:Context] " .. tostring(msg)) end end

-----------------------------------------------------
-- PROXIMITY CHECK
-----------------------------------------------------
-- getVehicleToInteractWith() can return a vehicle even when the player isn't actually
-- near it (e.g. last-targeted vehicle). Gate on real distance before doing anything else.
local PV_INTERACT_RANGE = 3 -- tiles

local function isPlayerNearVehicle(playerObj, vehicle)
    local dx = playerObj:getX() - vehicle:getX()
    local dy = playerObj:getY() - vehicle:getY()
    return (dx * dx + dy * dy) <= (PV_INTERACT_RANGE * PV_INTERACT_RANGE)
end

-----------------------------------------------------
-- QUEUE THE PAINT JOB
-----------------------------------------------------
-- Items in a backpack/bag are moved to the main inventory first (the vanilla pattern),
-- otherwise the action's top-level checks would fail and it would cancel silently.
local function onChooseColor(_, playerObj, vehicle, spraycan)
    local inv = playerObj:getInventory()
    local sanding = inv:getFirstTypeRecurse(PaintVehicle.SANDING_BLOCK)
    if sanding then ISInventoryPaneContextMenu.transferIfNeeded(playerObj, sanding) end
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, spraycan)

    ISTimedActionQueue.add(ISPaintVehicleAction:new(playerObj, vehicle, spraycan))
end

local function OnFillWorldObjectContextMenu_PaintVehicle(playerNum, context, worldobjects, test)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return end

    local vehicle = ISVehicleMenu.getVehicleToInteractWith(playerObj)
    if not vehicle then return end
    if not isPlayerNearVehicle(playerObj, vehicle) then return end

    -----------------------------------------------------
    -- ELIGIBILITY GATING (silent) -- vehicles that simply can't be repainted
    -- at all shouldn't show this option, whatever the weather/key/materials.
    -----------------------------------------------------
    local blocked, scriptName = PaintVehicle.isBlockedCommercial(vehicle)
    if blocked then
        dbg("blocked repaint for commercial vehicle: " .. tostring(scriptName))
        return
    end

    -- Vehicle submenu detection
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

    -- Fallback HSV repaint
    local allowRepaint = hasVehicleSubmenu
    if not allowRepaint and type(vehicle.setColorHSV) == "function" then
        local mask = vehicle.getTextureMask and vehicle:getTextureMask()
        if mask == nil or mask == "" then
            allowRepaint = true
        end
    end
    if not allowRepaint then return end

    if test then return true end

    -----------------------------------------------------
    -- Evaluate every requirement up front so the option can always be shown,
    -- greyed out with a tooltip explaining what's missing.
    -- Items count wherever they are, including bags (moved out when chosen).
    -----------------------------------------------------
    local inv = playerObj:getInventory()

    local cans = {}   -- color name -> first spraycan of that color
    local hasAnyCan = false
    for _, name in ipairs(PaintVehicle.NAMES) do
        local can = inv:getFirstTypeRecurse(PaintVehicle.COLORS[name].item)
        if can then
            cans[name] = can
            hasAnyCan = true
        end
    end

    local hasKey     = PaintVehicle.hasVehicleKey(playerObj, vehicle)
    local weatherOk  = not PaintVehicle.isBadWeather()
    local lightOk    = PaintVehicle.hasEnoughLight(playerObj)
    local cleanOk    = not PaintVehicle.isBloody(vehicle)
    local hasSanding = inv:containsTypeRecurse(PaintVehicle.SANDING_BLOCK)

    local allOk = hasKey and weatherOk and lightOk and cleanOk and hasSanding and hasAnyCan

    local mainOption = context:addOption("Repaint Vehicle", worldobjects, nil)

    if not allOk then
        mainOption.notAvailable = true

        local function reqLine(ok, text)
            local rgb = ok and " <RGB:1,1,1>" or " <RGB:1,0,0>"
            return rgb .. text .. " <LINE>"
        end

        local tip = ISToolTip:new()
        tip:initialise()
        tip:setVisible(true)

        tip.description = "Requirements:" .. " <LINE>"
        if vehicle:getKeyId() and vehicle:getKeyId() ~= -1 then
            tip.description = tip.description .. reqLine(hasKey, "Vehicle key")
        end
        tip.description = tip.description .. reqLine(weatherOk, "Clear weather")
        tip.description = tip.description .. reqLine(lightOk, "Enough light")
        tip.description = tip.description .. reqLine(cleanOk, "Vehicle is clean")
        tip.description = tip.description .. reqLine(hasSanding, "Sanding Block")
        tip.description = tip.description .. reqLine(hasAnyCan, "Spray Paint (any color)")

        mainOption.toolTip = tip
        return
    end

    local repaintMenu = ISContextMenu:getNew(context)
    context:addSubMenu(mainOption, repaintMenu)

    -- Alphabetical, one entry per color the player actually has
    for _, name in ipairs(PaintVehicle.NAMES) do
        if cans[name] then
            repaintMenu:addOption(name, nil, onChooseColor, playerObj, vehicle, cans[name])
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu_PaintVehicle)
