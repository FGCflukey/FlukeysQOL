local function ZomInfection_DoCure(player)
    -- Single-player fallback (playerObj is nil in SP)
    if not player then
        player = getPlayer()
    end

    local body = player:getBodyDamage()

    ---------------------------------------------------------
    -- 1. ZOMBIE INFECTION (the lethal one)
    ---------------------------------------------------------
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
        ZomInfection_DoCure(playerObj)
    end
end)