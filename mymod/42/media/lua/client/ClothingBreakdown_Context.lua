-- ClothingBreakdown_Context.lua
require "ClothingBreakdown_Definitions"
require "ClothingBreakdown_Material"

print("DEBUG: ClothingBreakdown_Context.lua LOADED")

-------------------------------------------------
-- SIMPLE, SAFE TOOL DETECTION
-------------------------------------------------
local function playerHasCuttingTool(player)
    local function scanContainer(container)
        if not container then return false end
        local items = container:getItems()
        if not items then return false end

        for i = 0, items:size() - 1 do
            local item = items:get(i)

            if instanceof(item, "InventoryItem") then
                local t = item:getType() or ""

                if t == "Scissors" then return true end
                if string.find(t, "Knife", 1, true) then return true end
                if t == "MeatCleaver" or t == "Machete" then return true end

                local sub = item.getInventory and item:getInventory() or nil
                if sub and scanContainer(sub) then return true end
            end
        end

        return false
    end

    return scanContainer(player:getInventory())
end

-------------------------------------------------
-- RECURSIVE INVENTORY SCAN
-------------------------------------------------
local function collectMatchingItems(container, fullType, player, out)
    if not container then return end
    local items = container:getItems()
    if not items then return end

    for i = 0, items:size() - 1 do
        local it = items:get(i)

        if instanceof(it, "InventoryItem") then
            -- Match by fullType
            if it:getFullType() == fullType then
                -- Exclude equipped items
                if not player:isEquipped(it) then
                    table.insert(out, it)
                end
            end

            -- Recurse into bags
            local sub = it.getInventory and it:getInventory() or nil
            if sub then
                collectMatchingItems(sub, fullType, player, out)
            end
        end
    end
end

-------------------------------------------------
-- CONTEXT MENU
-------------------------------------------------
function OnFillInventoryObjectContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then return end

    for _, entry in ipairs(items) do
        local item = entry

        -- Vanilla stack wrapper
        if not instanceof(item, "InventoryItem") and entry.items then
            item = entry.items[1]
        end

        if item and instanceof(item, "InventoryItem") then
            local fullType = item:getFullType()

            local rawBodyLoc = item.getBodyLocation and item:getBodyLocation() or nil
            local bodyLoc = rawBodyLoc and tostring(rawBodyLoc):lower() or nil

            local def = ClothingBreakdown[fullType]
                or ClothingBreakdown[bodyLoc]

            if def then
                if not playerHasCuttingTool(player) then
                    -- No tool, skip
                else
                    if not player:isEquipped(item) then

                        -------------------------------------------------
                        -- BUILD TRUE MATCH LIST (recursive, safe)
                        -------------------------------------------------
                        local matches = {}
                        collectMatchingItems(player:getInventory(), fullType, player, matches)

                        if #matches > 1 then
                            -- Submenu
                            local parent = context:addOption("Recycle Clothing")
                            local subMenu = context:getNew(context)
                            context:addSubMenu(parent, subMenu)

                            -- Recycle 1
                            subMenu:addOption(
                                "Recycle 1",
                                matches[1],
                                function()
                                    ISTimedActionQueue.add(ClothingBreakdownAction:new(player, matches[1], 80))
                                end
                            )

                            -- Recycle All
                            subMenu:addOption(
                                "Recycle All (" .. #matches .. ")",
                                matches,
                                function()
                                    for _, it in ipairs(matches) do
                                        ISTimedActionQueue.add(ClothingBreakdownAction:new(player, it, 80))
                                    end
                                end
                            )

                        else
                            -- Single item
                            context:addOption(
                                "Recycle Clothing",
                                item,
                                function()
                                    ISTimedActionQueue.add(ClothingBreakdownAction:new(player, item, 80))
                                end
                            )
                        end
                        -------------------------------------------------

                    end
                end
            end
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(OnFillInventoryObjectContextMenu)