-- media/lua/server/CarPartRepair/CarPartRepair_Server.lua
--
-- This file did not exist before. It's what closes the desync gap:
-- previously ISRepairCarPartAction:perform() called item:setCondition()
-- and consumed the kit/material directly on the client. In dedicated
-- MP that's a client telling itself the state changed — the server
-- (which is authoritative for all persistent item/vehicle state) was
-- never informed, and never asked to agree.
--
-- Now the client only *requests* a repair; this file is what actually
-- performs it, after checking everything again itself.

local DEBUG = true
local function dbg(msg) if DEBUG then print("[CarPartRepair:Server] " .. tostring(msg)) end end

local function OnClientCommand(module, command, player, args)
    if module ~= "CarPartRepair" then return end
    if command ~= "repairPart" then return end

    if not player or not args or not args.itemID or not args.partName then
        dbg("Malformed repairPart request, ignoring")
        return
    end

    local rule = CarPartRepair_Util.Rules[args.partName]
    if not rule then
        dbg("Unknown partName: " .. tostring(args.partName))
        sendServerCommand(player, "CarPartRepair", "repairResult", { success = false, reason = "Unknown part" })
        return
    end

    -- Re-derive the item from the player's OWN server-side inventory by ID.
    -- Never trust an item reference sent from the client.
    local inv = player:getInventory()
    local item = CarPartRepair_Util.findItemByID(inv, args.itemID)

    if not item then
        dbg("Item not found on server for id " .. tostring(args.itemID))
        sendServerCommand(player, "CarPartRepair", "repairResult", { success = false, reason = "Item not found" })
        return
    end

    -- Confirm the item actually still matches this rule (defends against a
    -- stale/forged partName being sent for a different item).
    local actualPartName = CarPartRepair_Util.identifyPart(item)
    if actualPartName ~= args.partName then
        dbg("partName mismatch: expected " .. tostring(args.partName) .. " got " .. tostring(actualPartName))
        sendServerCommand(player, "CarPartRepair", "repairResult", { success = false, reason = "Part mismatch" })
        return
    end

    -- Full re-validation server-side. This is the same check the client
    -- ran to decide whether to show the menu option, run again here because
    -- the client's answer can't be trusted (mods, edited clients, or just
    -- a stale state between the menu opening and the action completing).
    local ok, reason = CarPartRepair_Util.canRepairPart(player, item, rule)
    if not ok then
        dbg("Server rejected repair: " .. tostring(reason))
        sendServerCommand(player, "CarPartRepair", "repairResult", { success = false, reason = reason })
        return
    end

    -- Apply the mutation. This is the ONLY place condition should change now.
    local lvl = player:getPerkLevel(Perks.Mechanics)
    local maxRepair =
        (lvl <= 4) and rule.skillCaps[1] or
        (lvl <= 8) and rule.skillCaps[2] or
        rule.skillCaps[3]

    local oldCond = item:getCondition()
    -- One repair application takes the part straight to your skill-level
    -- cap, regardless of starting condition -- same single kit-use either
    -- way. (repairAmount in the rule table is no longer used for this
    -- calculation; kept in Util.lua for now in case you want it back for
    -- some other part group later.)
    local targetCond = maxRepair
    if targetCond < oldCond then targetCond = oldCond end -- never let a repair attempt lower condition
    item:setCondition(targetCond)

    -- Read it straight back from the same object we just set it on.
    -- If this doesn't match targetCond, setCondition isn't sticking at
    -- all (clamped, ignored, or this item type handles condition
    -- differently than a plain InventoryItem) -- a mutation problem,
    -- not a client-sync problem. If it DOES match here but the player
    -- still sees the old value on screen, that isolates it as purely
    -- a client display/sync issue instead.
    local verifyCond = item:getCondition()
    dbg("Repair mutation: old=" .. oldCond .. " target=" .. targetCond .. " verify=" .. verifyCond)
    if verifyCond ~= targetCond then
        dbg("!!! setCondition did not stick on the server object itself !!!")
    end

    -- Push the field change down to the owning client. This is the same
    -- syncItemFields() pattern your other server-authoritative mods already
    -- use successfully -- not a new guess, reusing what's proven to work.
    if item.syncItemFields then
        item:syncItemFields()
        dbg("syncItemFields() called")
    else
        dbg("!!! item:syncItemFields does not exist on this item type !!!")
    end

    -- Tire-specific: also restore air pressure, not just condition.
    if rule.alsoInflatesTire then
        if item.getAirPressureMax and item.setAirPressure then
            local maxAir = item:getAirPressureMax()
            item:setAirPressure(maxAir)
            dbg("Inflated tire to " .. tostring(maxAir))
            if item.syncItemFields then
                item:syncItemFields()
            end
        else
            dbg("!!! rule.alsoInflatesTire is true but item has no getAirPressureMax/setAirPressure !!!")
        end
    end

    -- Consume kit (re-fetched server-side, not the client's reference)
    local kit = inv:getFirstTypeRecurse(rule.required.kit)
    if kit and kit.getCurrentUses then
        kit:setCurrentUses(kit:getCurrentUses() - 1)
        if kit.syncItemFields then
            kit:syncItemFields()
        end
    end

    -- Drain the tool's uses if this rule opts into it (BlowTorch fuel,
    -- unlike the reusable Wrench which is never consumed). Same
    -- setCurrentUses()/syncItemFields() pattern as the kit above.
    if rule.toolConsumesUses then
        local tool = inv:getFirstTypeRecurse(rule.required.tool)
        if tool and tool.getCurrentUses and tool.setCurrentUses then
            local drainAmount = rule.toolUsesPerRepair or 1
            local newUses = math.max(0, tool:getCurrentUses() - drainAmount)
            tool:setCurrentUses(newUses)
            dbg("Tool drained: " .. rule.required.tool .. " -> uses=" .. newUses)
            if tool.syncItemFields then
                tool:syncItemFields()
            end
        else
            dbg("!!! rule.toolConsumesUses is true but " .. tostring(rule.required.tool) ..
                " has no getCurrentUses/setCurrentUses -- check its item script type !!!")
        end
    end

    -- Consume material (re-fetched server-side). This item is being
    -- REMOVED from the container entirely, not field-changed, so
    -- syncItemFields() doesn't apply here -- using your established
    -- sendRemoveItemFromContainer pattern instead, same as your other
    -- server-authoritative mods use for this exact situation.
    local material = inv:getFirstTypeRecurse(rule.required.material)
    if material then
        inv:Remove(material)
        if sendRemoveItemFromContainer then
            sendRemoveItemFromContainer(inv, material)
        else
            dbg("!!! sendRemoveItemFromContainer not available, material removal may lag until resync !!!")
        end
    end

    -- NOTE: I have NOT verified an explicit "push this one item back to the
    -- client now" call for B42 — I don't want to hand you a guessed function
    -- name as if it's confirmed. The engine does periodically sync a
    -- player's own inventory back to their client automatically, so this
    -- may just work with no extra call. Test it: if the hood's % doesn't
    -- visually update immediately after the action finishes, that's the
    -- signal you need an explicit push here, and at that point paste your
    -- console.txt and I'll help find the right call.

    sendServerCommand(player, "CarPartRepair", "repairResult", {
        success = true,
        itemID = args.itemID,
        newCondition = targetCond,
    })
end

Events.OnClientCommand.Add(OnClientCommand)