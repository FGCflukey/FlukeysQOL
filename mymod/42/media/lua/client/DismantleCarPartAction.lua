DismantleCarPartAction = ISBaseTimedAction:derive("DismantleCarPartAction")

-- Toggle debug output here
local DEBUG = false

local function dbg(msg)
    if DEBUG then
        print("[DismantleCarPart] " .. tostring(msg))
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

    local inv = self.character:getInventory()
    if not inv then
        dbg("ERROR: inventory nil")
        return ISBaseTimedAction.perform(self)
    end

    local name = string.lower(self.partName or "")
    local glass = isGlassPart(name)

    local torch = inv:getFirstTypeRecurse("BlowTorch")
    local mask  = inv:getFirstTypeRecurse("WeldingMask")
    local scalpel = inv:getFirstTypeRecurse("Scalpel")

    dbg("torch=" .. tostring(torch))
    dbg("mask=" .. tostring(mask))
    dbg("scalpel=" .. tostring(scalpel))
    dbg("glass=" .. tostring(glass))

    if glass then
        if not scalpel then
            dbg("Missing scalpel for glass dismantle")
            return ISBaseTimedAction.perform(self)
        end
    else
        local uses = 0
        if torch and torch.getCurrentUses then
            uses = torch:getCurrentUses()
        end

        dbg("torch current uses=" .. tostring(uses))

        if uses <= 0 or not mask then
            dbg("Missing blowtorch or mask")
            return ISBaseTimedAction.perform(self)
        end

        dbg("Consuming blowtorch fuel")
        if torch.setCurrentUses then
            torch:setCurrentUses(math.max(uses - 1, 0))
        end
    end

    if self.sound then
        self.character:stopOrTriggerSound(self.sound)
        self.sound = nil
    end

    if string.find(name, "trunkdoor") or string.find(name, "enginedoor") then
        inv:AddItem("Base.SheetMetal")
        inv:AddItem("Base.SheetMetal")

    elseif string.find(name, "frontdoor") or string.find(name, "reardoor") then
        inv:AddItem("Base.SheetMetal")

        local wires = ZombRand(1, 4)
        local bolts = ZombRand(1, 5)
        local screws = ZombRand(1, 5)

        for i = 1, wires do inv:AddItem("Base.ElectricWire") end
        for i = 1, bolts do inv:AddItem("Base.NutsBolts") end
        for i = 1, screws do inv:AddItem("Base.Screws") end

    elseif string.find(name, "bumper") then
        local bars = ZombRand(1, 3)
        local bolts = ZombRand(1, 5)

        for i = 1, bars do inv:AddItem("Base.SteelBar") end
        for i = 1, bolts do inv:AddItem("Base.NutsBolts") end

    elseif
        string.find(name, "frontwindow") or
        string.find(name, "frontsidewindow") or
        string.find(name, "rearwindow") or
        string.find(name, "rearsidewindow")
    then
        inv:AddItem("Base.GlassPanel")

    elseif
        string.find(name, "windshield") or
        string.find(name, "rearwindshield")
    then
        inv:AddItem("Base.GlassPanel")
        inv:AddItem("Base.GlassPanel")

    else
        inv:AddItem("Base.SheetMetal")
    end

    dbg("Removing part from inventory")
    inv:Remove(self.part)

    dbg("perform() finished")
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