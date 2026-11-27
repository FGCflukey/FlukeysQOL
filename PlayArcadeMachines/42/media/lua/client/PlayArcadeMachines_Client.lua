-- Play Arcade Machines -- CLIENT
--
-- Context menu + local animation/sound for playing a vanilla arcade or
-- pinball machine. Real stat reduction (boredom/unhappiness/stress) is NOT
-- done here -- it's server-authoritative (see PlayArcadeMachines_Server.lua).
-- This file only ever requests; the server re-validates power/position and
-- applies the real change itself.
--
-- Animation and arcade sounds come from my old B41 "Play Modded Arcades" mod.

local DEBUG = false
local function dbg(msg)
    if DEBUG then
        print("[PlayArcadeMachines:Client] " .. tostring(msg))
    end
end

local function tableContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then return true end
    end
    return false
end

local ARCADE_MACHINE_SPRITES = {
    ArcadeMachine1 = { "recreational_01_16", "recreational_01_17", "recreational_01_18", "recreational_01_19" },
    ArcadeMachine2 = { "recreational_01_20", "recreational_01_21", "recreational_01_22", "recreational_01_23" },
    PinballMachine = { "recreational_01_24", "recreational_01_27" },
}

local function getArcadeMachineType(spriteName)
    for machineType, sprites in pairs(ARCADE_MACHINE_SPRITES) do
        if tableContains(sprites, spriteName) then
            return machineType
        end
    end
    return nil
end

-- Per-machine sounds: a looping "playing" sound, plus a one-shot "end" sound
-- on full completion. Pinball has a single loop and no end sound.
local MACHINE_SOUNDS = {
    ArcadeMachine1 = { play = "PAMGArcadianplay", finish = "PAMGArcadianend" },
    ArcadeMachine2 = { play = "PAMGArcadianplay", finish = "PAMGArcadianend" },
    PinballMachine = { play = "PinballMachine", finish = nil },
}

-- Which side of each machine sprite the player stands on to play.
local FRONT_DIR = {
    recreational_01_16 = "S", recreational_01_20 = "S", recreational_01_24 = "S",
    recreational_01_17 = "E", recreational_01_21 = "E", recreational_01_27 = "E",
    recreational_01_19 = "N", recreational_01_23 = "N",
    recreational_01_18 = "W", recreational_01_22 = "W",
}

local function getFrontTile(square, spriteName)
    local dir = FRONT_DIR[spriteName]
    if not dir then return nil end
    if dir == "S" then return square:getS() end
    if dir == "E" then return square:getE() end
    if dir == "N" then return square:getN() end
    if dir == "W" then return square:getW() end
    return nil
end

-- Real vanilla ambient-grid-power formula, same one already confirmed this
-- session against SandboxVars.ElecShutModifier (matches ISWeatherChannel.lua).
local function isAmbientGridStillOn()
    local ok, powerOffDay = pcall(function() return getSandboxOptions():getElecShutModifier() end)
    if not ok then return true end
    if powerOffDay <= -1 then return true end
    local ok2, day = pcall(function()
        return getGameTime():getWorldAgeHours() / 24 + (getSandboxOptions():getTimeSinceApo() - 1) * 30
    end)
    if not ok2 then return true end
    return day < powerOffDay
end

local function isMachinePowered(square)
    if not square then return false end
    local ok, real = pcall(function() return square:haveElectricity() end)
    if ok and real then return true end
    local ok2, gridOn = pcall(function() return square:hasGridPower() end)
    return ok2 and gridOn and isAmbientGridStillOn()
end

---------------------------------------------------------
-- PlayArcadeTimedAction
---------------------------------------------------------
PlayArcadeTimedAction = ISBaseTimedAction:derive("PlayArcadeTimedAction")

function PlayArcadeTimedAction:isValid()
    if not self.character or not self.object then return false end

    local square = self.object:getSquare()
    if not isMachinePowered(square) then
        if not self.hasSaidPowerMessage then
            self.character:Say(getText("ContextMenu_PlayArcade_NoPower"))
            self.hasSaidPowerMessage = true
        end
        return false
    end

    if self.frontTile and self.frontTile ~= self.character:getSquare() then
        if not self.hasSaidMessage then
            self.character:Say(getText("ContextMenu_PlayArcade_StepInFront"))
            self.hasSaidMessage = true
        end
        return false
    end

    return true
end

function PlayArcadeTimedAction:update()
    if self.object then
        self.character:faceThisObject(self.object)
    end
    self:setActionAnim("PlayArcadian")

    if not self.gameSound then
        local soundRadius = 20
        local volume = 6
        local sounds = MACHINE_SOUNDS[self.machineType] or MACHINE_SOUNDS.ArcadeMachine1
        self.gameSound = self.character:getEmitter():playSound(sounds.play)
        dbg("Playing sound: " .. sounds.play)
        addSound(self.character, self.character:getX(), self.character:getY(), self.character:getZ(), soundRadius, volume)
    end
end

function PlayArcadeTimedAction:start()
    local square = self.object:getSquare()
    sendClientCommand(self.character, "PlayArcadeMachines", "StartPlaying", {
        x = square:getX(), y = square:getY(), z = square:getZ(),
        machineType = self.machineType,
    })
end

local function stopSound(action)
    if action.gameSound then
        action.character:getEmitter():stopSound(action.gameSound)
        action.gameSound = nil
    end
end

function PlayArcadeTimedAction:stop()
    stopSound(self)
    sendClientCommand(self.character, "PlayArcadeMachines", "StopPlaying", {})
    ISBaseTimedAction.stop(self)
end

function PlayArcadeTimedAction:perform()
    stopSound(self)
    -- "End" sound only on a real, full completion -- not on stop() (walking
    -- away mid-session), matching the "game over" feel of the old mod's
    -- sound pair rather than playing a finishing jingle for a game you
    -- never actually finished.
    local sounds = MACHINE_SOUNDS[self.machineType] or MACHINE_SOUNDS.ArcadeMachine1
    if sounds.finish then
        self.character:getEmitter():playSound(sounds.finish)
        dbg("Playing finish sound: " .. sounds.finish)
    end
    sendClientCommand(self.character, "PlayArcadeMachines", "StopPlaying", {})
    ISBaseTimedAction.perform(self)
end

function PlayArcadeTimedAction:new(character, object, time, machineType, frontTile)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.object = object
    o.maxTime = time or 300
    o.machineType = machineType
    o.frontTile = frontTile
    o.gameSound = nil
    o.hasSaidMessage = false
    o.hasSaidPowerMessage = false
    return o
end

---------------------------------------------------------
-- Context menu
---------------------------------------------------------
local function startPlayAction(playerNum, obj, machineType, frontTile)
    local player = getSpecificPlayer(playerNum)
    if player and obj and machineType then
        ISTimedActionQueue.add(PlayArcadeTimedAction:new(player, obj, 3000, machineType, frontTile))
    end
end

local function addArcadePlayOption(playerNum, context, worldObjects, test)
    if test or #worldObjects == 0 then return end

    local firstObj = worldObjects[1]
    if not firstObj then return end
    local square = firstObj:getSquare()
    if not square then return end

    -- Unpowered machines simply don't offer a Play option, same as the
    -- user's own old mod did -- isValid() above is the defensive-depth
    -- backstop in case power drops while the action is already queued.
    local powered = isMachinePowered(square)
    if not powered then return end

    for i = 0, square:getObjects():size() - 1 do
        local obj = square:getObjects():get(i)
        if obj then
            local sprite = obj:getSprite()
            local spriteName = sprite and sprite:getName()
            if spriteName then
                local machineType = getArcadeMachineType(spriteName)
                if machineType then
                    local frontTile = getFrontTile(square, spriteName)
                    context:addOption(getText("ContextMenu_PlayArcade"), obj, function()
                        startPlayAction(playerNum, obj, machineType, frontTile)
                    end)
                end
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(addArcadePlayOption)
