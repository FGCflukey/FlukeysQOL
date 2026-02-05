-- ClothingBreakdown_Material.lua
-- Hybrid material detection system (Override → Name → Normalized → Fallback)

ClothingBreakdown_Material = {}

-- Keyword-based name detection
local NameMaterialMap = {
    -- Leather indicators
    leather = "leather",
    cowhide = "leather",
    boot = "leather",
    army = "leather",
    military = "leather",

    -- Denim indicators
    denim = "denim",
    jeans = "denim",

    -- Cotton indicators
    shirt = "cotton",
    tshirt = "cotton",
    blouse = "cotton",
    sweater = "cotton",
    hoodie = "cotton",
    jacket = "cotton",
}

-- Normalize ANY detected material to one of the 3 valid categories
local function normalize(mat)
    if mat == "leather" then return "leather" end
    if mat == "denim" then return "denim" end
    if mat == "cotton" then return "cotton" end

    -- Anything unknown becomes cotton
    return "cotton"
end

-- Detect material from item name
local function detectFromName(item)
    local name = item:getFullType():lower()

    for keyword, mat in pairs(NameMaterialMap) do
        if name:find(keyword) then
            return mat
        end
    end

    return nil
end

-- Main detection function
function ClothingBreakdown_Material.detect(item, overrideMaterial)
    -- 1. Override wins
    if overrideMaterial then
        return normalize(overrideMaterial)
    end

    -- 2. Name-based detection
    local nameMat = detectFromName(item)
    if nameMat then
        return normalize(nameMat)
    end

    -- 3. Fallback
    return "cotton"
end

return ClothingBreakdown_Material