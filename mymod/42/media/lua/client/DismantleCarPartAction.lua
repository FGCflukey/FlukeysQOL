DismantleCarPartAction = ISBaseTimedAction:derive("DismantleCarPartAction")

-- Toggle debug output here
local DEBUG = false

local function dbg(msg)
    if DEBUG then
        print("[DismantleCarPart][Client] " .. tostring(msg))
    end
end

local function isGlassPart(name)
    return
        string.find(name, "frontwindow") or
        string.find(name, "frontsidewindow") or
        string.find(name, "rearwindow") or
        string.find(name, "rearsidewindow") or
        string.find(name, "windshield") or
        string.find(name, "rearwindshield")
end

function DismantleCarPartAction:isValid()
    return self.part ~= nil
end

function DismantleCarPartAction:update()
    self.character:faceThisObject(self.character)
end

function DismantleCarPartAction:start()
    local name = string.lower(self.partName or "")
    local glass = isGlassPart(name)

    if glass then
        self:setActionAnim("Loot")
    else
        self:setActionAnim("BlowTorch")
        self.sound = self.character:playSound("BlowTorch")
    end
end

function DismantleCarPartAction:stop()
    if self.sound then
        self.character:stopOrTriggerSound(self.sound)
        self.sound = nil
    end
    ISBaseTimedAction.stop(self)
end

function DismantleCarPartAction:perform()
    dbg("perform()")

    if self.sound then
        self.character:stopOrTriggerSound(self.sound)
        self.sound = nil
    end

    local inv = self.character:getInventory()
    if not inv then
        dbg("ERROR: inventory nil, aborting")
        return ISBaseTimedAction.perform(self)
    end

    local name = string.lower(self.partName or "")
    local glass = isGlassPart(name)

    -- Client-side pre-check only, for responsiveness. The server re-validates
    -- everything independently before touching any inventory state.
    if glass then
        local scalpel = inv:getFirstTypeRecurse("Scalpel")
        if not scalpel then
            dbg("Missing scalpel for glass dismantle (client pre-check)")
            return ISBaseTimedAction.perform(self)
        end
    else
        local torch = inv:getFirstTypeRecurse("BlowTorch")
        local mask  = inv:getFirstTypeRecurse("WeldingMask")
        local uses  = (torch and torch.getCurrentUses) and torch:getCurrentUses() or 0

        if uses <= 0 or not mask then
            dbg("Missing blowtorch/uses/mask (client pre-check)")
            return ISBaseTimedAction.perform(self)
        end
    end

    if not self.part or not self.part.getID then
        dbg("ERROR: part missing or has no ID, aborting")
        return ISBaseTimedAction.perform(self)
    end

    dbg("Sending dismantle command to server for partID=" .. tostring(self.part:getID()))

    sendClientCommand(self.character, "CarPartDismantle", "dismantle", {
        partID   = self.part:getID(),
        partName = self.partName,
    })

    -- NOTE: no local inv:AddItem / inv:Remove / setCurrentUses here.
    -- The server is authoritative and will push the actual container
    -- changes back via sendRemoveItemFromContainer / sendAddItemToContainer
    -- / syncItemFields.

    dbg("perform() finished (server pending)")
    ISBaseTimedAction.perform(self)
end

function DismantleCarPartAction:new(character, part)
    dbg("Constructor: character=" .. tostring(character) .. " part=" .. tostring(part))

    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.part = part
    o.partName = part:getFullType() or part:getType() or ""

    o.maxTime = 120
    o.stopOnWalk = true
    o.stopOnRun = true
    o.forceProgressBar = true
    o.useProgressBar = true

    dbg("Constructor finished")
    return o
end