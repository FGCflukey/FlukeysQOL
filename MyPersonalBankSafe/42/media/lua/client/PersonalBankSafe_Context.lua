-- My Personal Bank Safe -- client context menu wiring.
--
-- Three separate interactions, all gated server-side (this file only decides what
-- options to SHOW -- the server in PersonalBankSafe_Server.lua re-validates every one
-- of these before touching anything, same pattern as CarPartRepair/Vendor):
--   1. "Detach Safe from Floor" on the vanilla decorative bank vault.
--   2. "Place Personal Bank Safe" (4-direction submenu) on the carried item.
--   3. "Pick Up Safe" / "Reset to Vanilla" (owner, empty only) or nothing at all
--      (non-owner -- the open/examine option is stripped so it looks exactly like
--      vanilla's own inert decorative safe) on a placed safe.

local Util = MPBS.Util
local MODULE = "MPBS"

local DEBUG = false
local function dbg(msg)
    if DEBUG then
        print("[MPBS:Context] " .. tostring(msg))
    end
end

---------------------------------------------------------
-- Crowbar check -- recursive inventory search + both hand slots, per spec.
---------------------------------------------------------
local function hasCrowbar(player)
    local inv = player:getInventory()
    if inv:getFirstTypeRecurse("Base.Crowbar") then return true end

    local primary = player:getPrimaryHandItem()
    if primary and primary:getFullType() == "Base.Crowbar" then return true end

    local secondary = player:getSecondaryHandItem()
    if secondary and secondary:getFullType() == "Base.Crowbar" then return true end

    return false
end

---------------------------------------------------------
-- 1. Detach: vanilla decorative safe -> carried item
---------------------------------------------------------
local function onDetach(obj, player)
    ISTimedActionQueue.add(ISMPBSHeavyLiftAction:new(player, obj, function(character, liftedObj)
        local sq = liftedObj:getSquare()
        if not sq then return end
        sendClientCommand(character, MODULE, "Detach", { x = sq:getX(), y = sq:getY(), z = sq:getZ() })
    end))
end

---------------------------------------------------------
-- 2. Place: carried item -> real safe, 4-direction submenu
---------------------------------------------------------
local DIRECTION_LABELS = {
    N = "IGUI_MPBS_FaceNorth",
    E = "IGUI_MPBS_FaceEast",
    S = "IGUI_MPBS_FaceSouth",
    W = "IGUI_MPBS_FaceWest",
}

local function onPlace(item, player, direction)
    local sq = player:getSquare()
    if not sq then return end
    local target = sq:getAdjacentSquare(player:getDir())
    if not target then return end
    sendClientCommand(player, MODULE, "Place", {
        x = target:getX(), y = target:getY(), z = target:getZ(),
        direction = direction,
    })
end

local function addPlaceOption(context, item, player)
    local mainOption = context:addOption(getText("IGUI_MPBS_PlaceOption"), item, nil)
    local submenu = ISContextMenu:getNew(context)
    context:addSubMenu(mainOption, submenu)

    for _, dir in ipairs(Util.DIRECTIONS) do
        submenu:addOption(getText(DIRECTION_LABELS[dir]), item, function()
            onPlace(item, player, dir)
        end)
    end
end

Events.OnFillInventoryObjectContextMenu.Add(function(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then return end

    for _, item in ipairs(items) do
        local actual = item.items and item.items[1] or item
        if actual and actual.getFullType and actual:getFullType() == "MPBS.PersonalBankSafe" then
            addPlaceOption(context, actual, player)
            return
        end
    end
end)

---------------------------------------------------------
-- 3. World object menu: detach OR owner/non-owner branching on a placed safe
---------------------------------------------------------
local function addDisabled(context, text)
    local opt = context:addOption(text, nil, nil)
    opt.notAvailable = true
    return opt
end

local function onPickUp(obj, player)
    local safeId = obj:getModData().MPBS_safeId
    ISTimedActionQueue.add(ISMPBSHeavyLiftAction:new(player, obj, function(character, liftedObj)
        local sq = liftedObj:getSquare()
        if not sq then return end
        sendClientCommand(character, MODULE, "PickUp", {
            x = sq:getX(), y = sq:getY(), z = sq:getZ(),
            safeId = safeId,
        })
    end))
end

local function onReset(obj, player)
    local sq = obj:getSquare()
    if not sq then return end
    sendClientCommand(player, MODULE, "Reset", {
        x = sq:getX(), y = sq:getY(), z = sq:getZ(),
        safeId = obj:getModData().MPBS_safeId,
    })
end

Events.OnFillWorldObjectContextMenu.Add(function(playerNum, context, worldobjects, test)
    if test then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    -- `worldobjects` is a plain Lua array here (ipairs), not a Java list.
    for _, obj in ipairs(worldobjects) do
        if Util.isVanillaDecorativeSafe(obj) and not Util.isSafe(obj) then
            if hasCrowbar(player) then
                context:addOption(getText("IGUI_MPBS_DetachOption"), obj, onDetach, player)
            else
                addDisabled(context, getText("IGUI_MPBS_NeedCrowbar"))
            end
            return
        end

        if Util.isSafe(obj) then
            local cont = obj.getContainer and obj:getContainer() or nil
            local empty = cont == nil or cont:isEmpty()

            if Util.isOwner(obj, player) then
                if empty then
                    context:addOption(getText("IGUI_MPBS_PickUpOption"), obj, onPickUp, player)
                    context:addOption(getText("IGUI_MPBS_ResetOption"), obj, onReset, player)
                end
                -- vanilla's own open/examine option is left in place for the owner
            else
                -- Non-owner: strip vanilla's auto-added open/examine option so this
                -- behaves exactly like an untouched vanilla decorative safe. Matches
                -- PersonalSafe_Context.lua's own proven technique.
                local label = ISWorldObjectContextMenu.getMoveableDisplayName
                    and ISWorldObjectContextMenu.getMoveableDisplayName(obj)
                    or nil
                if not label or label == "" then
                    label = obj:getName()
                end
                if label and label ~= "" then
                    context:removeOptionByName(label)
                end
            end
            return
        end
    end
end)

---------------------------------------------------------
-- Known-safes broadcast (remote-client ownership fallback, see Util.lua header)
---------------------------------------------------------
Events.OnServerCommand.Add(function(module, command, args)
    if module ~= MODULE then return end

    if command == "SafeRegistered" and args then
        local key = args.x .. "," .. args.y .. "," .. args.z
        MPBS.knownSafes[key] = args.ownerKey
        dbg("known safe registered at " .. key)
    elseif command == "SafeUnregistered" and args then
        local key = args.x .. "," .. args.y .. "," .. args.z
        MPBS.knownSafes[key] = nil
        dbg("known safe unregistered at " .. key)
    elseif command == "KnownSafesSync" and args and args.safes then
        for _, s in ipairs(args.safes) do
            MPBS.knownSafes[s.x .. "," .. s.y .. "," .. s.z] = s.ownerKey
        end
        dbg("known safes synced: " .. tostring(#args.safes))
    end
end)

-- Ask the server for the full known-safes list once on join/reconnect.
Events.OnCreatePlayer.Add(function(playerNum, player)
    if playerNum ~= 0 then return end
    sendClientCommand(player, MODULE, "RequestKnownSafes", {})
end)
