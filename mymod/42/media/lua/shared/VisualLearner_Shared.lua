require "registries"

VisualLearner = VisualLearner or {}

function VisualLearner.hasTrait(player)
    if not player then return false end
    if type(player) ~= "userdata" then return false end
    if not player.HasTrait then return false end
    return player:HasTrait(VisualLearnerRegistries.TraitID)
end

-- Safely apply level gain with cap 10
function VisualLearner.gainLevels(player, perk, levelsToGain)
    if not player or not perk or levelsToGain <= 0 then return end

    local xp = player:getXp()
    if not xp then return end
    
    local currentLevel = player:getPerkLevel(perk)
    local targetLevel = math.min(currentLevel + levelsToGain, 10)

    if targetLevel <= currentLevel then return end

    xp:setXPToLevel(perk, targetLevel)
end

-- Get reading progress of a book: 0.0–1.0
function VisualLearner.getBookProgress(book)
    if not book then return 0 end

    local totalPages = (book.getNumberOfPages and book:getNumberOfPages()) or 0
    local readPages  = (book.getAlreadyReadPages and book:getAlreadyReadPages()) or 0

    if totalPages <= 0 then return 0 end
    return math.min(readPages / totalPages, 1.0)
end

-- Get a unique ID for the book instance
function VisualLearner.getBookId(book)
    if not book then return nil end
    if book.getID then
        return tostring(book:getID())
    end
    return tostring(book:getFullType()) .. ":" .. tostring(book:getAge()) .. ":" .. tostring(book:getCondition())
end