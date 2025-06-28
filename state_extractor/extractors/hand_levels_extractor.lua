-- Hand levels extraction module
-- Handles poker hand levels, play counts, and chips/mult values extraction

local IExtractor = assert(SMODS.load_file("state_extractor/extractors/i_extractor.lua"))()
local StateExtractorUtils = assert(SMODS.load_file("state_extractor/utils/state_extractor_utils.lua"))()

local HandLevelsExtractor = {}
HandLevelsExtractor.__index = HandLevelsExtractor
setmetatable(HandLevelsExtractor, {__index = IExtractor})

-- Poker hand names in expected order
local HAND_NAMES = {
    "High Card",
    "Pair", 
    "Two Pair",
    "Three of a Kind",
    "Straight",
    "Flush",
    "Full House",
    "Four of a Kind",
    "Straight Flush",
    "Royal Flush"
}

-- Default hand values (base values at level 1)
local DEFAULT_HAND_VALUES = {
    ["High Card"] = {chips = 5, mult = 1},
    ["Pair"] = {chips = 10, mult = 2},
    ["Two Pair"] = {chips = 20, mult = 2},
    ["Three of a Kind"] = {chips = 30, mult = 3},
    ["Straight"] = {chips = 30, mult = 4},
    ["Flush"] = {chips = 35, mult = 4},
    ["Full House"] = {chips = 40, mult = 4},
    ["Four of a Kind"] = {chips = 60, mult = 7},
    ["Straight Flush"] = {chips = 100, mult = 8},
    ["Royal Flush"] = {chips = 100, mult = 8}
}

function HandLevelsExtractor.new()
    local self = setmetatable({}, HandLevelsExtractor)
    return self
end

function HandLevelsExtractor:get_name()
    return "hand_levels_extractor"
end

function HandLevelsExtractor:extract()
    local success, result = pcall(function()
        local hand_levels_data = self:get_hand_levels_data()
        return {hand_levels = hand_levels_data}
    end)
    
    if success then
        return result
    else
        -- Return default structure if extraction fails
        return {hand_levels = self:get_default_hand_levels()}
    end
end

function HandLevelsExtractor:get_hand_levels_data()
    -- Try to extract hand data from Balatro's game state
    local hands_data = StateExtractorUtils.safe_get_nested_value(G, {"GAME", "hands"}, nil)
    
    if not hands_data then
        -- Fallback: try alternative data structure locations
        hands_data = StateExtractorUtils.safe_get_nested_value(G, {"GAME", "hand_levels"}, nil)
    end
    
    if not hands_data then
        -- Fallback: try poker_hands location
        hands_data = StateExtractorUtils.safe_get_nested_value(G, {"GAME", "poker_hands"}, nil)
    end
    
    if hands_data then
        return self:process_hands_data(hands_data)
    else
        return self:get_default_hand_levels()
    end
end

function HandLevelsExtractor:process_hands_data(hands_data)
    local processed_hands = {}
    
    for _, hand_name in ipairs(HAND_NAMES) do
        local hand_info = hands_data[hand_name]
        
        if hand_info then
            -- Extract actual data from Balatro's structure
            local level = hand_info.level or 1
            local times_played = hand_info.played or hand_info.times_played or 0
            
            -- Calculate current chips and mult based on level
            local chips, mult = self:calculate_hand_values(hand_name, level)
            
            processed_hands[hand_name] = {
                level = level,
                times_played = times_played,
                chips = chips,
                mult = mult
            }
        else
            -- Use defaults if hand data not found
            processed_hands[hand_name] = self:get_default_hand_info(hand_name)
        end
    end
    
    return processed_hands
end

function HandLevelsExtractor:calculate_hand_values(hand_name, level)
    local default_values = DEFAULT_HAND_VALUES[hand_name]
    if not default_values then
        return 0, 0
    end
    
    -- Balatro hand leveling formula (approximate)
    -- Chips typically increase by base amount per level
    -- Mult typically increases by 1 per level after level 1
    local base_chips = default_values.chips
    local base_mult = default_values.mult
    
    local current_chips = base_chips + (base_chips * (level - 1))
    local current_mult = base_mult + (level - 1)
    
    return current_chips, current_mult
end

function HandLevelsExtractor:get_default_hand_info(hand_name)
    local default_values = DEFAULT_HAND_VALUES[hand_name]
    if default_values then
        return {
            level = 1,
            times_played = 0,
            chips = default_values.chips,
            mult = default_values.mult
        }
    else
        return {
            level = 1,
            times_played = 0,
            chips = 0,
            mult = 0
        }
    end
end

function HandLevelsExtractor:get_default_hand_levels()
    local default_hands = {}
    
    for _, hand_name in ipairs(HAND_NAMES) do
        default_hands[hand_name] = self:get_default_hand_info(hand_name)
    end
    
    return default_hands
end

return HandLevelsExtractor