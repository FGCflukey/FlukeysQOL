require "TimedActions/ISBaseTimedAction"
LockpickTimedAction = ISBaseTimedAction:derive("LockpickTimedAction")

local function unlockVehicleDoor(player, vehicle, door)
    vehicle:playPartSound(door, player, "Unlock")
    door:getDoor():setLocked(false)
end

local function unlockDoor(player, door)
    player:getEmitter():playSound("UnlockDoor")
    door:setLockedByKey(false)
    door:setIsLocked(false)
    if instanceof(door, "IsoDoor") then
        door:setLocked(false)
    end
end

-- ⭐ Helper: return item to original container
local function returnItem(item, originalContainer, character)
    if not item or not originalContainer then return end

    local inv = character:getInventory()
    if inv:contains(item) then
        inv:Remove(item)
    end

    originalContainer:AddItem(item)
end

function LockpickTimedAction:isValid()
    return true
end

function LockpickTimedAction:update()
    if self.vehicle then
        self.character:faceThisObject(self.vehicle)
    else
        self.character:faceThisObject(self.door)
    end
end

function LockpickTimedAction:waitToStart()
    if self.vehicle then
        self.character:faceThisObject(self.vehicle)
    else
        self.character:faceThisObject(self.door)
    end
    return self.character:shouldBeTurning()
end

function LockpickTimedAction:start()
    local proxy = self.vehicle and self.vehicle or self.door
    self.character:getEmitter():playSound("PickLock", proxy)
    self:setActionAnim(CharacterActionAnims.InsertBullets)
end

function LockpickTimedAction:stop()
    ISBaseTimedAction.stop(self)
end

function LockpickTimedAction:perform()
    local failed = false

    -- Failure logic unchanged
    if getSandboxOptions():getOptionByName("simpleLockpicking.CanFailLockpick"):getValue() then
        local baseFailChance = getSandboxOptions():getOptionByName("simpleLockpicking.FailChance"):getValue()
        local burglarBonus = 0
        local trait = CharacterTrait.get(ResourceLocation.of("Burglar"))
        if self.character:hasTrait(trait) then
            burglarBonus = getSandboxOptions():getOptionByName("simpleLockpicking.BurglarBonus"):getValue()
        end

        local failChance = math.max(0, baseFailChance - burglarBonus)
        if (ZombRand(100) + 1) <= failChance then
            failed = true
            if getSandboxOptions():getOptionByName("simpleLockpicking.LosePaperclipOnFail"):getValue() then
                local inventory = self.character:getInventory()
                self.character:getPrimaryHandItem():UseItem()
                inventory:setDrawDirty(true)
                local proxy = self.vehicle and self.vehicle or self.door
                self.character:getEmitter():playSound("SnapPaperclip", proxy)
                self.character:Say(getText("IGUI_LockpickFailBreak"))
            else
                self.character:Say(getText("IGUI_LockpickFail"))
            end
        end
    end

    if not failed then
        if self.vehicle then
            unlockVehicleDoor(self.character, self.vehicle, self.door)
        else
            unlockDoor(self.character, self.door)
        end
    end

    -- ⭐ Return tools to original containers
    returnItem(self.paperclip, self.paperclipContainer, self.character)
    returnItem(self.screwdriver, self.screwdriverContainer, self.character)

    ISBaseTimedAction.perform(self)
end

function LockpickTimedAction:new(playerID, door, vehicle, paperclip, screwdriver, paperclipContainer, screwdriverContainer)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.playerID = playerID
    o.character = getSpecificPlayer(playerID)
    o.door = door
    o.vehicle = vehicle

    -- ⭐ Store tools + original containers
    o.paperclip = paperclip
    o.screwdriver = screwdriver
    o.paperclipContainer = paperclipContainer
    o.screwdriverContainer = screwdriverContainer

    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = math.max(1, round(300 / getSandboxOptions():getOptionByName("simpleLockpicking.ActionSpeedMult"):getValue()))
    if o.character:isTimedActionInstant() then o.maxTime = 1 end

    return o
end