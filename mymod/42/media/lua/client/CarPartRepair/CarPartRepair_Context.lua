-- media/lua/client/CarPartRepair/CarPartRepair_Context.lua

-- require "CarPartRepair.CarPartRepair_Util"
-- require "CarPartRepair.CarPartRepair_Action"

local Util = CarPartRepair_Util
local Action = CarPartRepair_Action

local DEBUG = true
local function dbg(msg) if DEBUG then print("[CarPartRepair:Context] " .. tostring(msg)) end end

local function OnFillInventoryObjectContextMenu(playerIndex, context, items)
    local player = getSpecificPlayer(playerIndex)
    if not player then return end

    dbg("context triggered itemsCount=" .. #items)

    -- Identify the item clicked
    local item = nil
    for _, v in ipairs(items) do
        if v.items then
            item = v.items[1]
        else
            item = v
        end
        if item then break end
    end

    if not item then return end

    -- Identify part type
    local partName, rule = CarPartRepair_Util.identifyPart(item)
    if not partName then return end

    dbg("found part=" .. partName)

    -- Check repair eligibility
    local ok, reason = CarPartRepair_Util.canRepairPart(player, item, rule)
    dbg("canRepairPart ok=" .. tostring(ok) .. " reason=" .. tostring(reason))

    ---------------------------------------------------------
    -- OPTION A: Disabled repair option + tooltip
    ---------------------------------------------------------
    if not ok then
        -- Skill cap message
        if reason == "Part condition cannot be improved further" then
            player:Say("I can't repair this part any further.")
            return
        end

        -- Create disabled option
        local opt = context:addOption("Repair " .. partName .. " (Unavailable)", nil, nil)
        opt.notAvailable = true

        -- Tooltip
        local tip = ISToolTip:new()
        tip:initialise()
        tip:setVisible(true)

        tip.description = "Requirements:\n"

        -- Tool
        if not CarPartRepair_Util.containsFullType(player:getInventory(), rule.required.tool) then
            tip.description = tip.description .. " - " .. rule.required.tool .. " (Missing)\n"
        else
            tip.description = tip.description .. " - " .. rule.required.tool .. "\n"
        end

        -- Second tool (e.g. TirePump) -- optional, only some rules use it
        if rule.required.tool2 then
            if not CarPartRepair_Util.containsFullType(player:getInventory(), rule.required.tool2) then
                tip.description = tip.description .. " - " .. rule.required.tool2 .. " (Missing)\n"
            else
                tip.description = tip.description .. " - " .. rule.required.tool2 .. "\n"
            end
        end

        -- Material
        if not CarPartRepair_Util.containsFullType(player:getInventory(), rule.required.material) then
            tip.description = tip.description .. " - " .. rule.required.material .. " (Missing)\n"
        else
            tip.description = tip.description .. " - " .. rule.required.material .. "\n"
        end

        -- Kit
        if not CarPartRepair_Util.containsFullType(player:getInventory(), rule.required.kit) then
            tip.description = tip.description .. " - " .. rule.required.kit .. " (Missing)\n"
        else
            tip.description = tip.description .. " - " .. rule.required.kit .. "\n"
        end

        opt.toolTip = tip
        return
    end

    ---------------------------------------------------------
    -- If everything is OK, add the real repair option
    ---------------------------------------------------------
    context:addOption("Repair " .. partName, player, CarPartRepair_Action.startRepair, item, rule, partName)
end

Events.OnFillInventoryObjectContextMenu.Add(OnFillInventoryObjectContextMenu)