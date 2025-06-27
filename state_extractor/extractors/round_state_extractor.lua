-- Round state extraction module
-- Handles hands and discards remaining

local IExtractor = assert(SMODS.load_file("state_extractor/extractors/i_extractor.lua"))()
local StateExtractorUtils = assert(SMODS.load_file("state_extractor/utils/state_extractor_utils.lua"))()

local RoundStateExtractor = {}
RoundStateExtractor.__index = RoundStateExtractor
setmetatable(RoundStateExtractor, {__index = IExtractor})

function RoundStateExtractor.new()
    local self = setmetatable({}, RoundStateExtractor)
    return self
end

function RoundStateExtractor:get_name()
    return "round_state_extractor"
end

function RoundStateExtractor:extract()
    local success, result = pcall(function()
        local hands_remaining = self:get_hands_remaining()
        local discards_remaining = self:get_discards_remaining()
        return {hands_remaining = hands_remaining, discards_remaining = discards_remaining}
    end)
    
    if success then
        return result
    else
        return {hands_remaining = 0, discards_remaining = 0}
    end
end

function RoundStateExtractor:get_hands_remaining()
    if G and G.GAME and G.GAME.current_round and type(G.GAME.current_round.hands_left) == "number" then
        return G.GAME.current_round.hands_left
    end
    return 0
end

function RoundStateExtractor:get_discards_remaining()
    if G and G.GAME and G.GAME.current_round and type(G.GAME.current_round.discards_left) == "number" then
        return G.GAME.current_round.discards_left
    end
    return 0
end

return RoundStateExtractor