--[[
    Repairable Glovebox and Heater
    A Timed action: Welding Heater repair.

    Built on top of The Indie Stone's ISBaseTimedAction (the standard PZ
    pattern for queued character actions). Purpose to forward a parameterized
    "repairHeater" message to the server when it completes.
]]

require "TimedActions/ISBaseTimedAction"

QOLHeaterRepairAction = ISBaseTimedAction:derive("QOLHeaterRepairAction")

local NET_MODULE    = "QOL_vehicle"
local NET_COMMAND   = "repairHeater"
local SOUND_BASE_R  = 20

-- ORIGINAL ANIM_NAME WAS INVALID IN B41/B42
-- local ANIM_NAME     = "BlowTorchMid"
local ANIM_NAME     = "Craft"

----------------------------------------------------------------
-- Local helpers
----------------------------------------------------------------
local function hushTorch(action)
    if action.sound then
        action.character:getEmitter():stopSound(action.sound)
        action.sound = nil
    end
    if action.blowtorch and action.blowtorch.setJobDelta then
        action.blowtorch:setJobDelta(0)
    end
end

local function ensureFullType(name)
    name = tostring(name)
    if name:find("%.") then return name end
    return "Base." .. name
end

local function fullyQualify(materials)
    local out = {}
    if type(materials) ~= "table" then return out end

    for partId, count in pairs(materials) do
        local key = ensureFullType(partId)
        out[key] = (out[key] or 0) + (tonumber(count) or 0)
    end
    return out
end

----------------------------------------------------------------
-- Constructor
----------------------------------------------------------------
function QOLHeaterRepairAction:new(character, part, blowtorch, mask, duration, materials, targetCondition)
    local instance = setmetatable({}, self)
    self.__index = self

    instance.character       = character
    instance.vehicle         = part and part:getVehicle() or nil
    instance.part            = part
    instance.blowtorch       = blowtorch
    instance.mask            = mask
    instance.requiredParts   = materials
    instance.targetCondition = targetCondition

    if character:isTimedActionInstant() then
        instance.maxTime = 1
    else
        instance.maxTime = duration
    end

    instance.stopOnWalk = true
    instance.stopOnRun  = true
    instance.sound      = nil
    instance.jobType    = getText("ContextMenu_Repair") .. " " .. getText("IGUI_VehiclePartHeater")
    return instance
end

----------------------------------------------------------------
-- Life cycle
----------------------------------------------------------------

function QOLHeaterRepairAction:isValid()
    -- Must have vehicle + part
    if not self.vehicle or not self.part then return false end

    -- Must be close enough to the vehicle (2 tiles squared)
    if self.character:DistToSquared(self.vehicle) > 4 then return false end

    -- Blowtorch must still have uses (modern drainable API)
    local uses = 0
    local maxUses = 0
    if self.blowtorch then
        if self.blowtorch.getCurrentUses and self.blowtorch.getMaxUses then
            uses = self.blowtorch:getCurrentUses()
            maxUses = self.blowtorch:getMaxUses()
        end
    end
    if uses <= 0 or maxUses <= 0 then return false end

    -- Mask must still exist
    if not self.mask then return false end

    -- Sheet metal must still exist
    local inv = self.character:getInventory()
    local needed = self.requiredParts.SmallSheetMetal or 0
    if inv:getItemCount("Base.SmallSheetMetal") < needed then
        return false
    end

    return true
end

function QOLHeaterRepairAction:waitToStart()
    self.character:faceThisObject(self.vehicle)
    return self.character:shouldBeTurning()
end

function QOLHeaterRepairAction:update()
    self.character:faceThisObject(self.vehicle)
    self.blowtorch:setJobDelta(self:getJobDelta())
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

-- ✔ FIXED animation: "Craft" works in B41/B42
function QOLHeaterRepairAction:start()
    self.blowtorch:setJobType(self.jobType)

    self:setActionAnim(ANIM_NAME)
    self:setOverrideHandModels(self.character:getPrimaryHandItem(), nil)

    self.sound = self.character:getEmitter():playSound("BlowTorch")

    local r = SOUND_BASE_R * self.character:getWeldingSoundMod()
    addSound(self.character,
        self.character:getX(), self.character:getY(), self.character:getZ(),
        r, r)
end

function QOLHeaterRepairAction:stop()
    hushTorch(self)
    ISBaseTimedAction.stop(self)
end

function QOLHeaterRepairAction:perform()
    hushTorch(self)

    sendClientCommand(self.character, NET_MODULE, NET_COMMAND, {
        vehicle         = self.part:getVehicle():getId(),
        part            = self.part:getId(),
        targetCondition = self.targetCondition,
        repairParts     = fullyQualify(self.requiredParts),
    })

    ISBaseTimedAction.perform(self)
end
