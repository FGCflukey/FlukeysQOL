-- RefillPropane.lua
-- Single-file implementation: context menu + timed action + refill logic
-- Author: Tom & Copilot

-------------------------------------------------
-- Debug helper
-------------------------------------------------

local function RP_log(...)
    print("[RefillPropane]", ...)
end

-------------------------------------------------
-- Pump detection
-------------------------------------------------

local function isPropanePumpObject(obj)
    if not obj then return false end

    local sprite = obj:getSprite()
    if not sprite then return false end

    local name = sprite:getName() or ""
    local lower = string.lower(name)

    -- Exact sprite prefixes for B42 pumps
    local isPump =
        string.find(lower, "shop_fossoil_01", 1, true) or
        string.find(lower, "shop_gas2go_01", 1, true)

    RP_log("Checking object sprite:", name, "IsPump:", isPump and "true" or "false")

    return isPump
end

local function getPropanePump(square)
    if not square then
        RP_log("getPropanePump: no square")
        return nil
    end

    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if isPropanePumpObject(obj) then
            RP_log("getPropanePump: found pump on square", square:getX(), square:getY())
            return obj
        end
    end

    return nil
end

-- Vanilla-style: search adjacent squares too
local function findNearbyPump(square)
    for dx = -1, 1 do
        for dy = -1, 1 do
            local sq = getCell():getGridSquare(square:getX()+dx, square:getY()+dy, square:getZ())
            if sq then
                local pump = getPropanePump(sq)
                if pump then return pump end
            end
        end
    end
    return nil
end

-------------------------------------------------
-- Adjacency check (using engine method)
-------------------------------------------------

local function isAdjacentToSquare(playerObj, targetSquare)
    if not playerObj or not targetSquare then return false end

    local playerSquare = playerObj:getSquare()
    local adjacent = playerSquare:isAdjacentTo(targetSquare)

    RP_log("Adjacency check:",
        "Player square:", playerSquare:getX(), playerSquare:getY(), playerSquare:getZ(),
        "Target square:", targetSquare:getX(), targetSquare:getY(), targetSquare:getZ(),
        "Result:", adjacent and "true" or "false")

    return adjacent
end

-------------------------------------------------
-- Item predicates (safe + vanilla-accurate)
-------------------------------------------------

local function isValidBlowTorch(item)
    if not item then return false end
    if item:getType() ~= "BlowTorch" then return false end
    if not instanceof(item, "Drainable") then return false end

    local cur = item:getCurrentUses()
    local max = item:getMaxUses()

    local ok = cur < max

    RP_log("Blowtorch check:",
        "Type:", item:getType(),
        "Uses:", cur, "/", max,
        "Result:", ok and "true" or "false")

    return ok
end

local function isValidPropaneTank(item)
    if not item then return false end
    if item:getType() ~= "PropaneTank" then return false end
    if not instanceof(item, "Drainable") then return false end

    local cur = item:getCurrentUses()
    local max = item:getMaxUses()

    local ok = cur < max

    RP_log("Propane tank check:",
        "Type:", item:getType(),
        "Uses:", cur, "/", max,
        "Result:", ok and "true" or "false")

    return ok
end

-------------------------------------------------
-- Refill logic
-------------------------------------------------

local function refillItem(item)
    if not item then
        RP_log("refillItem: no item")
        return
    end

    RP_log("Refill start for item:", item:getType())

    -- PropaneTank (identical to BlowTorch logic)
    if item:getType() == "PropaneTank" then
        local cur = item:getCurrentUses()
        local max = item:getMaxUses()
        RP_log("PropaneTank before refill:", cur, "/", max)
        item:setCurrentUses(max)
        RP_log("PropaneTank after refill:", item:getCurrentUses(), "/", max)
        return
    end

    -- BlowTorch
    if item:getType() == "BlowTorch" then
        local cur = item:getCurrentUses()
        local max = item:getMaxUses()
        RP_log("Blowtorch before refill:", cur, "/", max)
        item:setCurrentUses(max)
        RP_log("Blowtorch after refill:", item:getCurrentUses(), "/", max)
        return
    end

    RP_log("refillItem: unsupported item type:", item:getType())
end

-------------------------------------------------
-- Timed action
-------------------------------------------------

ISRefillPropaneAction = ISBaseTimedAction:derive("ISRefillPropaneAction")

function ISRefillPropaneAction:isValid()
    if not self.item or not self.pumpObj then
        return false
    end

    -- Pump must still exist
    if not self.pumpObj:getSquare() then
        return false
    end

    -- Player must remain adjacent during the action
    return isAdjacentToSquare(self.character, self.pumpObj:getSquare())
end

function ISRefillPropaneAction:update()
    self.item:setJobDelta(self:getJobDelta())
    
    if self.sound ~= 0 and not self.character:getEmitter():isPlaying(self.sound) then
        self.sound = self.character:playSound("BlowTorch")
    end
    
end

function ISRefillPropaneAction:start()
    RP_log("TimedAction start for", self.item:getType())
    self.item:setJobType("Refilling")
    self.item:setJobDelta(0.0)

    self:setActionAnim("Loot")
    self:setOverrideHandModels(self.item, nil)
    self.character:SetVariable("LootPosition", "Mid")

    self.character:faceThisObject(self.pumpObj)
    self.sound = self.character:playSound("VehicleAddFuelFromGasPump")
end

function ISRefillPropaneAction:stop()
    RP_log("TimedAction stop for", self.item:getType())
    if self.sound ~= 0 then
        self.character:getEmitter():stopSound(self.sound)
    end
    ISBaseTimedAction.stop(self)
    self.item:setJobDelta(0.0)
end

function ISRefillPropaneAction:perform()
    RP_log("TimedAction perform for", self.item:getType())
    if self.sound ~= 0 then
        self.character:getEmitter():stopSound(self.sound)
    end
    self.item:setJobDelta(0.0)
    refillItem(self.item)
    ISBaseTimedAction.perform(self)
end

function ISRefillPropaneAction:new(playerObj, item, pumpObj)
    local o = ISBaseTimedAction.new(self, playerObj)
    o.item = item
    o.pumpObj = pumpObj
    o.maxTime = 600        -- 10 seconds
    o.stopOnWalk = true
    o.stopOnRun = true
    o.useProgressBar = true
    return o
end

-------------------------------------------------
-- Context menu hook
-------------------------------------------------

local function RP_onFillWorldObjectContextMenu(player, context, worldobjects, test)
    if test then return end

    if not worldobjects or #worldobjects == 0 then
        RP_log("ContextMenu: no worldobjects")
        return
    end

    local playerObj = getSpecificPlayer(player)
    if not playerObj then
        RP_log("ContextMenu: no playerObj")
        return
    end

    local firstObj = worldobjects[1]
    local square = firstObj and firstObj:getSquare()
    if not square then
        RP_log("ContextMenu: no square from first worldobject")
        return
    end

    local pumpObj = findNearbyPump(square)
    if not pumpObj then
        return
    end

    if not isAdjacentToSquare(playerObj, pumpObj:getSquare()) then
        RP_log("ContextMenu: player not adjacent to pump square")
        return
    end

    local inv = playerObj:getInventory()
    local items = inv:getItems()

    local foundAny = false

    for i = 0, items:size() - 1 do
        local item = items:get(i)

        if isValidBlowTorch(item) or isValidPropaneTank(item) then
            foundAny = true
            local optionText = "Refill " .. item:getName()

            RP_log("ContextMenu: adding option for", item:getType(), "as", optionText)

            context:addOption(
                optionText,
                worldobjects,
                function()
                    RP_log("ContextMenu: queueing timed action for", item:getType())
                    ISTimedActionQueue.add(ISRefillPropaneAction:new(playerObj, item, pumpObj))
                end
            )
        end
    end

    if not foundAny then
        RP_log("ContextMenu: no valid blowtorch or propane tank in inventory")
    end
end

Events.OnFillWorldObjectContextMenu.Add(RP_onFillWorldObjectContextMenu)