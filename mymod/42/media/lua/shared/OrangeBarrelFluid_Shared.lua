OrangeBarrelFluid = OrangeBarrelFluid or {}
OrangeBarrelFluid.DEBUG = true

local function OBFLog(...)
    if not OrangeBarrelFluid.DEBUG then return end
    print("[OrangeBarrelFluid]", ...)
end

--------------------------------------------------
-- Utils
--------------------------------------------------

-- These barrels (and MetalDrum) always carry a FluidContainer component now,
-- declared directly on their vanilla item scripts — see
-- media/scripts/items/OB_FluidBarrels.txt. No conversion step needed.
function OrangeBarrelFluid.IsOrangeBarrel(object)
    if not object then
        OBFLog("IsOrangeBarrel: object is nil")
        return false
    end

    local sprite = object.getSprite and object:getSprite() or nil
    if not sprite then
        OBFLog("IsOrangeBarrel: no sprite")
        return false
    end

    local spriteName = sprite.getName and sprite:getName() or nil
    if not spriteName then
        OBFLog("IsOrangeBarrel: sprite has no name")
        return false
    end

    OBFLog("IsOrangeBarrel: spriteName =", spriteName)

    return spriteName == "crafted_01_32"
        or spriteName == "location_military_generic_01_14"
        or spriteName == "location_military_generic_01_15"
        or spriteName == "location_military_generic_01_6"
        or spriteName == "location_military_generic_01_7"
        or spriteName == "industry_01_22"
        or spriteName == "industry_01_23"
end

-- Reads the OUR fluid container (by ContainerName, so we don't misreport a
-- barrel another mod — e.g. LG Extended Plumbing — has attached its own
-- FluidContainer to for an unrelated purpose).
function OrangeBarrelFluid.GetFluidComponent(barrel)
    if not barrel then return nil end

    local comp = nil
    pcall(function()
        if ComponentType and ComponentType.FluidContainer and barrel.hasComponent and barrel.getComponent then
            if barrel:hasComponent(ComponentType.FluidContainer) then
                local c = barrel:getComponent(ComponentType.FluidContainer)
                if c and c.getContainerName and c:getContainerName() == "OrangeBarrel" then
                    comp = c
                end
            end
        end
    end)

    return comp
end
