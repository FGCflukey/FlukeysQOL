require "TimedActions/ISBaseTimedAction"
require "OrangeBarrelFluid_Shared"

OB_ResetBarrelAction = ISBaseTimedAction:derive("OB_ResetBarrelAction")

-- Debug toggle
local OB_DEBUG = true   -- set to true to enable logging

local function OBFLog(...)
    if not OB_DEBUG then return end
    print("[OB_ResetBarrelAction]", ...)
end

local function OB_GetResetLabel()
    return "Reset Barrel"
end

function OB_ResetBarrelAction:isValid()
    if not self.character or not self.barrel then
        return false
    end

    local wrench = OrangeBarrelFluid.getPlayerWrench(self.character)
    if not wrench then
        -- Option B: Player speech when missing wrench
        self.character:Say("I need a pipe wrench to reset this barrel.")
        return false
    end

    if not OrangeBarrelFluid.HasFluidComponent(self.barrel) then
        return false
    end

    local comp = nil
    local okGet = pcall(function()
        if self.barrel.getComponent and ComponentType and ComponentType.FluidContainer then
            comp = self.barrel:getComponent(ComponentType.FluidContainer)
        end
    end)

    if okGet and comp and comp.getAmount then
        local amount = comp:getAmount()
        if amount > 0 then
            self.character:Say("Empty The Barrel Must Be Empty!")
            return false
        end
    end

    return true
end

function OB_ResetBarrelAction:start()
    OBFLog("start called")

    if self.barrel and self.character.faceThisObject then
        self.character:faceThisObject(self.barrel)
    end

    if self.setOverrideHandModels then
        self:setOverrideHandModels(self.wrench, nil)
    end

    self.wrench:setJobType(OB_GetResetLabel())
    self.wrench:setJobDelta(0.0)

    if self.setActionAnim then
        self:setActionAnim("Loot")
    end
    if self.setAnimVariable then
        self:setAnimVariable("LootPosition", "Mid")
    end

    local ok, soundOrErr = pcall(function()
        return self.character:playSound("RepairWithWrench")
    end)

    if ok then
        self.sound = soundOrErr
        OBFLog("start: sound started, id =", tostring(self.sound))
    else
        self.sound = nil
        OBFLog("start: playSound failed:", soundOrErr)
    end
end

function OB_ResetBarrelAction:update()
    if self.barrel and self.character.faceThisObject then
        self.character:faceThisObject(self.barrel)
    end

    if self.character.setMetabolicTarget then
        self.character:setMetabolicTarget(Metabolics.MediumWork)
    end

    if self.wrench and self.wrench.setJobDelta then
        self.wrench:setJobDelta(self:getJobDelta())
    end
end

function OB_ResetBarrelAction:stop()
    OBFLog("stop called")

    if self.sound and self.character.stopOrTriggerSound then
        self.character:stopOrTriggerSound(self.sound)
    end

    if self.wrench and self.wrench.setJobDelta then
        self.wrench:setJobDelta(0.0)
    end

    ISBaseTimedAction.stop(self)
end

function OB_ResetBarrelAction:perform()
    OBFLog("perform called")

    if self.sound and self.character.stopOrTriggerSound then
        self.character:stopOrTriggerSound(self.sound)
    end

    if self.wrench and self.wrench.setJobDelta then
        self.wrench:setJobDelta(0.0)
    end

    -- The actual mutation happens server-side (see OrangeBarrelFluid_Server.lua).
    -- We identify the barrel by square, not by object-list index — that list's
    -- order isn't guaranteed to match between client and server at the moment
    -- the command arrives, which caused index-based lookups to fail sometimes.
    if self.barrel then
        local square = self.barrel:getSquare()
        if square then
            OBFLog("perform: requesting server reset at", square:getX(), square:getY(), square:getZ())
            sendClientCommand(self.character, "OrangeBarrelFluid", "reset", {
                x = square:getX(), y = square:getY(), z = square:getZ()
            })
        else
            OBFLog("perform: barrel has no square, aborting")
        end
    end

    ISBaseTimedAction.perform(self)
end

function OB_ResetBarrelAction:getDuration()
    if self.character and self.character.isTimedActionInstant and self.character:isTimedActionInstant() then
        return 1
    end
    return 270
end

function OB_ResetBarrelAction:new(character, barrel, wrench)
    OBFLog("new called, barrel =", tostring(barrel), "wrench =", tostring(wrench))

    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.barrel = barrel
    o.wrench = wrench
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
    o.maxTime = o:getDuration()
    return o
end
