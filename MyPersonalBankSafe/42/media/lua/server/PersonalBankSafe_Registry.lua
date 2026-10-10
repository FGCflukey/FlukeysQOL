-- Persistent per-owner safe registry (world-level ModData), mirrors the proven
-- structure in PersonalSafe_Registry.lua: tracks how many safes each owner has
-- placed (for the MaxSafesPerPlayer sandbox limit) and hands out stable safe ids.

if isClient() then return end

MPBS = MPBS or {}
local Registry = {}
MPBS.Registry = Registry

local KEY = "MPBS_Registry"

---@return table
function Registry.data()
    local data = ModData.getOrCreate(KEY)
    if data.version == nil then
        data.version = 1
        data.owners = data.owners or {}
    end
    return data
end

---@param ownerKey string
---@return table
function Registry.owner(ownerKey)
    local owners = Registry.data().owners
    owners[ownerKey] = owners[ownerKey] or { username = "", safes = {} }
    return owners[ownerKey]
end

---@param ownerKey string
---@return integer
function Registry.count(ownerKey)
    local rec = Registry.data().owners[ownerKey]
    return rec and #rec.safes or 0
end

---@param ownerKey string
---@param username string
---@param x integer
---@param y integer
---@param z integer
---@param safeId string
function Registry.add(ownerKey, username, x, y, z, safeId)
    local rec = Registry.owner(ownerKey)
    rec.username = username
    table.insert(rec.safes, { x = x, y = y, z = z, safeId = safeId })
end

---@param ownerKey string
---@param safeId string
---@return boolean
function Registry.remove(ownerKey, safeId)
    local rec = Registry.data().owners[ownerKey]
    if not rec then return false end
    for i = #rec.safes, 1, -1 do
        if rec.safes[i].safeId == safeId then
            table.remove(rec.safes, i)
            return true
        end
    end
    return false
end

---@param ownerKey string
---@return string
function Registry.newSafeId(ownerKey)
    local rec = Registry.owner(ownerKey)
    rec.idSeq = (rec.idSeq or 0) + 1
    return ownerKey .. ":" .. tostring(rec.idSeq)
end

--- Every currently-registered safe across all owners, for the join/reconnect sync.
---@return table array of { x, y, z, ownerKey }
function Registry.allSafes()
    local out = {}
    for ownerKey, rec in pairs(Registry.data().owners) do
        for _, s in ipairs(rec.safes) do
            table.insert(out, { x = s.x, y = s.y, z = s.z, ownerKey = ownerKey })
        end
    end
    return out
end

Events.OnInitGlobalModData.Add(function()
    Registry.data()
end)

return Registry
