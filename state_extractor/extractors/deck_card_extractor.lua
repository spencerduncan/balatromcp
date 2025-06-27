-- Deck cards extraction module
-- Handles deck cards extraction

local IExtractor = assert(SMODS.load_file("state_extractor/extractors/i_extractor.lua"))()
local StateExtractorUtils = assert(SMODS.load_file("state_extractor/utils/state_extractor_utils.lua"))()
local CardUtils = assert(SMODS.load_file("state_extractor/utils/card_utils.lua"))()

local DeckCardExtractor = {}
DeckCardExtractor.__index = DeckCardExtractor
setmetatable(DeckCardExtractor, {__index = IExtractor})

function DeckCardExtractor.new()
    local self = setmetatable({}, DeckCardExtractor)
    return self
end

function DeckCardExtractor:get_name()
    return "deck_card_extractor"
end

function DeckCardExtractor:extract()
    local success, result = pcall(function()
        return self:extract_deck_cards()
    end)
    
    if success then
        return {deck_cards = result}
    else
        return {deck_cards = {}}
    end
end

function DeckCardExtractor:validate_card_areas()
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

function DeckCardExtractor:validate_card_structure(card, card_name)
    if not card then
        return
    end
end

function DeckCardExtractor:extract_deck_cards()
    -- Extract deck cards from G.playing_cards - full deck data only
    local deck_cards = {}
    
    -- Extract from G.playing_cards (complete deck information)
    if not StateExtractorUtils.safe_check_path(G, {"playing_cards"}) then
        return deck_cards
    end
    
    for i, card in ipairs(G.playing_cards) do
        if card then
            -- SAFE EXTRACTION: Only extract primitive values, avoid object references
            local safe_card = {
                id = StateExtractorUtils.safe_primitive_value(card, "unique_val", "deck_card_" .. i),
                rank = StateExtractorUtils.safe_primitive_nested_value(card, {"base", "value"}, "A"),
                suit = StateExtractorUtils.safe_primitive_nested_value(card, {"base", "suit"}, "Spades"),
                enhancement = CardUtils.get_card_enhancement_safe(card),
                edition = CardUtils.get_card_edition_safe(card),
                seal = CardUtils.get_card_seal_safe(card)
            }
            table.insert(deck_cards, safe_card)
        end
    end
    
    return deck_cards
end

function DeckCardExtractor:extract_remaining_deck_cards()
    -- Extract remaining deck cards from G.deck.cards with CIRCULAR REFERENCE SAFE access
    local remaining_deck_cards = {}
    
    if not StateExtractorUtils.safe_check_path(G, {"deck", "cards"}) then
        return remaining_deck_cards
    end
    
    for i, card in ipairs(G.deck.cards) do
        if card then
            -- SAFE EXTRACTION: Only extract primitive values, avoid object references
            local safe_card = {
                id = StateExtractorUtils.safe_primitive_value(card, "unique_val", "remaining_deck_card_" .. i),
                rank = StateExtractorUtils.safe_primitive_nested_value(card, {"base", "value"}, "A"),
                suit = StateExtractorUtils.safe_primitive_nested_value(card, {"base", "suit"}, "Spades"),
                enhancement = CardUtils.get_card_enhancement_safe(card),
                edition = CardUtils.get_card_edition_safe(card),
                seal = CardUtils.get_card_seal_safe(card)
            }
            table.insert(remaining_deck_cards, safe_card)
        end
    end
    
    return remaining_deck_cards
end

return DeckCardExtractor