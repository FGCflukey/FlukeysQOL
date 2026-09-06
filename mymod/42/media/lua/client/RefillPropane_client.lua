local function RP_log(msg)
    print("[RefillPropane-Client] " .. tostring(msg))
end

ISRefillPropaneAction = ISBaseTimedAction:derive("ISRefillPropaneAction")

function ISRefillPropaneAction:isValid()
    if not self.item or not self.pumpObj then return false end
    if not self.pumpObj:getSquare() then return false end
    return RefillPropane.isAdjacentToSquare(self.character, self.pumpObj:getSquare())
end

function ISRefillPropaneAction:update()
    self.item:setJobDelta(self:getJobDelta())
end

function ISRefillPropaneAction:start()
    self.item:setJobType("Refilling")
    self.item:setJobDelta(0.0)
    self.originalContainer = self.item:getContainer()

    self.character:faceThisObject(self.pumpObj)

    -- Same "hold the container up and fill it" animation vanilla uses
    -- for filling a canteen/bottle at a tap (ISTakeWaterAction), which
    -- is the closer real-world match here than the gas-canister-pour
    -- animation -- we're filling a held tank/torch from a pump, not
    -- pouring one container into another.
    self:setActionAnim("fill_container_tap")
    if self.character:isSecondaryHandItem(nil) then
        self:setOverrideHandModels(nil, self.item:getStaticModel())
    else
        self:setOverrideHandModels(self.item:getStaticModel(), nil)
    end

    self.sound = self.character:playSound("VehicleAddFuelFromGasPump")
end

function ISRefillPropaneAction:stop()
    self.character:stopOrTriggerSound(self.sound)
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function ISRefillPropaneAction:perform()
    self.character:stopOrTriggerSound(self.sound)
    self.item:setJobDelta(0.0)

    -- Auto-return to original container (visual only — item never leaves the player's control)
    if self.originalContainer and self.item:getContainer() ~= self.originalContainer then
        self.originalContainer:AddItem(self.item)
    end

    RP_log("Requesting server refill for itemID " .. tostring(self.item:getID()))
    sendClientCommand(self.character, "RefillPropane", "refill", { itemID = self.item:getID() })

    ISBaseTimedAction.perform(self)
end

function ISRefillPropaneAction:new(playerObj, item, pumpObj)
    local o = ISBaseTimedAction.new(self, playerObj)
    o.item = item
    o.pumpObj = pumpObj
    o.maxTime = 600
    o.stopOnWalk = true
    o.stopOnRun = true
    o.useProgressBar = true
    return o
end

-------------------------------------------------
-- Context menu: one "Fill Propane Tank" / "Fill
-- Propane Torch" option per item type instead of
-- one option per item. A single item of a type
-- fills directly; more than one opens a submenu
-- with "Refill All" plus one entry per item.
-------------------------------------------------

local function RP_itemLabel(item)
    local pct = 0
    local maxUses = item:getMaxUses()
    if maxUses and maxUses > 0 then
        pct = math.floor((item:getCurrentUses() / maxUses) * 100)
    end
    return item:getName() .. " (" .. pct .. "%)"
end

local function RP_queueRefill(playerObj, item, pumpObj)
    ISTimedActionQueue.add(ISRefillPropaneAction:new(playerObj, item, pumpObj))
end

local function RP_addRefillOption(context, label, items, playerObj, pumpObj)
    if #items == 0 then return end

    if #items == 1 then
        local item = items[1]
        context:addOption(label, nil, function()
            RP_queueRefill(playerObj, item, pumpObj)
        end)
        return
    end

    local mainOption = context:addOption(label, nil, nil)
    local submenu = ISContextMenu:getNew(context)
    context:addSubMenu(mainOption, submenu)

    submenu:addOption("Refill All", nil, function()
        for _, item in ipairs(items) do
            RP_queueRefill(playerObj, item, pumpObj)
        end
    end)

    for _, item in ipairs(items) do
        submenu:addOption(RP_itemLabel(item), nil, function()
            RP_queueRefill(playerObj, item, pumpObj)
        end)
    end
end

local function RP_onFillWorldObjectContextMenu(player, context, worldobjects, test)
    if test then return end

    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end

    local firstObj = worldobjects[1]
    local square = firstObj and firstObj:getSquare()
    if not square then return end

    local pumpObj = RefillPropane.findNearbyPump(square)
    if not pumpObj then return end
    if not RefillPropane.isAdjacentToSquare(playerObj, pumpObj:getSquare()) then return end

    local refillables = RefillPropane.getAllRefillableItems(playerObj)
    if #refillables == 0 then return end

    local torches, tanks = {}, {}
    for _, item in ipairs(refillables) do
        if item:getType() == "BlowTorch" then
            table.insert(torches, item)
        elseif item:getType() == "PropaneTank" then
            table.insert(tanks, item)
        end
    end

    RP_addRefillOption(context, "Fill Propane Torch", torches, playerObj, pumpObj)
    RP_addRefillOption(context, "Fill Propane Tank", tanks, playerObj, pumpObj)
end

Events.OnFillWorldObjectContextMenu.Add(RP_onFillWorldObjectContextMenu)
