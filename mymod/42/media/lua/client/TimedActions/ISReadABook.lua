require "TimedActions/ISBaseTimedAction"

ISReadABook = ISBaseTimedAction:derive("ISReadABook")

-------------------------------------------------
-- Helper: check if this reader has Visual Learner
-------------------------------------------------
local function VL_HasVisualLearner(self)
    local ch = self.character
    return ch and ch.HasTrait and ch:HasTrait("visuallearner:visuallearner")
end

-------------------------------------------------
-- Vanilla multiplier logic (for non-trait readers)
-------------------------------------------------
ISReadABook.checkMultiplier = function(self)
    local trainedStuff = SkillBook[self.item:getSkillTrained()]
    if trainedStuff then
        local readPercent = (self.item:getAlreadyReadPages() / self.item:getNumberOfPages()) * 100
        if readPercent > 100 then
            readPercent = 100
        end
        local multiplier = (math.floor(readPercent / 10) * (self.maxMultiplier / 10))
        if multiplier > self.character:getXp():getMultiplier(trainedStuff.perk) then
            addXpMultiplier(self.character, trainedStuff.perk, multiplier,
                self.item:getLvlSkillTrained(), self.item:getMaxLevelTrained())
        end
    end
end

-------------------------------------------------
-- Level gain helper for half/full bonuses
-------------------------------------------------
local function VL_GainLevels(player, perk, levelsToGain)
    if not player or not perk or levelsToGain <= 0 then return end
    local xp = player:getXp()
    if not xp then return end

    local currentLevel = player:getPerkLevel(perk)
    local targetLevel = math.min(currentLevel + levelsToGain, 10)
    if targetLevel <= currentLevel then return end

    xp:setXPToLevel(perk, targetLevel)
end

local function VL_GetBookProgress(item)
    if not item then return 0 end
    local totalPages = item:getNumberOfPages() or 0
    local readPages  = item:getAlreadyReadPages() or 0
    if totalPages <= 0 then return 0 end
    return math.min(readPages / totalPages, 1.0)
end

-------------------------------------------------
-- ISReadABook core
-------------------------------------------------

function ISReadABook:isValid()
    if self.character:tooDarkToRead() then
        HaloTextHelper.addBadText(self.character, getText("ContextMenu_TooDark"))
        return false
    end
    local vehicle = self.character:getVehicle()
    if vehicle and vehicle:isDriver(self.character) then
        return not vehicle:isEngineRunning() or vehicle:getSpeed2D() == 0
    end
    if isClient() and self.item then
        return self.character:getInventory():containsID(self.item:getID())
            and ((self.item:getNumberOfPages() > 0
                and self.item:getAlreadyReadPages() <= self.item:getNumberOfPages())
                or self.item:getNumberOfPages() < 0)
    else
        return self.character:getInventory():contains(self.item)
            and ((self.item:getNumberOfPages() > 0
                and self.item:getAlreadyReadPages() <= self.item:getNumberOfPages())
                or self.item:getNumberOfPages() < 0)
    end
end

function ISReadABook:isUsingTimeout()
    return false
end

function ISReadABook:update()
    self.pageTimer = self.pageTimer + getGameTime():getMultiplier()
    self.item:setJobDelta(self:getJobDelta())

    if not isClient() then
        if self.item:getNumberOfPages() > 0 then
            local pagesRead = math.floor(self.item:getNumberOfPages() * self:getJobDelta())
            self.item:setAlreadyReadPages(pagesRead)
            if self.item:getAlreadyReadPages() > self.item:getNumberOfPages() then
                self.item:setAlreadyReadPages(self.item:getNumberOfPages())
            end
            self.character:setAlreadyReadPages(self.item:getFullType(), self.item:getAlreadyReadPages())
        end
    end

    if self.item:hasModData() and self.item:getModData().printMedia then
        return
    end

    if SkillBook[self.item:getSkillTrained()] then
        local skillBook = SkillBook[self.item:getSkillTrained()]
        local perk = skillBook.perk

        if self.item:getLvlSkillTrained() > self.character:getPerkLevel(perk) + 1
            or self.character:hasTrait(CharacterTrait.ILLITERATE) then

            if self.pageTimer >= 200 then
                self.pageTimer = 0
                local txtRandom = ZombRand(3)
                if txtRandom == 0 then
                    HaloTextHelper.addBadText(self.character, getText("IGUI_PlayerText_DontGet"))
                elseif txtRandom == 1 then
                    HaloTextHelper.addBadText(self.character, getText("IGUI_PlayerText_TooComplicated"))
                else
                    HaloTextHelper.addBadText(self.character, getText("IGUI_PlayerText_DontUnderstand"))
                end
                if self.item:getNumberOfPages() > 0 then
                    self.character:setAlreadyReadPages(self.item:getFullType(), 0)
                    self:forceStop()
                end
            end

        elseif self.item:getMaxLevelTrained() < self.character:getPerkLevel(perk) + 1 then
            if self.pageTimer >= 200 then
                self.pageTimer = 0
                local txtRandom = ZombRand(2)
                if txtRandom == 0 then
                    HaloTextHelper.addGoodText(self.character, getText("IGUI_PlayerText_KnowSkill"))
                else
                    HaloTextHelper.addGoodText(self.character, getText("IGUI_PlayerText_BookObsolete"))
                end
            end

        else
            -- HERE: trait-specific vs vanilla behavior
            if not isClient() then
                if VL_HasVisualLearner(self) then
                    -- XP-per-page logic (like the mod you posted)
                    local currentPages = self.item:getAlreadyReadPages()
                    if not self.lastXPPage then
                        self.lastXPPage = currentPages or 0
                    end

                    local level = self.character:getPerkLevel(perk)
                    if currentPages and self.lastXPPage then
                        if currentPages > self.lastXPPage then
                            local pagesDiff = currentPages - self.lastXPPage
                            local XPPerPage = 0

                            if level == 0 or level == 1 then
                                XPPerPage = 4.2
                            elseif level == 2 or level == 3 then
                                XPPerPage = 16.2
                            elseif level == 4 or level == 5 then
                                XPPerPage = 60.1
                            elseif level == 6 or level == 7 then
                                XPPerPage = 123.7
                            elseif level == 8 or level == 9 then
                                XPPerPage = 173.9
                            end

                            self.character:getXp():AddXP(perk, XPPerPage * pagesDiff)
                            self.lastXPPage = currentPages
                            self.character:setAlreadyReadPages(self.item:getFullType(), currentPages)
                        end
                    elseif not self.lastXPPage then
                        self.lastXPPage = currentPages or 0
                    end

                    -- Half/full bonuses for Visual Learner
                    local progress = VL_GetBookProgress(self.item)
                    self.VL_halfGranted = self.VL_halfGranted or false
                    self.VL_totalGranted = self.VL_totalGranted or 0

                    if (not self.VL_halfGranted) and progress >= 0.5 then
                        VL_GainLevels(self.character, perk, 1)
                        self.VL_halfGranted = true
                        self.VL_totalGranted = (self.VL_totalGranted or 0) + 1
                    end

                    if progress >= 1.0 then
                        local remaining = 2 - (self.VL_totalGranted or 0)
                        if remaining > 0 then
                            VL_GainLevels(self.character, perk, remaining)
                            self.VL_totalGranted = (self.VL_totalGranted or 0) + remaining
                        end
                    end
                else
                    -- Non-trait: vanilla multiplier behavior
                    ISReadABook.checkMultiplier(self)
                end
            end
        end
    end

    local stats = self.character:getStats()
    if self.stats and (self.item:getUnhappyChange() < 0.0) then
        if stats:get(CharacterStat.UNHAPPINESS) > self.stats.unhappiness then
            stats:set(CharacterStat.UNHAPPINESS, self.stats.unhappiness)
        end
    end
end

function ISReadABook.checkLevel(character, item)
    if item:getNumberOfPages() <= 0 then
        return
    end
    local skillBook = SkillBook[item:getSkillTrained()]
    if not skillBook then
        return
    end
    local level = character:getPerkLevel(skillBook.perk)
    if (item:getLvlSkillTrained() > level + 1) or character:hasTrait(CharacterTrait.ILLITERATE) then
        item:setAlreadyReadPages(0)
        character:setAlreadyReadPages(item:getFullType(), 0)
    end
end

function ISReadABook:start()
    if isClient() and self.item then
        self.item = self.character:getInventory():getItemById(self.item:getID())
    end

    self.lastXPPage = self.item:getAlreadyReadPages() or 0
    self.VL_halfGranted = false
    self.VL_totalGranted = 0

    if self.startPage then
        self:setCurrentTime(self.maxTime * (self.startPage / self.item:getNumberOfPages()))
    end

    self.item:setJobType(getText("ContextMenu_Read") .. ' ' .. self.item:getName())
    self.item:setJobDelta(0.0)

    if self.item:getReadType() then
        self:setAnimVariable("ReadType", self.item:getReadType())
    elseif (self.item:getType() == "Newspaper" or self.item:hasTag(ItemTag.NEWSPAPER_READ)) then
        self:setAnimVariable("ReadType", "newspaper")
    elseif (self.item:hasTag(ItemTag.PICTURE)) then
        self:setAnimVariable("ReadType", "photo")
    else
        self:setAnimVariable("ReadType", "book")
    end

    self:setActionAnim(CharacterActionAnims.Read)
    self:setOverrideHandModels(nil, self.item)
    self.character:setReading(true)

    self.character:reportEvent("EventRead")

    if not SkillBook[self.item:getSkillTrained()] then
        self.stats = {}
        self.stats.boredom = self.character:getStats():get(CharacterStat.BOREDOM)
        self.stats.unhappiness = self.character:getStats():get(CharacterStat.UNHAPPINESS)
        self.stats.stress = self.character:getStats():get(CharacterStat.STRESS)
    end

    if self:isBook(self.item) then
        self.character:playSound("OpenBook")
    else
        self.character:playSound("OpenMagazine")
    end

    if self.item:hasModData() and self.item:getModData().printMedia then
        self:startLoadingPrintMediaTextures()
    end
end

function ISReadABook:stop()
    if self.item:getNumberOfPages() > 0 and self.item:getAlreadyReadPages() >= self.item:getNumberOfPages() then
        self.item:setAlreadyReadPages(self.item:getNumberOfPages())
    end
    self.character:setReading(false)
    self.item:setJobDelta(0.0)
    if self:isBook(self.item) then
        self.character:playSound("CloseBook")
    else
        self.character:playSound("CloseMagazine")
    end
    syncItemFields(self.character, self.item)
    ISBaseTimedAction.stop(self)
end

function ISReadABook:perform()
    self.character:setReading(false)
    self.item:getContainer():setDrawDirty(true)
    self.item:setJobDelta(0.0)
    if self:isBook(self.item) then
        self.character:playSound("CloseBook")
    else
        self.character:playSound("CloseMagazine")
    end

    self.isLiteratureRead = nil
    if self.item:hasModData() and self.item:getModData().literatureTitle then
        self.isLiteratureRead = self.character:isLiteratureRead(self.item:getModData().literatureTitle)
        self.character:addReadLiterature(self.item:getModData().literatureTitle)
    end

    if self.item:hasModData() and self.item:getModData().printMedia then
        self:displayPrintMedia()
    end

    ISBaseTimedAction.perform(self)
end

-- The rest (print media, animEvent, serverStart, getDuration, new)
-- can be copied directly from the working mod you posted,
-- since they don't affect XP logic beyond what we've already customized.

-- (You can paste those unchanged below this point.)
-- See init() in PrintMedia.lua
function ISReadABook:startLoadingPrintMediaTextures()
    local mediaID = self.item:getModData().printMedia
    local text = getTextOrNull(mediaID.info)
    if not text then return end
    local elements = string.split(text, "<")
    for i, val in ipairs(elements) do
        if val ~= "" then
            local data = string.split(val, ">")
            local params = {}
            local paramsData = string.split(data[1], ",")
            local incorrectElement = nil
            for _,v in ipairs(paramsData) do
                local temp = string.split(v, ":")
                if temp[1] == nil or temp[2] == nil then
                    incorrectElement = v
                else
                    params[string.trim(temp[1])] = string.trim(temp[2])
                end
            end
            if incorrectElement then
                print("RICH TEXT ERROR: Incorrect string: " .. incorrectElement)
                break
            end
            if params["type"] == "texture" then
                for key,value in pairs(params) do
                    if key == "texture" then
                        loadstring("return " .. value)()
                    end
                end
            end
        end
    end
end

function ISReadABook:displayPrintMedia()
    local val = self.item:getModData().printMedia
    local win = PZAPI.UI.PrintMedia{
        x = 730, y = 100,
    }
    win.media_id = val.id
    win.data = getText(val.info)
    win.children.bar.children.name.text = getText(val.title)
    win.textTitle = getText(val.title)
    win.textData = string.gsub(getText(val.text), "\\n", "\n")
    win:instantiate()
    win.javaObj:setAlwaysOnTop(false)
    win:centerOnScreen(self.playerNum)

    if getCore():getOptionAutoRevealPrintMediaMapLocations() then
        self:revealPrintMediaLocationsOnMap(win.media_id)
    end

    if getJoypadData(self.playerNum) then
        ISAtomUIJoypad.Apply(win)
        win.close = function(self)
            UIManager.RemoveElement(self.javaObj)
            if getJoypadData(self.playerNum) then
                setJoypadFocus(self.playerNum, self.prevFocus)
            end
        end
        win.children.bar.children.closeButton.onLeftClick = function(_self)
            getSoundManager():playUISound(_self.sounds.activate)
            _self.parent.parent:close()
        end
        win.playerNum = self.playerNum
        win.prevFocus = getJoypadData(self.playerNum).focus
        win.onJoypadDown = function(self, button, joypadData)
            if button == Joypad.BButton then
                self.children.bar.children.closeButton:onLeftClick()
            end
            if button == Joypad.XButton then
                self:onClickNewspaperButton()
            end
            if button == Joypad.YButton then
                self:onClickMapButton()
            end
        end
        setJoypadFocus(self.playerNum, win)
    end
end

function ISReadABook:revealPrintMediaLocationsOnMap(mediaID)
    if not PrintMediaDefinitions then
        return
    end
    local miscDetails = PrintMediaDefinitions.MiscDetails[mediaID]
    if not miscDetails then
        return
    end
    for i = 1, 5 do
        local locationData = miscDetails["location" .. i]
        if locationData == nil then
            break
        end
        for _, sqData in ipairs(locationData) do
            WorldMapVisited.getInstance():setKnownInSquares(sqData.x1, sqData.y1, sqData.x2, sqData.y2)
        end
    end
end

function ISReadABook:complete()
    self.item:setJobDelta(0.0)

    if self.item:getLearnedRecipes() and not self.item:getLearnedRecipes():isEmpty() then
        self.character:getAlreadyReadBook():add(self.item:getFullType())
        if self.item:getLearnedRecipes():contains("Herbalist") and not self.character:hasTrait(CharacterTrait.HERBALIST) then
            self.character:hasTrait(CharacterTrait.HERBALIST)
        end
    end

    if not SkillBook[self.item:getSkillTrained()] and not self.isLiteratureRead then
        self.character:ReadLiterature(self.item)

        local args = { itemId=self.item:getID() }
        sendServerCommand(self.character, 'literature', 'readLiterature', args)

    elseif self.item:getAlreadyReadPages() >= self.item:getNumberOfPages() then
        self.item:setAlreadyReadPages(0)
    end

    if self.item:hasModData() and self.item:getModData().learnedRecipe ~= nil then
        self.character:learnRecipe(self.item:getModData().learnedRecipe)
    end

    if self.item:hasModData() and self.item:getModData().literatureTitle then
        self.character:addReadLiterature(self.item:getModData().literatureTitle)
    end

    if self.item:hasModData() and self.item:getModData().printMedia then
        self.character:addReadPrintMedia(self.item:getModData().printMedia.id)
    end

    self.item:setAlreadyReadPages(self.item:getNumberOfPages())

    sendSyncPlayerFields(self.character, 0x00000007)
    syncItemFields(self.character, self.item)

    return true
end

function ISReadABook:animEvent(event, parameter)
    if event == "PageFlip" then
        if getGameSpeed() ~= 1 then
            return
        end
        if self:isBook(self.item) then
            self.character:playSound("PageFlipBook")
        else
            self.character:playSound("PageFlipMagazine")
        end
    end

    if event == "ReadAPage" then
        if isServer() then
            if SkillBook[self.item:getSkillTrained()] then
                if self.item:getLvlSkillTrained() > self.character:getPerkLevel(SkillBook[self.item:getSkillTrained()].perk) + 1
                    or self.character:hasTrait(CharacterTrait.ILLITERATE) then

                    if self.item:getNumberOfPages() > 0 then
                        self.character:setAlreadyReadPages(self.item:getFullType(), 0)
                        self.item:setAlreadyReadPages(0)
                        syncItemFields(self.character, self.item)
                        self.netAction:forceComplete()
                    end

                elseif self.item:getMaxLevelTrained() >= self.character:getPerkLevel(SkillBook[self.item:getSkillTrained()].perk) + 1 then
                    local skillBook = SkillBook[self.item:getSkillTrained()].perk
                    local level = self.character:getPerkLevel(skillBook)
                    local currentPages = self.item:getAlreadyReadPages()

                    if not self.lastXPPage then
                        self.lastXPPage = self.item:getAlreadyReadPages() or 0
                    end

                    if skillBook and currentPages and self.lastXPPage then
                        if currentPages > self.lastXPPage then
                            local pagesDiff = currentPages - self.lastXPPage
                            local XPPerPage = 0

                            if level == 0 or level == 1 then
                                XPPerPage = 4.2
                            elseif level == 2 or level == 3 then
                                XPPerPage = 16.2
                            elseif level == 4 or level == 5 then
                                XPPerPage = 60.1
                            elseif level == 6 or level == 7 then
                                XPPerPage = 123.7
                            elseif level == 8 or level == 9 then
                                XPPerPage = 173.9
                            end

                            self.character:getXp():AddXP(skillBook, XPPerPage * pagesDiff)
                            self.lastXPPage = currentPages
                            sendSyncPlayerFields(self.character, 0x00000001)
                        end
                    elseif not self.lastXPPage then
                        self.lastXPPage = currentPages or 0
                    end
                end
            end

            if self.item:getNumberOfPages() > 0 and self.startPage then
                local pagesRead = math.floor(self.item:getNumberOfPages() * self.netAction:getProgress()) + self.startPage
                self.item:setAlreadyReadPages(pagesRead)

                if self.item:getAlreadyReadPages() > self.item:getNumberOfPages() then
                    self.item:setAlreadyReadPages(self.item:getNumberOfPages())
                    self.netAction:forceComplete()
                end

                self.character:setAlreadyReadPages(self.item:getFullType(), self.item:getAlreadyReadPages())
                syncItemFields(self.character, self.item)
            end
        end
    end
end

function ISReadABook:isBook(item)
    if not item then return false end
    return string.match(item:getType(), "Book")
end

function ISReadABook:serverStart()
    local numPages = 5
    if self.item:getNumberOfPages() > 0 then
        numPages = self.item:getNumberOfPages()
    end
    emulateAnimEvent(self.netAction, self.maxTime * 8.0 / numPages, "ReadAPage", nil)
end

function ISReadABook:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end

    local numPages
    if self.item:getNumberOfPages() > 0 then
        ISReadABook.checkLevel(self.character, self.item)
        self.item:setAlreadyReadPages(self.character:getAlreadyReadPages(self.item:getFullType()))
        self.startPage = self.item:getAlreadyReadPages()
        numPages = self.item:getNumberOfPages() - self.item:getAlreadyReadPages()
    else
        numPages = 5
    end

    local f = 1 / getGameTime():getMinutesPerDay() / 2
    local time = numPages * self.minutesPerPage / f
    if self.item:hasTag(ItemTag.FAST_READ) then
        time = 50
    end
    if self.character:hasTrait(CharacterTrait.FAST_READER) then
        time = time * 0.7
    end
    if self.character:hasTrait(CharacterTrait.SLOW_READER) then
        time = time * 1.3
    end

    local eyeItem = self.character:getWornItems():getItem(ItemBodyLocation.EYES)
    if eyeItem and eyeItem:getType() == "Glasses_Reading" then
        time = time * 0.9
    end

    return time
end

function ISReadABook:new(character, item)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.playerNum = character:getPlayerNum()
    o.item = item

    o.minutesPerPage = getSandboxOptions():getOptionByName("MinutesPerPage"):getValue() or 2.0
    if o.minutesPerPage < 0.0 then o.minutesPerPage = 2.0 end

    if SkillBook[item:getSkillTrained()] then
        if item:getLvlSkillTrained() == 1 then
            o.maxMultiplier = SkillBook[item:getSkillTrained()].maxMultiplier1
        elseif item:getLvlSkillTrained() == 3 then
            o.maxMultiplier = SkillBook[item:getSkillTrained()].maxMultiplier2
        elseif item:getLvlSkillTrained() == 5 then
            o.maxMultiplier = SkillBook[item:getSkillTrained()].maxMultiplier3
        elseif item:getLvlSkillTrained() == 7 then
            o.maxMultiplier = SkillBook[item:getSkillTrained()].maxMultiplier4
        elseif item:getLvlSkillTrained() == 9 then
            o.maxMultiplier = SkillBook[item:getSkillTrained()].maxMultiplier5
        else
            o.maxMultiplier = 1
            print('ERROR: book has unhandled skill level ' .. item:getLvlSkillTrained())
        end
    end

    o.ignoreHandsWounds = true
    o.maxTime = o:getDuration()
    o.caloriesModifier = 0.5
    o.pageTimer = 0
    o.forceProgressBar = true

    return o
end