-- Pack contents extraction module
-- Handles pack contents extraction during pack_opening phase

local IExtractor = assert(SMODS.load_file("state_extractor/extractors/i_extractor.lua"))()
local StateExtractorUtils = assert(SMODS.load_file("state_extractor/utils/state_extractor_utils.lua"))()
local CardUtils = assert(SMODS.load_file("state_extractor/utils/card_utils.lua"))()

local PackExtractor = {}
PackExtractor.__index = PackExtractor
setmetatable(PackExtractor, {__index = IExtractor})

function PackExtractor.new()
    local self = setmetatable({}, PackExtractor)
    return self
end

function PackExtractor:get_name()
    return "pack_extractor"
end

function PackExtractor:extract()
    local success, result = pcall(function()
        return self:extract_pack_contents()
    end)
    
    if success then
        return {pack_contents = result}
    else
        return {pack_contents = {}}
    end
end

function PackExtractor:extract_pack_contents()
    -- Extract pack contents with defensive programming
    local pack_contents = {}
    
    -- Check if we have pack cards available (during pack opening)
    if not StateExtractorUtils.safe_check_path(G, {"pack_cards", "cards"}) then
        return pack_contents
    end
    
    -- Extract cards from G.pack_cards.cards
    for i, card in ipairs(G.pack_cards.cards) do
        if card and card.ability then
            local card_data = self:extract_pack_card_data(card, i)
            if card_data then
                table.insert(pack_contents, card_data)
            end
        end
    end
    
    return pack_contents
end

function PackExtractor:extract_pack_card_data(card, index)
    -- Extract individual card data safely
    local card_data = {
        index = index - 1, -- 0-based indexing for consistency
        card_type = "unknown",
        name = "Unknown",
        cost = 0,
        properties = {}
    }
    
    -- Determine card type based on ability.set
    local ability_set = StateExtractorUtils.safe_primitive_nested_value(card, {"ability", "set"}, "")
    if ability_set and ability_set ~= "" then
        card_data.card_type = string.lower(ability_set)
    end
    
    -- Extract card name
    card_data.name = StateExtractorUtils.safe_primitive_nested_value(card, {"ability", "name"}, "Unknown")
    
    -- Extract cost if available
    card_data.cost = StateExtractorUtils.safe_primitive_value(card, "cost", 0)
    
    -- Extract additional card properties safely
    card_data.properties = self:extract_card_properties(card)
    
    return card_data
end

function PackExtractor:extract_card_properties(card)
    local properties = {}
    
    -- Extract key if available (for playing cards)
    local key = StateExtractorUtils.safe_primitive_nested_value(card, {"base", "id"}, nil)
    if key then
        properties.key = key
    end
    
    -- Extract suit and rank for playing cards
    local suit = StateExtractorUtils.safe_primitive_nested_value(card, {"base", "suit"}, nil)
    if suit then
        properties.suit = suit
    end
    
    local rank = StateExtractorUtils.safe_primitive_nested_value(card, {"base", "value"}, nil)
    if rank then
        properties.rank = rank
    end
    
    -- Extract enhancement if available
    local enhancement = StateExtractorUtils.safe_primitive_nested_value(card, {"config", "center", "key"}, nil)
    if enhancement then
        properties.enhancement = enhancement
    end
    
    -- Extract edition if available
    local edition = StateExtractorUtils.safe_primitive_nested_value(card, {"edition"}, nil)
    if edition then
        properties.edition = edition
    end
    
    -- Extract seal if available
    local seal = StateExtractorUtils.safe_primitive_nested_value(card, {"seal"}, nil)
    if seal then
        properties.seal = seal
    end
    
    return properties
end

return PackExtractor