-- Game state extraction module
-- Handles ante and money extraction

local IExtractor = assert(SMODS.load_file("state_extractor/extractors/i_extractor.lua"))()
local StateExtractorUtils = assert(SMODS.load_file("state_extractor/utils/state_extractor_utils.lua"))()

local GameStateExtractor = {}
GameStateExtractor.__index = GameStateExtractor
setmetatable(GameStateExtractor, {__index = IExtractor})

function GameStateExtractor.new()
    local self = setmetatable({}, GameStateExtractor)
    return self
end

function GameStateExtractor:get_name()
    return "game_state_extractor"
end

function GameStateExtractor:extract()
    local success, result = pcall(function()
        local ante = self:get_ante()
        local money = self:get_money()
        return {ante = ante, money = money}
    end)
    
    if success then
        return result
    else
        return {ante = 1, money = 0}
    end
end

function GameStateExtractor:get_ante()
    local ante = StateExtractorUtils.safe_get_nested_value(G, {"GAME", "round_resets", "ante"}, 1)
    return ante
end

function GameStateExtractor:get_money()
    local money = StateExtractorUtils.safe_get_nested_value(G, {"GAME", "dollars"}, 0)
    return money
end

return GameStateExtractor