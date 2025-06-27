-- Joker cards extraction module
-- Handles joker cards extraction

local IExtractor = assert(SMODS.load_file("state_extractor/extractors/i_extractor.lua"))()
local StateExtractorUtils = assert(SMODS.load_file("state_extractor/utils/state_extractor_utils.lua"))()
local CardUtils = assert(SMODS.load_file("state_extractor/utils/card_utils.lua"))()

local JokerExtractor = {}
JokerExtractor.__index = JokerExtractor
setmetatable(JokerExtractor, {__index = IExtractor})

function JokerExtractor.new()
    local self = setmetatable({}, JokerExtractor)
    return self
end

function JokerExtractor:get_name()
    return "joker_extractor"
end

function JokerExtractor:extract()
    local success, result = pcall(function()
        return self:extract_jokers()
    end)
    
    if success then
        return {jokers = result}
    else
        return {jokers = {}}
    end
end

function JokerExtractor:validate_card_areas()
    local areas = {
        {name = "hand", object = G.hand},
        {name = "jokers", object = G.jokers},
        {name = "consumeables", object = G.consumeables},
        {name = "shop_jokers", object = G.shop_jokers}
    }
    
    for _, area in ipairs(areas) do
        if area.object and area.object.cards and #area.object.cards > 0 then
            self:validate_card_structure(area.object.cards[1], area.name .. "[1]")
        end
    end
end

function JokerExtractor:validate_card_structure(card, card_name)
    if not card then
        return
    end
end

function JokerExtractor:extract_jokers()
    -- Extract current jokers with CIRCULAR REFERENCE SAFE access
    local jokers = {}
    
    if not StateExtractorUtils.safe_check_path(G, {"jokers", "cards"}) then
        return jokers
    end
    
    for i, joker in ipairs(G.jokers.cards) do
        if joker then
            local safe_joker = {
                id = StateExtractorUtils.safe_primitive_value(joker, "unique_val", "joker_" .. i),
                name = StateExtractorUtils.safe_primitive_nested_value(joker, {"ability", "name"}, "Unknown"),
                position = i - 1, -- 0-based indexing
                properties = CardUtils.extract_joker_properties_safe(joker)
            }
            table.insert(jokers, safe_joker)
        end
    end
    
    return jokers
end

return JokerExtractor