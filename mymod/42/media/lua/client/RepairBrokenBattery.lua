-- RepairBrokenBattery.lua
-- Lets a fully dead (condition 0) car battery be repaired from the inventory.
--
-- Vanilla's inventory menu only offers "Repair" when the item is NOT broken
-- (ISInventoryPaneContextMenu: `not testItem:isBroken()`), so the "Fix Battery"
-- fixing in Vehicle_Parts_Fixings.txt (Battery Repair Kit / Electronics Scrap)
-- could never be used on a battery once it hit 0. The repair itself has no such
-- limit: FixingManager.fixItem (checked in projectzomboid.jar) repairs from 0,
-- and ISFixAction runs it server-side, so we only need to offer the option.
-- We reuse vanilla's own fixing menu builder, so tooltips, success chance,
-- item transfer and the timed action are exactly the normal repair path.

require "ISUI/ISInventoryPaneContextMenu"

local DEBUG = false
local function dbg(msg) if DEBUG then print("[RepairBrokenBattery] " .. tostring(msg)) end end

-- Must match the Require list of "fixing Fix Battery" in Vehicle_Parts_Fixings.txt
local BATTERY_TYPES = {
    ["Base.CarBattery1"] = true,
    ["Base.CarBattery2"] = true,
    ["Base.CarBattery3"] = true,
    ["Base.CarBattery8"] = true,
}

-- Inventory menu entries are either items or stacks ({ items = { ... } })
local function firstDeadBattery(items)
    for _, entry in ipairs(items) do
        local item = entry
        if not instanceof(item, "InventoryItem") then
            item = entry.items and entry.items[1]
        end
        if item and BATTERY_TYPES[item:getFullType()] and item:isBroken() then
            return item
        end
    end
    return nil
end

local function addRepairOption(playerNum, context, items)
    local battery = firstDeadBattery(items)
    if not battery then return end

    local fixingList = FixingManager.getFixes(battery)
    if fixingList:isEmpty() then
        dbg("dead battery " .. battery:getFullType() .. " has no fixings")
        return
    end

    local label = getText("ContextMenu_Repair") .. " " .. getItemNameFromFullType(battery:getFullType())
    local fixOption = context:addOption(label, items, nil)
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(fixOption, subMenu)
    for i = 0, fixingList:size() - 1 do
        ISInventoryPaneContextMenu.buildFixingMenu(battery, playerNum, fixingList:get(i), i, fixOption, subMenu)
    end
    dbg("offered repair for dead battery id=" .. tostring(battery:getID()))
end

Events.OnFillInventoryObjectContextMenu.Add(addRepairOption)
