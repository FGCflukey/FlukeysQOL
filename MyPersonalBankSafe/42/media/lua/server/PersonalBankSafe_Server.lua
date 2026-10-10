-- My Personal Bank Safe -- server authority.
--
-- Real object construction (IsoThumpable + ItemContainer) and the full square-removal
-- sequence (including the special-objects-list ghost-reference fix) are adapted from
-- the subscribed PersonalSafe Workshop mod's own already-proven Server.createSafe /
-- removeSafeFromSquare -- see the comment on removeSafeFromSquare below for exactly
-- why the naive two-call removal isn't enough for an AddSpecialObject-spawned object.

if isClient() then return end

local Util = MPBS.Util
local Registry = MPBS.Registry
local MODULE = "MPBS"

local DEBUG = false
local function dbg(msg)
    if DEBUG then
        print("[MPBS:Server] " .. tostring(msg))
    end
end

---------------------------------------------------------
-- Small helpers
---------------------------------------------------------
local function playerIsNearSquare(player, square)
    local playerSquare = player:getSquare()
    if not playerSquare or not square then return false end
    if playerSquare:getZ() ~= square:getZ() then return false end
    local dx = math.abs(playerSquare:getX() - square:getX())
    local dy = math.abs(playerSquare:getY() - square:getY())
    return dx <= 1 and dy <= 1
end

local function findDecorativeSafeAt(square)
    if not square then return nil end
    local objs = square:getObjects()
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if Util.isVanillaDecorativeSafe(obj) and not Util.isSafe(obj) then
            return obj
        end
    end
    return nil
end

local function findOurSafeAt(square, safeId)
    if not square then return nil end
    local objs = square:getObjects()
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if Util.isSafe(obj) and obj:getModData().MPBS_safeId == safeId then
            return obj
        end
    end
    return nil
end

local function squareIsClearForPlacement(square)
    if not square then return false end
    local objs = square:getObjects()
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if Util.isSafe(obj) or Util.isVanillaDecorativeSafe(obj) then
            return false
        end
    end
    return true
end

--- B42: AddSpecialObject (used when we build the real safe) adds the object to BOTH
--- the square's objects list AND its special-objects list. RemoveTileObject only
--- clears the objects list, so the special-objects entry survives as a ghost
--- reference -- causing "IsoThumpable not found on square" and a tile that silently
--- refuses further placement. Mirrors vanilla ISAnvil:removeFromGround and the fix
--- already proven in the PersonalSafe Workshop mod.
local function removeSafeFromSquare(sq, obj)
    if not sq or not obj then return end
    pcall(function() sq:transmitRemoveItemFromSquare(obj) end)
    pcall(function() sq:RemoveTileObject(obj) end)
    pcall(function()
        local specials = sq:getSpecialObjects()
        if specials then specials:remove(obj) end
    end)
    pcall(function() sq:RecalcProperties() end)
end

local function removeDecorativeSafe(sq, obj)
    if not sq or not obj then return end
    sq:transmitRemoveItemFromSquare(obj)
    sq:RemoveTileObject(obj)
end

local function giveItem(player, fullType)
    local inv = player:getInventory()
    local item = inv:AddItem(fullType)
    if item and inv:contains(item) then
        sendAddItemToContainer(inv, item)
    end
    return item
end

local function removeOneItem(player, fullType)
    local inv = player:getInventory()
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it:getFullType() == fullType then
            inv:Remove(it)
            -- Removing server-side alone never tells the owning client -- the item
            -- just sits there visually even though the server already consumed it
            -- (same bug class already fixed throughout this pack, e.g. ATM_Server.lua).
            sendRemoveItemFromContainer(inv, it)
            return true
        end
    end
    return false
end

local function broadcastSafe(cmd, x, y, z, ownerKey)
    sendServerCommand(MODULE, cmd, { x = x, y = y, z = z, ownerKey = ownerKey })
end

---------------------------------------------------------
-- Detach: vanilla decorative safe -> carried item
---------------------------------------------------------
local function handleDetach(player, args)
    if not args or not args.x or not args.y or not args.z then return end
    local square = getCell():getGridSquare(args.x, args.y, args.z)
    if not square then return end
    if not playerIsNearSquare(player, square) then
        dbg(player:getUsername() .. " Detach rejected: not near square")
        return
    end

    local obj = findDecorativeSafeAt(square)
    if not obj then
        dbg("Detach rejected: no decorative safe at square (already taken?)")
        return
    end

    local inv = player:getInventory()
    local hasCrowbar = inv:getFirstTypeRecurse("Base.Crowbar") ~= nil
    if not hasCrowbar then
        local primary = player:getPrimaryHandItem()
        local secondary = player:getSecondaryHandItem()
        hasCrowbar = (primary and primary:getFullType() == "Base.Crowbar")
            or (secondary and secondary:getFullType() == "Base.Crowbar")
    end
    if not hasCrowbar then
        dbg(player:getUsername() .. " Detach rejected: no crowbar")
        return
    end

    removeDecorativeSafe(square, obj)
    giveItem(player, "MPBS.PersonalBankSafe")
    dbg(player:getUsername() .. " detached safe at " .. args.x .. "," .. args.y .. "," .. args.z)
end

---------------------------------------------------------
-- Place: carried item -> real safe
---------------------------------------------------------
local function handlePlace(player, args)
    if not args or not args.x or not args.y or not args.z or not args.direction then return end
    if not Util.SPRITES[args.direction] then return end

    local ownerKey = Util.getOwnerKey(player)
    if not ownerKey then return end

    if Registry.count(ownerKey) >= Util.getMaxSafesPerPlayer() then
        player:Say(getText("IGUI_MPBS_Limit"))
        return
    end

    local square = getCell():getGridSquare(args.x, args.y, args.z)
    if not square then return end
    if not playerIsNearSquare(player, square) then
        dbg(player:getUsername() .. " Place rejected: not near square")
        return
    end
    if not squareIsClearForPlacement(square) then
        player:Say(getText("IGUI_MPBS_Occupied"))
        return
    end

    if not removeOneItem(player, "MPBS.PersonalBankSafe") then
        dbg(player:getUsername() .. " Place rejected: no carried safe item")
        return
    end

    local cell = getCell()
    local sprite = Util.SPRITES[args.direction]
    local obj = IsoThumpable.new(cell, square, sprite, false, {})
    obj:setIsContainer(true)
    obj:setIsDismantable(false)
    obj:setIsThumpable(false)
    obj:setMaxHealth(1000000)
    obj:setHealth(1000000)

    local cont = ItemContainer.new("personalbanksafe", square, obj)
    cont:setCapacity(Util.getCapacityKg())
    cont:setExplored(true)
    obj:setContainer(cont)

    local safeId = Registry.newSafeId(ownerKey)
    local rec = Registry.owner(ownerKey)
    local displayNum = rec.idSeq or 1

    local md = obj:getModData()
    md.MPBS_isSafe = true
    md.MPBS_ownerKey = ownerKey
    md.MPBS_ownerName = player:getUsername()
    md.MPBS_safeId = safeId
    md.MPBS_direction = args.direction

    obj:setName(getText("IGUI_MPBS_SafeName", tostring(displayNum)))

    square:AddSpecialObject(obj)
    obj:transmitCompleteItemToClients()
    obj:transmitModData()

    Registry.add(ownerKey, player:getUsername(), args.x, args.y, args.z, safeId)
    broadcastSafe("SafeRegistered", args.x, args.y, args.z, ownerKey)

    dbg(player:getUsername() .. " placed safe " .. safeId .. " at " .. args.x .. "," .. args.y .. "," .. args.z)
end

---------------------------------------------------------
-- PickUp: real safe (empty, owner only) -> carried item
---------------------------------------------------------
local function handlePickUp(player, args)
    if not args or not args.x or not args.y or not args.z or not args.safeId then return end
    local ownerKey = Util.getOwnerKey(player)
    if not ownerKey then return end

    local square = getCell():getGridSquare(args.x, args.y, args.z)
    local obj = findOurSafeAt(square, args.safeId)
    if not obj then return end
    if obj:getModData().MPBS_ownerKey ~= ownerKey then
        dbg(player:getUsername() .. " PickUp rejected: not owner")
        return
    end
    local cont = obj:getContainer()
    if cont and not cont:isEmpty() then
        player:Say(getText("IGUI_MPBS_NotEmpty"))
        return
    end

    Registry.remove(ownerKey, args.safeId)
    broadcastSafe("SafeUnregistered", args.x, args.y, args.z, ownerKey)
    removeSafeFromSquare(square, obj)
    giveItem(player, "MPBS.PersonalBankSafe")

    dbg(player:getUsername() .. " picked up safe " .. args.safeId)
end

---------------------------------------------------------
-- Reset: real safe (empty, owner only) -> back to vanilla decoration
---------------------------------------------------------
local function handleReset(player, args)
    if not args or not args.x or not args.y or not args.z or not args.safeId then return end
    local ownerKey = Util.getOwnerKey(player)
    if not ownerKey then return end

    local square = getCell():getGridSquare(args.x, args.y, args.z)
    local obj = findOurSafeAt(square, args.safeId)
    if not obj then return end
    if obj:getModData().MPBS_ownerKey ~= ownerKey then
        dbg(player:getUsername() .. " Reset rejected: not owner")
        return
    end
    local cont = obj:getContainer()
    if cont and not cont:isEmpty() then
        player:Say(getText("IGUI_MPBS_NotEmpty"))
        return
    end

    local direction = obj:getModData().MPBS_direction or "S"
    local sprite = Util.SPRITES[direction] or Util.SPRITES.S

    Registry.remove(ownerKey, args.safeId)
    broadcastSafe("SafeUnregistered", args.x, args.y, args.z, ownerKey)
    removeSafeFromSquare(square, obj)

    -- Respawn the original, plain decorative object -- no container, no ownership.
    -- Constructor shape confirmed from vanilla's own moveable placement code
    -- (ISMoveableSpriteProps.lua:2104): IsoObject.new(getCell(), square, getSprite(name)).
    local decorative = IsoObject.new(getCell(), square, getSprite(sprite))
    square:AddTileObject(decorative)
    decorative:transmitCompleteItemToClients()

    dbg(player:getUsername() .. " reset safe " .. args.safeId .. " to vanilla")
end

---------------------------------------------------------
-- Known-safes sync (remote-client ownership fallback, see Util.lua header)
---------------------------------------------------------
local function handleRequestKnownSafes(player)
    sendServerCommand(player, MODULE, "KnownSafesSync", { safes = Registry.allSafes() })
end

---------------------------------------------------------
-- Dispatch
---------------------------------------------------------
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= MODULE then return end
    if not player then return end

    if command == "Detach" then
        handleDetach(player, args)
    elseif command == "Place" then
        handlePlace(player, args)
    elseif command == "PickUp" then
        handlePickUp(player, args)
    elseif command == "Reset" then
        handleReset(player, args)
    elseif command == "RequestKnownSafes" then
        handleRequestKnownSafes(player)
    end
end)
