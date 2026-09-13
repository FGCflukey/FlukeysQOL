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

-- Shared with perform() below so the tool we auto-equipped in start()
-- always gets swapped back out, whether the repair finishes or gets
-- interrupted (stopOnWalk/stopOnRun/stopOnAim are all true here, so
-- interruption is easy) -- otherwise the tool stays stuck equipped.
local function restorePrimary(self)
    if self.tool then
        self.character:setPrimaryHandItem(self.originalPrimary)
    end
end

function ISRepairCarPartAction:stop()
    local emitter = self.character:getEmitter()
    if emitter and self.sound then
        emitter:stopSound(self.sound)
    end

    restorePrimary(self)
    ISBaseTimedAction.stop(self)
end

function ISRepairCarPartAction:perform()
    dbg("perform()")

    local emitter = self.character:getEmitter()
    if emitter and self.sound then
        emitter:stopSound(self.sound)
    end

    restorePrimary(self)

    -- IMPORTANT: we no longer mutate condition / consume the kit or
    -- material locally. All of that now happens server-side in
    -- CarPartRepair_Server.lua, which re-validates everything itself
    -- (never trusts the client) and is the source of truth.
    --
    -- We DO send an optimistic local hint so the UI feels responsive,
    -- but the server's follow-up command is what actually sticks.
    --
    -- If the part isn't in the character's own inventory (e.g. it's
    -- sitting in a nearby crate's loot panel), also send the square
    -- its container sits on -- the server's own inventory search
    -- can't reach a separate world container at all, so without this
    -- hint it always reports "Item not found" for anything not
    -- carried on the player. Just a hint: the server re-validates
    -- distance before trusting it.
    local containerX, containerY, containerZ = nil, nil, nil
    local container = self.item:getContainer()
    if container and not container:isInCharacterInventory(self.character) then
        local parent = container:getParent()
        if parent and parent.getSquare then
            local sq = parent:getSquare()
            if sq then
                containerX, containerY, containerZ = sq:getX(), sq:getY(), sq:getZ()
            end
        end
    end

    sendClientCommand(self.character, "CarPartRepair", "repairPart", {
        itemID     = self.item:getID(),
        partName   = self.partName,
        containerX = containerX,
        containerY = containerY,
        containerZ = containerZ,
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

            -- The server already has the real, correct data (proven by
            -- it surviving a reconnect) -- but if the part was in a
            -- nearby world container (crate, etc.) rather than our own
            -- inventory, its already-open loot panel was never told to
            -- redraw and keeps showing the stale condition. Re-derive
            -- the same item/container (same lookup the server used) and
            -- mark it dirty -- setDrawDirty(true) is the same client-side
            -- redraw hint vanilla's own ISReadABook.lua uses.
            if args.containerX then
                local item = CarPartRepair_Util.findItemNearby(player, args.itemID, args.containerX, args.containerY, args.containerZ)
                if item and item:getContainer() then
                    item:getContainer():setDrawDirty(true)
                end
            end
        else
            player:Say("Couldn't finish the repair.")
            dbg("Server rejected repair: " .. tostring(args.reason))
        end
    end
end
Events.OnServerCommand.Add(OnServerCommand)