-- Hand cards extraction module
-- Handles current hand cards extraction

local IExtractor = assert(SMODS.load_file("state_extractor/extractors/i_extractor.lua"))()
local StateExtractorUtils = assert(SMODS.load_file("state_extractor/utils/state_extractor_utils.lua"))()
local CardUtils = assert(SMODS.load_file("state_extractor/utils/card_utils.lua"))()

local HandCardExtractor = {}
HandCardExtractor.__index = HandCardExtractor
setmetatable(HandCardExtractor, {__index = IExtractor})

function HandCardExtractor.new()
    local self = setmetatable({}, HandCardExtractor)
    return self
end

function HandCardExtractor:get_name()
    return "hand_card_extractor"
end

function HandCardExtractor:extract()
    local success, result = pcall(function()
        return self:extract_hand_cards()
    end)
    
    if success then
        return {hand_cards = result}
    else
        return {hand_cards = {}}
    end
end

function HandCardExtractor:validate_card_areas()
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

function HandCardExtractor:validate_card_structure(card, card_name)
    if not card then
        return
    end
end

function HandCardExtractor:extract_hand_cards()
    -- Extract current hand cards with CIRCULAR REFERENCE SAFE access
    local hand_cards = {}
    
    if not StateExtractorUtils.safe_check_path(G, {"hand", "cards"}) then
        return hand_cards
    end
    
    for i, card in ipairs(G.hand.cards) do
        if card then
            -- SAFE EXTRACTION: Only extract primitive values, avoid object references
            local safe_card = {
                id = StateExtractorUtils.safe_primitive_value(card, "unique_val", "card_" .. i),
                rank = StateExtractorUtils.safe_primitive_nested_value(card, {"base", "value"}, "A"),
                suit = StateExtractorUtils.safe_primitive_nested_value(card, {"base", "suit"}, "Spades"),
                enhancement = CardUtils.get_card_enhancement_safe(card),
                edition = CardUtils.get_card_edition_safe(card),
                seal = CardUtils.get_card_seal_safe(card)
            }
            table.insert(hand_cards, safe_card)
        end
    end
    
    return hand_cards
end

return HandCardExtractor