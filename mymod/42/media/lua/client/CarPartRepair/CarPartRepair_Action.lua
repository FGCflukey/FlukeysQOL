-- media/lua/client/CarPartRepair/CarPartRepair_Action.lua

CarPartRepair_Action = {}

local DEBUG = false
local function dbg(msg) if DEBUG then print("[CarPartRepair:Action] " .. tostring(msg)) end end

ISRepairCarPartAction = ISBaseTimedAction:derive("ISRepairCarPartAction")

function ISRepairCarPartAction:isValid()
    return self.item ~= nil
end

function ISRepairCarPartAction:update()
    local emitter = self.character:getEmitter()
    if emitter and self.sound and not emitter:isPlaying(self.sound) then
        self.sound = emitter:playSound("Sewing")
    end
end

function ISRepairCarPartAction:start()
    dbg("start()")

    self.originalPrimary = self.character:getPrimaryHandItem()

    if self.tool then
        self.character:setPrimaryHandItem(self.tool)
    end

    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")

    local emitter = self.character:getEmitter()
    if emitter then
        self.sound = emitter:playSound("Sewing")
    end
end

function ISRepairCarPartAction:stop()
    local emitter = self.character:getEmitter()
    if emitter and self.sound then
        emitter:stopSound(self.sound)
    end

    ISBaseTimedAction.stop(self)
end

function ISRepairCarPartAction:perform()
    dbg("perform()")

    local emitter = self.character:getEmitter()
    if emitter and self.sound then
        emitter:stopSound(self.sound)
    end

    self.character:setPrimaryHandItem(self.originalPrimary)

    -- IMPORTANT: we no longer mutate condition / consume the kit or
    -- material locally. All of that now happens server-side in
    -- CarPartRepair_Server.lua, which re-validates everything itself
    -- (never trusts the client) and is the source of truth.
    --
    -- We DO send an optimistic local hint so the UI feels responsive,
    -- but the server's follow-up command is what actually sticks.
    sendClientCommand(self.character, "CarPartRepair", "repairPart", {
        itemID    = self.item:getID(),
        partName  = self.partName,
    })

    ISBaseTimedAction.perform(self)
end

function CarPartRepair_Action.startRepair(player, item, rule, partName)
    dbg("startRepair: " .. item:getFullType())

    local inv = player:getInventory()

    local tool     = inv:getFirstTypeRecurse(rule.required.tool)
    local material = inv:getFirstTypeRecurse(rule.required.material)
    local kit      = inv:getFirstTypeRecurse(rule.required.kit)

    local action = ISRepairCarPartAction:new(player, item, tool, material, kit, rule, partName)
    ISTimedActionQueue.add(action)
end

function ISRepairCarPartAction:new(character, item, tool, material, kit, rule, partName)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.item      = item
    o.tool      = tool
    o.material  = material
    o.kit       = kit
    o.rule      = rule
    o.partName  = partName

    local lvl = character:getPerkLevel(Perks.Mechanics)
    o.maxTime = 1200 - (lvl * 100)

    o.stopOnWalk = true
    o.stopOnRun  = true
    o.stopOnAim  = true
    o.forceProgressBar = true

    return o
end

---------------------------------------------------------
-- Server's authoritative result comes back here. The server
-- has already applied the real state change; this just lets us
-- give the player feedback and correct the UI if anything about
-- our optimistic guess was wrong (e.g. someone else used the last
-- kit charge in the meantime).
---------------------------------------------------------
local function OnServerCommand(module, command, args)
    if module ~= "CarPartRepair" then return end

    if command == "repairResult" then
        local player = getSpecificPlayer(0)
        if not player then return end

        if args.success then
            player:Say("That should hold.")
        else
            player:Say("Couldn't finish the repair.")
            dbg("Server rejected repair: " .. tostring(args.reason))
        end
    end
end
Events.OnServerCommand.Add(OnServerCommand)