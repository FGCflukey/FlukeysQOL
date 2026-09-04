-- Corpse Cleanup - Client Timed Action (MP Safe)

CorpseCleanupDebug = true

local function CCDebug(msg)
    if CorpseCleanupDebug then
        print("[CorpseCleanup CLIENT] " .. tostring(msg))
    end
end

CCDebug("CorpseCleanup_Action.lua loaded")

CorpseCleanupAction = ISBaseTimedAction:derive("CorpseCleanupAction")

function CorpseCleanupAction:isValid()
    CCDebug("isValid() called")
    return self.corpse ~= nil
end

function CorpseCleanupAction:update()
    self.character:faceThisObject(self.corpse)
end

function CorpseCleanupAction:start()
    CCDebug("Timed action started")
    self:setActionAnim("Dig")
    self.character:reportEvent("EventDig")
    self.sound = self.character:getEmitter():playSound("DissectCorpseKnives")
end

function CorpseCleanupAction:stop()
    CCDebug("Timed action stopped")
    if self.sound then
        self.character:getEmitter():stopSound(self.sound)
    end
    ISBaseTimedAction.stop(self)
end

function CorpseCleanupAction:perform()
    CCDebug("Timed action perform() reached")

    if self.sound then
        self.character:getEmitter():stopSound(self.sound)
    end

    CCDebug("Sending server command (coords + username)")

    sendClientCommand(self.character, "CorpseCleanup", "Butcher", {
        x = self.corpse:getX(),
        y = self.corpse:getY(),
        z = self.corpse:getZ(),

        playerID = self.character:getUsername(),

        originalPrimary = self.originalPrimary and self.originalPrimary:getID() or nil,
        originalSecondary = self.originalSecondary and self.originalSecondary:getID() or nil,
    })

    CCDebug("Server command sent")

    ISBaseTimedAction.perform(self)
end

function CorpseCleanupAction:new(character, corpse, tool, time, originalPrimary, originalSecondary)
    CCDebug("Creating new timed action")
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.corpse = corpse
    o.tool = tool
    o.maxTime = time or 200
    o.originalPrimary = originalPrimary
    o.originalSecondary = originalSecondary
    return o
end

-------------------------------------------------
-- RE-EQUIP HANDLER (server tells us to restore hands)
-------------------------------------------------
-- Client-driven equip changes sync properly both ways; the same change
-- made directly by the server does not visually update the owning
-- client until it forces its own resync. See CorpseCleanup_Server.lua.
Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "CorpseCleanup" or command ~= "ReEquip" then return end

    local player = getPlayer()
    if not player then return end

    CCDebug("Received ReEquip command, restoring hand items")

    if args.originalPrimary then
        local prim = player:getInventory():getItemById(args.originalPrimary)
        if prim then
            player:setPrimaryHandItem(prim)
            CCDebug("Re-equipped primary")
        end
    end

    if args.originalSecondary then
        local sec = player:getInventory():getItemById(args.originalSecondary)
        if sec then
            player:setSecondaryHandItem(sec)
            CCDebug("Re-equipped secondary")
        end
    end
end)