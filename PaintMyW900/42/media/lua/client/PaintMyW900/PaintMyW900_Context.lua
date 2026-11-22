require "PaintMyW900/PaintMyW900_Defs"
require "TimedActions/PaintMyW900_Action"

-- Right-click a W900 truck/trailer -> "Paint My W900" -> pick a colour.
-- Each colour's tooltip shows the paint it needs and how much you have.

local dbg = PaintMyW900.dbg

local function line(ok, text)
    return (ok and " <RGB:1,1,1> " or " <RGB:1,0,0> ") .. text .. " <LINE> "
end

local function fmtCans(uses)
    local cans = uses / PaintMyW900.USES_PER_CAN
    if cans == math.floor(cans) then
        return cans .. (cans == 1 and " can" or " cans")
    end
    return string.format("%.1f cans", cans)
end

local function newTip(text)
    local tip = ISToolTip:new()
    tip:initialise()
    tip:setVisible(false)
    tip.description = text
    return tip
end

local function onPaint(_, playerObj, vehicle, skinIndex)
    ISTimedActionQueue.add(PaintMyW900Action:new(playerObj, vehicle, skinIndex))
end

local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or playerObj:getVehicle() then return end

    local vehicle = ISVehicleMenu.getVehicleToInteractWith(playerObj)
    if not vehicle or not PaintMyW900.isNear(playerObj, vehicle) then return end
    local def, scriptName = PaintMyW900.getVehicleDef(vehicle)
    if not def then return end
    if math.abs(vehicle:getCurrentSpeedKmHour()) > 0.8 then return end
    if test then return ISWorldObjectContextMenu.setTest() end

    dbg("menu for " .. tostring(scriptName) .. " skin=" .. tostring(vehicle:getSkinIndex()))

    local main = context:addOption("Paint My W900", worldobjects, nil)

    -- General requirements first: if any fail, grey out the whole option.
    local hasKey   = PaintMyW900.hasVehicleKey(playerObj, vehicle)
    local weather  = not PaintMyW900.isBadWeather()
    local light    = PaintMyW900.hasEnoughLight(playerObj)
    local clean    = not PaintMyW900.isBloody(vehicle)
    local brush    = PaintMyW900.hasBrush(playerObj)
    if not (hasKey and weather and light and clean and brush) then
        main.notAvailable = true
        local d = "Requirements: <LINE> "
        if vehicle:getKeyId() and vehicle:getKeyId() ~= -1 then d = d .. line(hasKey, "Vehicle key") end
        d = d .. line(weather, "Clear weather")
        d = d .. line(light, "Enough light")
        d = d .. line(clean, "Vehicle is clean (no blood)")
        d = d .. line(brush, "Paint Brush")
        main.toolTip = newTip(d)
        return
    end

    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(main, sub)

    local current = vehicle:getSkinIndex()
    local skinCount = vehicle:getSkinCount()
    for _, s in ipairs(def.skins) do
        local idx, key = s[1], s[2]
        if idx < skinCount then
            local color = PaintMyW900.COLORS[key]
            if idx == current then
                local opt = sub:addOption(color.label .. " (current)", nil, nil)
                opt.notAvailable = true
            else
                local cost = PaintMyW900.getCost(vehicle, key)
                local enough = true
                local d = "Paint needed: <LINE> "
                for _, c in ipairs(cost) do
                    local have = PaintMyW900.countUses(playerObj, c.paint)
                    local ok = have >= c.uses
                    enough = enough and ok
                    d = d .. line(ok, PaintMyW900.PAINT[c.paint].name .. " paint: " ..
                        fmtCans(c.uses) .. " (have " .. fmtCans(have) .. ")")
                end
                d = d .. " <LINE> <RGB:0.8,0.8,0.8> Also removes rust."
                local opt = sub:addOption(color.label, nil, onPaint, playerObj, vehicle, idx)
                opt.toolTip = newTip(d)
                if not enough then opt.notAvailable = true end
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
