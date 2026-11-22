-- ===================================================================
--  Boulder Mining - shared definitions (client + server)
-- ===================================================================
--  Our own feature, informed by reading Workshop "Break Big Rocks"
--  (3538602374). What we kept from that research:
--   * vanilla boulder sprites are "boulders_N" (see vanilla
--     server/WorldGen/features/ore/boulders.lua for the layout)
--   * 0-7 are single-tile giants, 16-31 are 2x2 giants (4 sprites
--     each), 32/33 and 34/35 are 2-tile pairs, the rest are smaller.
--  What we do differently: break the WHOLE multi-tile boulder at once
--  (that mod removed only the clicked tile, leaving the other 3/4 of a
--  2x2 boulder behind), and do all the work in a server-side
--  complete() like vanilla's own ISPickAxeGroundCoverItem.
-- ===================================================================

BoulderMining = BoulderMining or {}

local DEBUG = false
local function dbg(msg) if DEBUG then print("[BoulderMining] " .. tostring(msg)) end end
BoulderMining.dbg = dbg

---------------------------------------------------------
-- Size profiles: loot is rolled ONCE per whole boulder.
-- {min, max} inclusive.
---------------------------------------------------------
BoulderMining.Profiles = {
    giant = {
        time = 400,
        loot = {
            { "Base.Stone2",      3, 5 },
            { "Base.LargeStone",  2, 3 },
            { "Base.FlintNodule", 1, 3 },
        },
        xp = 15,
    },
    medium = {
        time = 280,
        loot = {
            { "Base.Stone2",      2, 3 },
            { "Base.LargeStone",  1, 2 },
            { "Base.FlintNodule", 1, 2 },
        },
        xp = 10,
    },
    small = {
        time = 160,
        loot = {
            { "Base.Stone2",      1, 2 },
            { "Base.FlintNodule", 0, 1 },
        },
        xp = 5,
    },
}

---------------------------------------------------------
-- sprite name -> { profile = "giant"/..., group = id or nil }
-- group: sprites that together make ONE multi-tile boulder.
---------------------------------------------------------
local Defs = {}
BoulderMining.Defs = Defs
BoulderMining.GroupSprites = {}   -- group id -> set of sprite names

local function add(index, profile, group)
    local name = "boulders_" .. index
    Defs[name] = { profile = profile, group = group }
    if group then
        BoulderMining.GroupSprites[group] = BoulderMining.GroupSprites[group] or {}
        BoulderMining.GroupSprites[group][name] = true
    end
end

for i = 0, 7 do add(i, "giant") end
for i = 16, 31 do add(i, "giant", "g" .. math.floor((i - 16) / 4)) end
add(32, "medium", "p32"); add(33, "medium", "p32")
add(34, "medium", "p34"); add(35, "medium", "p34")
for _, i in ipairs({ 8, 10, 11, 13, 14, 15 }) do add(i, "medium") end
for _, i in ipairs({ 9, 12 }) do add(i, "small") end
-- B42 "boulders_light" set + map-placed variants (per the Workshop mod's
-- tile research). Harmless if a given index doesn't exist in this build.
for i = 40, 47 do add(i, "medium") end
for i = 56, 63 do add(i, "medium") end
add(49, "medium"); add(52, "medium")
for _, i in ipairs({ 48, 50, 51, 53, 54, 55 }) do add(i, "small") end

function BoulderMining.getSpriteName(obj)
    if not obj or not obj.getSprite then return nil end
    local spr = obj:getSprite()
    return spr and spr:getName() or nil
end

function BoulderMining.getDef(obj)
    local name = BoulderMining.getSpriteName(obj)
    return name and Defs[name] or nil, name
end

function BoulderMining.findOnSquare(sq)
    if not sq then return nil end
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if BoulderMining.getDef(obj) then return obj end
    end
    return nil
end

---------------------------------------------------------
-- Tools: must be in the primary hand to mine.
---------------------------------------------------------
local TOOL_TYPES = {
    PickAxe = true, PickAxeForged = true,
    Sledgehammer = true, Sledgehammer2 = true, SledgehammerForged = true,
}

function BoulderMining.isTool(item)
    if not item or item:isBroken() then return false end
    if TOOL_TYPES[item:getType()] then return true end
    return item:hasTag(ItemTag.PICK_AXE) or item:hasTag(ItemTag.SLEDGEHAMMER) or item:hasTag(ItemTag.STONE_MAUL)
end

---------------------------------------------------------
-- All world objects making up the boulder that `obj` belongs to.
-- 1) engine sprite grid, if the tiles define one
-- 2) otherwise flood-fill neighbouring squares for the other sprites
--    of the same group, each sprite name used once (so two identical
--    boulders sitting side by side never merge into one).
---------------------------------------------------------
function BoulderMining.collectParts(obj)
    local parts = { obj }
    local def, name = BoulderMining.getDef(obj)
    if not def then return parts end

    if obj.getSpriteGridObjectsIncludingSelf then
        local grid = ArrayList.new()
        obj:getSpriteGridObjectsIncludingSelf(grid)
        if grid:size() > 1 then
            parts = {}
            for i = 0, grid:size() - 1 do parts[#parts + 1] = grid:get(i) end
            dbg("sprite grid parts: " .. #parts)
            return parts
        end
    end

    if not def.group then return parts end
    local wanted = BoulderMining.GroupSprites[def.group]
    local used = { [name] = true }
    local queue = { obj:getSquare() }
    local seenSq = { [obj:getSquare()] = true }
    local qi = 1
    while qi <= #queue do
        local sq = queue[qi]; qi = qi + 1
        for _, nb in ipairs({ sq:getN(), sq:getS(), sq:getE(), sq:getW() }) do
            if nb and not seenSq[nb] then
                seenSq[nb] = true
                local objs = nb:getObjects()
                for i = 0, objs:size() - 1 do
                    local o = objs:get(i)
                    local n = BoulderMining.getSpriteName(o)
                    if n and wanted[n] and not used[n] then
                        used[n] = true
                        parts[#parts + 1] = o
                        queue[#queue + 1] = nb
                        break
                    end
                end
            end
        end
    end
    dbg("group " .. def.group .. " parts: " .. #parts)
    return parts
end

---------------------------------------------------------
-- Within reach of ANY tile of the boulder (same tolerance vanilla's
-- pickaxe/sledgehammer actions use: 1.6 tiles per axis).
---------------------------------------------------------
function BoulderMining.isWithinReach(character, parts)
    for _, o in ipairs(parts) do
        local sq = o:getSquare()
        if sq and sq:getZ() == math.floor(character:getZ()) then
            local dx = math.abs(sq:getX() + 0.5 - character:getX())
            local dy = math.abs(sq:getY() + 0.5 - character:getY())
            if dx <= 1.6 and dy <= 1.6 then return true end
        end
    end
    return false
end
