-- Card-specific utility functions for state extraction
-- Provides safe access methods for card properties and attributes

local StateExtractorUtils = assert(SMODS.load_file("state_extractor/utils/state_extractor_utils.lua"))()

local CardUtils = {}

-- SAFE card property extraction methods
function CardUtils.get_card_enhancement_safe(card)
    -- Determine card enhancement with CIRCULAR REFERENCE SAFE access
    if not card then
        return "none"
    end
    
    local ability_name = StateExtractorUtils.safe_primitive_nested_value(card, {"ability", "name"}, nil)
    if ability_name and type(ability_name) == "string" then
        local enhancement_map = {
            m_bonus = "bonus",
            m_mult = "mult",
            m_wild = "wild",
            m_glass = "glass",
            m_steel = "steel",
            m_stone = "stone",
            m_gold = "gold"
        }
        return enhancement_map[ability_name] or "none"
    end
    return "none"
end

function CardUtils.get_card_edition_safe(card)
    -- Determine card edition with CIRCULAR REFERENCE SAFE access
    if not card then
        return "none"
    end
    
    if card.edition and type(card.edition) == "table" then
        -- Check each edition type as primitive boolean
        if StateExtractorUtils.safe_primitive_value(card.edition, "foil", false) then
            return "foil"
        elseif StateExtractorUtils.safe_primitive_value(card.edition, "holo", false) then
            return "holographic"
        elseif StateExtractorUtils.safe_primitive_value(card.edition, "polychrome", false) then
            return "polychrome"
        elseif StateExtractorUtils.safe_primitive_value(card.edition, "negative", false) then
            return "negative"
        end
    end
    return "none"
end

function CardUtils.get_card_seal_safe(card)
    -- Determine card seal with CIRCULAR REFERENCE SAFE access
    if not card then
        return "none"
    end
    
    local seal = StateExtractorUtils.safe_primitive_value(card, "seal", "none")
    return seal
end

function CardUtils.extract_joker_properties_safe(joker)
    -- Extract joker-specific properties with CIRCULAR REFERENCE SAFE access
    local properties = {}
    
    if not joker then
        return properties
    end
    
    -- Only extract primitive values to avoid circular references
    properties.mult = StateExtractorUtils.safe_primitive_nested_value(joker, {"ability", "mult"}, 0)
    properties.chips = StateExtractorUtils.safe_primitive_nested_value(joker, {"ability", "t_chips"}, 0)
    
    -- AVOID extracting complex 'extra' object - too likely to have circular references
    
    return properties
end

function CardUtils.determine_blind_type_safe(blind)
    -- Determine the type of blind with CIRCULAR REFERENCE SAFE access
    if not blind then
        return "small"
    end
    
    -- Check if it's a boss blind (primitive boolean check)
    if StateExtractorUtils.safe_primitive_value(blind, "boss", false) then
        return "boss"
    end
    
    -- Check if it's a big blind by name (primitive string check)
    local blind_name = StateExtractorUtils.safe_primitive_value(blind, "name", "")
    if type(blind_name) == "string" and string.find(blind_name, "Big") then
        return "big"
    end
    
    return "small"
end

-- Legacy methods for backward compatibility
function CardUtils.get_card_enhancement(card)
    if not card then
        return "none"
    end
    
    local ability_name = StateExtractorUtils.safe_get_nested_value(card, {"ability", "name"}, nil)
    if ability_name then
        local enhancement_map = {
            m_bonus = "bonus",
            m_mult = "mult",
            m_wild = "wild",
            m_glass = "glass",
            m_steel = "steel",
            m_stone = "stone",
            m_gold = "gold"
        }
        return enhancement_map[ability_name] or "none"
    end
    return "none"
end

function CardUtils.get_card_edition(card)
    if not card then
        return "none"
    end
    
    if card.edition then
        if card.edition.foil then
            return "foil"
        elseif card.edition.holo then
            return "holographic"
        elseif card.edition.polychrome then
            return "polychrome"
        elseif card.edition.negative then
            return "negative"
        end
    end
    return "none"
end

function CardUtils.get_card_seal(card)
    if card.seal then
        return card.seal
    end
    return "none"
end

function CardUtils.extract_joker_properties(joker)
    local properties = {}
    
    if not joker then
        return properties
    end
    
    properties.extra = StateExtractorUtils.safe_get_nested_value(joker, {"ability", "extra"}, {})
    properties.mult = StateExtractorUtils.safe_get_nested_value(joker, {"ability", "mult"}, 0)
    properties.chips = StateExtractorUtils.safe_get_nested_value(joker, {"ability", "t_chips"}, 0)
    
    return properties
end

function CardUtils.determine_blind_type(blind)
    if not blind then
        return "small"
    end
    
    -- Check if it's a boss blind
    if StateExtractorUtils.safe_get_value(blind, "boss", false) then
        return "boss"
    end
    
    -- Check if it's a big blind by name
    local blind_name = StateExtractorUtils.safe_get_value(blind, "name", "")
    if type(blind_name) == "string" and string.find(blind_name, "Big") then
        return "big"
    end
    
    return "small"
end

return CardUtils