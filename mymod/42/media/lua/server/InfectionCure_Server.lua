local function ZomInfection_DoCure(player, itemID)
    -- Single-player fallback (playerObj is nil in SP)
    if not player then
        player = getPlayer()
    end

    if not player then
        print("[ZomInfection] SERVER REJECT: no player object to cure")
        return
    end

    local inventory = player:getInventory()
    local item = nil

    if itemID then
        item = inventory:getItemById(itemID)
    end

    -- Fallback if the ID lookup fails for some reason (e.g. SP timing)
    if not item then
        item = inventory:FindAndReturn("Base.SyringeWithCure")
    end

    if not item then
        print("[ZomInfection] SERVER REJECT: no SyringeWithCure found in inventory for " .. tostring(player:getUsername()))
        return
    end

    if item:getFullType() ~= "Base.SyringeWithCure" then
        print("[ZomInfection] SERVER REJECT: item " .. tostring(itemID) .. " is not a SyringeWithCure (got " .. tostring(item:getFullType()) .. ") for " .. tostring(player:getUsername()))
        return
    end

    local container = item:getContainer()
    if not container then
        container = inventory
    end

    ---------------------------------------------------------
    -- 0. Authoritatively consume the syringe, give back an empty one
    ---------------------------------------------------------
    container:Remove(item)
    local newItem = container:AddItem("Base.EmptySyringe")

    if isServer() then
        sendRemoveItemFromContainer(container, item)
        sendAddItemToContainer(container, newItem)
    end

    ---------------------------------------------------------
    -- 1. ZOMBIE INFECTION (the lethal one)
    ---------------------------------------------------------
    local body = player:getBodyDamage()

    body:setInfected(false)
    body:setInfectionTime(-1)

    -- Build 42 infection fields
    if body.setInfectionGrowth then
        body:setInfectionGrowth(0)
    end

    if body.setInfectionStage then
        body:setInfectionStage(0)
    end

    ---------------------------------------------------------
    -- 2. WOUND INFECTIONS (the ones shown in the UI)
    ---------------------------------------------------------
    local parts = body:getBodyParts()
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)

        -- Zombie infection on body part
        part:SetInfected(false)

        -- Build 42 wound infection fields
        if part.setWoundInfectionLevel then
            part:setWoundInfectionLevel(0)
        end

        if part.setBiteInfectionLevel then
            part:setBiteInfectionLevel(0)
        end

        if part.setCutInfectionLevel then
            part:setCutInfectionLevel(0)
        end

        if part.setScratchInfectionLevel then
            part:setScratchInfectionLevel(0)
        end

        if part.setStitchInfectionLevel then
            part:setStitchInfectionLevel(0)
        end

        if part.setDeepWoundInfectionLevel then
            part:setDeepWoundInfectionLevel(0)
        end

        -- Optional: clear dirtiness (helps prevent reinfection)
        if part.setDirt then
            part:setDirt(0)
        end
    end

    ---------------------------------------------------------
    -- 3. Log confirmation
    ---------------------------------------------------------
    print("[ZomInfection] Cure applied to " .. player:getUsername())
end


-------------------------------------------------------------
-- CLIENT COMMAND HANDLER
-------------------------------------------------------------
Events.OnClientCommand.Add(function(module, command, playerObj, args)
    if module == "ZomInfection" and command == "Cure" then
        ZomInfection_DoCure(playerObj, args and args.itemID)
    end
end)