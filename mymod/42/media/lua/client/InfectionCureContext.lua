print("[ZomInfection] Context LOADED")

local function ZomInfectionCure_Context(playerIndex, context, items)
    local player = getSpecificPlayer(playerIndex)
    if not player then return end

    local foundItem = nil

    for _, v in ipairs(items) do
        local obj = v

        if v.items then
            obj = v.items[1]
        end

        if obj and obj.item then
            obj = obj.item
        end

        if instanceof(obj, "InventoryItem") then
            print("DEBUG REAL ITEM:", obj:getFullType())
            if obj:getFullType() == "Base.SyringeWithCure" then
                foundItem = obj
                break
            end
        end
    end

    if not foundItem then return end

    context:addOption(
        "Inject Cure",
        foundItem,
        function(_, item)
            if not item then
                print("[ZomInfection] ERROR: item is nil")
                return
            end
            ISTimedActionQueue.add(ZomInfectionCureAction:new(player, item))
        end,
        foundItem
    )
end

Events.OnFillInventoryObjectContextMenu.Add(ZomInfectionCure_Context)