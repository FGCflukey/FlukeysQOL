-- ===================================================================
--  Faster tire inflating + crouch animation
-- ===================================================================
--  Wraps vanilla ISInflateTire (shared/Vehicles/TimedActions):
--   * 3x faster: vanilla is 100 ticks per PSI. getDuration() runs on
--     both client and server (server uses it for the net action), so
--     wrapping it here keeps both sides agreed on the length.
--   * Low "Loot" crouch for the whole action (same anim + variable
--     vanilla's ISGrabItemAction uses for picking up floor items).
--   * Faces the tire itself instead of the vehicle's center.
--  Everything else (PSI updates, server complete(), sync) is vanilla.
-- ===================================================================

require "TimedActions/ISBaseTimedAction"
require "Vehicles/TimedActions/ISInflateTire"

local DEBUG = false
local function dbg(msg)
    if DEBUG then print("[FasterTireInflate] " .. tostring(msg)) end
end

local SPEED_MULTIPLIER = 3

if not ISInflateTire then
    dbg("ISInflateTire not found, patch skipped")
    return
end

local original_getDuration = ISInflateTire.getDuration
local original_start       = ISInflateTire.start
local original_update      = ISInflateTire.update

function ISInflateTire:getDuration()
    local t = original_getDuration(self)
    if not t or t <= 1 then return t end
    local fast = math.max(1, math.ceil(t / SPEED_MULTIPLIER))
    dbg("duration " .. tostring(t) .. " -> " .. tostring(fast))
    return fast
end

-- Center of this tire's area on the vehicle, or nil.
local function getTireSpot(self)
    if not self.vehicle or not self.part then return nil end
    local area = self.part:getArea()
    if not area then return nil end
    local vec = self.vehicle:getAreaCenter(area)
    if not vec then return nil end
    return vec:getX(), vec:getY()
end

function ISInflateTire:start()
    original_start(self)
    self:setActionAnim("Loot")
    self:setAnimVariable("LootPosition", "Low")
end

function ISInflateTire:update()
    original_update(self)
    -- Vanilla faces the vehicle's center every tick; turn toward the tire instead.
    local x, y = getTireSpot(self)
    if x and y then
        self.character:faceLocationF(x, y)
    end
end
