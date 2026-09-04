require "OrangeBarrelFluid_Shared"

local function OBFLog(...)
    if not OrangeBarrelFluid.DEBUG then return end
    print("[OrangeBarrelFluid]", ...)
end

--------------------------------------------------
-- RIGHT-CLICK Barrel Info Tooltip
--------------------------------------------------

Events.OnPreFillWorldObjectContextMenu.Add(function(player, context, worldobjects)
    -- Find the barrel
    local barrel = nil
    for _, obj in ipairs(worldobjects) do
        if OrangeBarrelFluid.IsOrangeBarrel(obj) then
            barrel = obj
            break
        end
    end
    if not barrel then return end

    local comp = OrangeBarrelFluid.GetFluidComponent(barrel)

    local text = "Empty Barrel"
    if comp then
        local amount = comp.getAmount and comp:getAmount() or 0

        if amount <= 0 then
            if comp.setFluidType then
                pcall(function() comp:setFluidType("") end)
            end
            text = "Empty Barrel"
        else
            local capacity = comp.getCapacity and comp:getCapacity() or 200
            local fluid = comp.getFluidType and comp:getFluidType() or "Unknown"
            text = fluid .. " (" .. tostring(amount) .. " / " .. tostring(capacity) .. ")"
        end
    end

    local infoOption = context:addOption("Barrel Info", nil)
    local tooltip = ISToolTip:new()
    tooltip:initialise()
    tooltip.description = text
    infoOption.toolTip = tooltip
end)

OBFLog("Orange Barrel Fluid Storage Mod loaded!")
