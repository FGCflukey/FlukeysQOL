-- Shared helpers for My Personal Bank Safe (MPBS).
--
-- Ownership and remote-client sync patterns here are adapted from the subscribed
-- PersonalSafe Workshop mod (3745891081), which already hit and fixed the real bug
-- class this guards against: a remote (non-owning) client's copy of a world object
-- can lag behind on ModData sync, so relying on obj:getModData() alone for an
-- ownership check can let a non-owner see/loot another player's safe. The fix is a
-- server-broadcast "known safes" map (coords -> ownerKey) that every client receives
-- independently of the object's own ModData replication, used as a fallback.

MPBS = MPBS or {}
MPBS.Util = MPBS.Util or {}
MPBS.knownSafes = MPBS.knownSafes or {} -- "x,y,z" -> ownerKey, populated by server broadcast

local Util = MPBS.Util

-- The decorative bank vault sprites (confirmed real IsoObject instances via in-game
-- probe, no existing container logic) -- also reused as-is for OUR placed safe, since
-- it's the exact same real tileset art, just now container-bearing.
Util.SPRITES = {
    E = "location_business_bank_01_68",
    S = "location_business_bank_01_69",
    W = "location_business_bank_01_70",
    N = "location_business_bank_01_71",
}

Util.SPRITE_SET = {}
for _, name in pairs(Util.SPRITES) do
    Util.SPRITE_SET[name] = true
end

Util.DIRECTIONS = { "N", "E", "S", "W" }

function Util.spriteName(obj)
    if not obj or not obj.getSprite then return nil end
    local spr = obj:getSprite()
    return spr and spr:getName() or nil
end

--- Is this a vanilla decorative bank safe (not yet ours)?
---@param obj IsoObject
---@return boolean
function Util.isVanillaDecorativeSafe(obj)
    local n = Util.spriteName(obj)
    return n ~= nil and Util.SPRITE_SET[n] == true
end

--- Stable per-CHARACTER owner key (SteamID + username; username alone on non-Steam
--- servers). One Steam account can run several characters -- keying on SteamID alone
--- would make their safes shared, which is the exact bug PersonalSafe's own comments
--- describe having to fix.
---@param player IsoPlayer
---@return string|nil
function Util.getOwnerKey(player)
    if not player then return nil end
    local name = player:getUsername() or "?"
    local id = player:getSteamID()
    if id and tostring(id) ~= "0" then
        return tostring(id) .. ":" .. name
    end
    return name
end

--- Coordinate key "x,y,z" for an object's square.
---@param obj IsoObject
---@return string|nil
function Util.coordKey(obj)
    if not obj or not obj.getSquare then return nil end
    local sq = obj:getSquare()
    if not sq then return nil end
    return sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ()
end

--- Owner of a safe as known from the synced known-safes broadcast (see note above).
---@param obj IsoObject
---@return string|nil
function Util.knownOwnerAt(obj)
    local k = Util.coordKey(obj)
    return k and MPBS.knownSafes[k] or nil
end

--- Is this world object one of our placed safes (vs still-decorative, or unrelated)?
---@param obj IsoObject
---@return boolean
function Util.isSafe(obj)
    if not obj or not obj.getModData then return false end
    local md = obj:getModData()
    if md ~= nil and md.MPBS_isSafe == true then return true end
    -- Reliable cross-client signal: our custom container type replicates with the
    -- world object even when ModData hasn't reached this client yet.
    local okType, isOurs = pcall(function()
        local c = obj.getContainer and obj:getContainer() or nil
        return c ~= nil and c.getType and c:getType() == "personalbanksafe"
    end)
    if okType and isOurs then return true end
    -- Remote-client fallback via the broadcast map.
    if Util.knownOwnerAt(obj) ~= nil then
        local okC, hasContainer = pcall(function()
            return obj.getContainer and obj:getContainer() ~= nil
        end)
        if okC and hasContainer then return true end
    end
    return false
end

--- Does the given player own this safe?
---@param obj IsoObject
---@param player IsoPlayer
---@return boolean
function Util.isOwner(obj, player)
    if not Util.isSafe(obj) then return false end
    local key = Util.getOwnerKey(player)
    if key == nil then return false end
    local stored = obj.getModData and obj:getModData().MPBS_ownerKey or nil
    if stored == nil then stored = Util.knownOwnerAt(obj) end
    if stored == nil then return false end
    return stored == key
end

-- ---------------------------------------------------------------------------
-- Sandbox options (SP-safe hardcoded fallback mirrors PersonalSafe_Config.lua)
-- ---------------------------------------------------------------------------

-- Must stay in sync with the numValues/order in sandbox-options.txt and the
-- Sandbox.json _option1.._option6 labels.
local CAPACITY_CHOICES_KG = { 50, 100, 200, 300, 400, 500 }
local DEFAULT_CAPACITY_INDEX = 2 -- 100 kg, matches sandbox-options.txt default

--- Capacity (kg) a newly placed safe should use.
---@return integer
function Util.getCapacityKg()
    local opts = getSandboxOptions and getSandboxOptions() or nil
    local opt = opts and opts:getOptionByName("MPBS.CapacityKg") or nil
    local idx = opt and opt:getValue() or nil
    if idx and CAPACITY_CHOICES_KG[idx] then
        return CAPACITY_CHOICES_KG[idx]
    end
    return CAPACITY_CHOICES_KG[DEFAULT_CAPACITY_INDEX]
end

--- Max safes one player may have placed at once.
---@return integer
function Util.getMaxSafesPerPlayer()
    local opts = getSandboxOptions and getSandboxOptions() or nil
    local opt = opts and opts:getOptionByName("MPBS.MaxSafesPerPlayer") or nil
    local v = opt and opt:getValue() or nil
    return v or 3
end

return Util
