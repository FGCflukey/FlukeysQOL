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
    if self.sound ~= 0 and not self.character:getEmitter():isPlaying(self.sound) then
        self.sound = self.character:playSound("BlowTorch")
    end
end

function ISRefillPropaneAction:start()
    self.item:setJobType("Refilling")
    self.item:setJobDelta(0.0)
    self.originalContainer = self.item:getContainer()
    self:setActionAnim("Loot")
    self:setOverrideHandModels(self.item, nil)
    self.character:SetVariable("LootPosition", "Mid")
    self.character:faceThisObject(self.pumpObj)
    self.sound = self.character:playSound("VehicleAddFuelFromGasPump")
end

function ISRefillPropaneAction:stop()
    if self.sound ~= 0 then
        self.character:getEmitter():stopSound(self.sound)
    end
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function ISRefillPropaneAction:perform()
    if self.sound ~= 0 then
        self.character:getEmitter():stopSound(self.sound)
    end
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

    for _, item in ipairs(refillables) do
        context:addOption("Refill " .. item:getName(), worldobjects, function()
            ISTimedActionQueue.add(ISRefillPropaneAction:new(playerObj, item, pumpObj))
        end)
    end
end

Events.OnFillWorldObjectContextMenu.Add(RP_onFillWorldObjectContextMenu)