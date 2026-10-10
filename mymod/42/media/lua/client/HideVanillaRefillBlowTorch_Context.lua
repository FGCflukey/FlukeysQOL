-- Hides vanilla's own, broken "Refill Welding Torch" option from the held-
-- item craft submenu, leaving only our RefillBlowTorch_QOL recipe (see
-- base_fixed.txt for why it can't just replace vanilla's recipe by name).
--
-- Recipe options store the real CraftRecipe object as option.param1
-- (ISInventoryPaneContextMenu.lua, addNewCraftingDynamicalContextMenu), and
-- ISContextMenu:removeOptionByName()/:getSubMenu() are the same real, public
-- methods vanilla's own context menu code uses. This walks the already-built
-- menu tree right after vanilla's own listener populates it and removes the
-- one option backed by vanilla's actual recipe object.

local VANILLA_RECIPE_NAME = "RefillBlowTorch"

local function isVanillaRefillOption(opt)
    -- Most context menu options (Equip, Drop, anything from a container like
    -- a cooler, etc.) have param1 == nil -- indexing nil for a method call
    -- throws in Kahlua, and PZ logs a full error dump for every pcall catch
    -- even though it doesn't crash. CONFIRMED (2026-10-10): this was spamming
    -- another player's client log on every single right-click in the game,
    -- not just the torch's. Checking the type first avoids the error
    -- entirely instead of catching it after the fact.
    local recipe = opt.param1
    if type(recipe) ~= "table" or not recipe.getName then return false end
    return recipe:getName() == VANILLA_RECIPE_NAME
end

local function stripVanillaOption(ctx)
    if not ctx or not ctx.options then return false end
    for _, opt in ipairs(ctx.options) do
        if isVanillaRefillOption(opt) then
            ctx:removeOptionByName(opt.name)
            return true
        end
    end
    for _, opt in ipairs(ctx.options) do
        if opt.subOption then
            local sub = ctx:getSubMenu(opt.subOption)
            if sub and stripVanillaOption(sub) then
                return true
            end
        end
    end
    return false
end

local function HideVanillaRefillBlowTorch(_player, context)
    stripVanillaOption(context)
end

Events.OnFillInventoryObjectContextMenu.Add(HideVanillaRefillBlowTorch)
