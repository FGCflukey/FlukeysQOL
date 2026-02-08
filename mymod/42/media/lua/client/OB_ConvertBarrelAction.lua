require "TimedActions/ISBaseTimedAction"

OB_ConvertBarrelAction = ISBaseTimedAction:derive("OB_ConvertBarrelAction")

-- Debug toggle
local OB_DEBUG = false   -- set to true to enable logging

local function OBFLog(...)
    if not OB_DEBUG then return end
    print("[OB_ConvertBarrelAction]", ...)
end

local function OB_GetConvertLabel()
    local txt = getText("ContextMenu_ConvertToFluidBarrel")
    if not txt or txt == "" or txt == "ContextMenu_ConvertToFluidBarrel" then
        return "Open Barrel"
    end
    return txt
end

local function hasFluidComponentSafe(barrel)
    if not barrel then
        OBFLog("hasFluidComponentSafe: barrel is nil")
        return false
    end
    if OrangeBarrelFluid and OrangeBarrelFluid.HasFluidComponent then
        local ok, res = pcall(OrangeBarrelFluid.HasFluidComponent, barrel)
        if not ok then
            OBFLog("HasFluidComponent errored:", res)
            return false
        end
        OBFLog("HasFluidComponent result:", tostring(res))
        return res and true or false
    else
        OBFLog("HasFluidComponent not available on OrangeBarrelFluid")
    end
    return false
end

function OB_ConvertBarrelAction:isValid()
    if not self.character or not self.barrel then
        return false
    end

    local wrench = OrangeBarrelFluid.getPlayerWrench(self.character)
    if not wrench then
        return false
    end

    if OrangeBarrelFluid.HasFluidComponent(self.barrel) then
        return false
    end

    return true
end

function OB_ConvertBarrelAction:start()
    OBFLog("start called")

    if self.barrel and self.character.faceThisObject then
        self.character:faceThisObject(self.barrel)
    else
        OBFLog("start: cannot face barrel (missing method or barrel)")
    end

    if self.setOverrideHandModels then
        self:setOverrideHandModels(self.wrench, nil)
    else
        OBFLog("start: setOverrideHandModels not available")
    end

    local label = OB_GetConvertLabel()
    self.wrench:setJobType(label)
    self.wrench:setJobDelta(0.0)

    if self.setActionAnim then
        self:setActionAnim("Loot")
    else
        OBFLog("start: setActionAnim not available")
    end

    if self.setAnimVariable then
        self:setAnimVariable("LootPosition", "Mid")
    else
        OBFLog("start: setAnimVariable not available")
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

function OB_ConvertBarrelAction:update()
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

function OB_ConvertBarrelAction:stop()
    OBFLog("stop called")

    if self.sound and self.character and self.character.stopOrTriggerSound then
        self.character:stopOrTriggerSound(self.sound)
        OBFLog("stop: sound stopped")
    end

    if self.wrench and self.wrench.setJobDelta then
        self.wrench:setJobDelta(0.0)
    end

    ISBaseTimedAction.stop(self)
end

function OB_ConvertBarrelAction:perform()
    OBFLog("perform called")

    if self.sound and self.character and self.character.stopOrTriggerSound then
        self.character:stopOrTriggerSound(self.sound)
        OBFLog("perform: sound stopped")
    end

    if self.wrench and self.wrench.setJobDelta then
        self.wrench:setJobDelta(0.0)
    end

    if not self.barrel then
        OBFLog("perform: barrel is nil, aborting conversion")
    else
        if OrangeBarrelFluid and OrangeBarrelFluid.AddFluidComponent then
            local ok, res = pcall(OrangeBarrelFluid.AddFluidComponent, self.barrel)
            if ok then
                OBFLog("perform: AddFluidComponent returned:", tostring(res))
            else
                OBFLog("perform: AddFluidComponent errored:", res)
            end
        else
            OBFLog("perform: OrangeBarrelFluid.AddFluidComponent not available")
        end
    end

    ISBaseTimedAction.perform(self)
end

function OB_ConvertBarrelAction:getDuration()
    if self.character and self.character.isTimedActionInstant and self.character:isTimedActionInstant() then
        return 1
    end
    return 270
end

function OB_ConvertBarrelAction:new(character, barrel, wrench, requireWrench)
    OBFLog("new called, barrel =", tostring(barrel), "wrench =", tostring(wrench))

    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.barrel = barrel
    o.wrench = wrench
    o.requireWrench = requireWrench
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
    o.maxTime = o:getDuration()
    return o
end