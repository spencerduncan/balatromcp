-- Main StateExtractor orchestrator class
-- Manages collection of specialized extractors and provides unified interface

local StateExtractorUtils = require("state_extractor.utils.state_extractor_utils")
local CardUtils = require("state_extractor.utils.card_utils")

-- Import all specialized extractors
local SessionExtractor = require("state_extractor.extractors.session_extractor")
local PhaseExtractor = require("state_extractor.extractors.phase_extractor")
local GameStateExtractor = require("state_extractor.extractors.game_state_extractor")
local RoundStateExtractor = require("state_extractor.extractors.round_state_extractor")
local HandCardExtractor = require("state_extractor.extractors.hand_card_extractor")
local JokerExtractor = require("state_extractor.extractors.joker_extractor")
local ConsumableExtractor = require("state_extractor.extractors.consumable_extractor")
local DeckCardExtractor = require("state_extractor.extractors.deck_card_extractor")
local BlindExtractor = require("state_extractor.extractors.blind_extractor")
local ShopExtractor = require("state_extractor.extractors.shop_extractor")
local ActionExtractor = require("state_extractor.extractors.action_extractor")
local JokerReorderExtractor = require("state_extractor.extractors.joker_reorder_extractor")

local StateExtractor = {}
StateExtractor.__index = StateExtractor

function StateExtractor.new()
    local self = setmetatable({}, StateExtractor)
    self.component_name = "STATE_EXTRACTOR"
    self.extractors = {}
    
    -- Initialize and register all extractors in correct order
    self:register_extractor(SessionExtractor.new())
    self:register_extractor(PhaseExtractor.new())
    self:register_extractor(GameStateExtractor.new())
    self:register_extractor(RoundStateExtractor.new())
    self:register_extractor(HandCardExtractor.new())
    self:register_extractor(JokerExtractor.new())
    self:register_extractor(ConsumableExtractor.new())
    self:register_extractor(DeckCardExtractor.new())
    self:register_extractor(BlindExtractor.new())
    self:register_extractor(ShopExtractor.new())
    self:register_extractor(ActionExtractor.new())
    self:register_extractor(JokerReorderExtractor.new())
    
    -- Initialize session_id for backward compatibility
    self.session_id = nil
    
    -- Immediately test G object availability and structure
    self:validate_g_object()
    
    return self
end

function StateExtractor:register_extractor(extractor)
    -- Import IExtractor for validation
    local IExtractor = require("state_extractor.extractors.i_extractor")
    
    -- Validate extractor implements required interface
    if IExtractor.validate_implementation(extractor) then
        table.insert(self.extractors, extractor)
    else
        error("Extractor must implement IExtractor interface (extract() and get_name() methods required)")
    end
end

function StateExtractor:extract_current_state()
    local state = {}
    local extraction_errors = {}
    
    -- Extract from each registered extractor with error handling
    for _, extractor in ipairs(self.extractors) do
        local success, result = pcall(function()
            return extractor:extract()
        end)
        
        if success and result then
            -- Merge extractor results into flat state dictionary
            self:merge_extraction_results(state, result)
        else
            local extractor_name = extractor:get_name() or "unknown_extractor"
            table.insert(extraction_errors, extractor_name .. ": " .. tostring(result))
        end
    end
    
    -- Handle extraction errors
    if #extraction_errors > 0 then
        state.extraction_errors = extraction_errors
    end
    
    return state
end

function StateExtractor:merge_extraction_results(state, extractor_result)
    -- Merge extractor results into the main state dictionary
    if type(extractor_result) == "table" then
        for key, value in pairs(extractor_result) do
            state[key] = value
        end
    end
end


-- Backward compatibility methods - delegate to appropriate extractors
function StateExtractor:get_session_id()
    -- Maintain session_id for backward compatibility
    if not self.session_id then
        self.session_id = "session_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
    end
    return self.session_id
end

function StateExtractor:get_current_phase()
    -- Delegate to PhaseExtractor for backward compatibility
    for _, extractor in ipairs(self.extractors) do
        if extractor:get_name() == "phase_extractor" then
            return extractor:get_current_phase()
        end
    end
    return "hand_selection" -- Safe default if PhaseExtractor not found
end

function StateExtractor:get_ante()
    -- Delegate to GameStateExtractor for backward compatibility
    for _, extractor in ipairs(self.extractors) do
        if extractor:get_name() == "game_state_extractor" then
            return extractor:get_ante()
        end
    end
    return 1 -- Safe default if GameStateExtractor not found
end

function StateExtractor:get_money()
    -- Delegate to GameStateExtractor for backward compatibility
    for _, extractor in ipairs(self.extractors) do
        if extractor:get_name() == "game_state_extractor" then
            return extractor:get_money()
        end
    end
    return 0 -- Safe default if GameStateExtractor not found
end

function StateExtractor:get_hands_remaining()
    -- Delegate to RoundStateExtractor for backward compatibility
    for _, extractor in ipairs(self.extractors) do
        if extractor:get_name() == "round_state_extractor" then
            return extractor:get_hands_remaining()
        end
    end
    return 0 -- Safe default if RoundStateExtractor not found
end

function StateExtractor:get_discards_remaining()
    -- Delegate to RoundStateExtractor for backward compatibility
    for _, extractor in ipairs(self.extractors) do
        if extractor:get_name() == "round_state_extractor" then
            return extractor:get_discards_remaining()
        end
    end
    return 0 -- Safe default if RoundStateExtractor not found
end

function StateExtractor:extract_hand_cards()
    -- Delegate to HandCardExtractor for backward compatibility
    for _, extractor in ipairs(self.extractors) do
        if extractor:get_name() == "hand_card_extractor" then
            return extractor:extract_hand_cards()
        end
    end
    return {} -- Safe default if HandCardExtractor not found
end

function StateExtractor:extract_deck_cards()
    -- Delegate to DeckCardExtractor for backward compatibility
    for _, extractor in ipairs(self.extractors) do
        if extractor:get_name() == "deck_card_extractor" then
            return extractor:extract_deck_cards()
        end
    end
    return {} -- Safe default if DeckCardExtractor not found
end

function StateExtractor:extract_remaining_deck_cards()
    -- Delegate to DeckCardExtractor for backward compatibility
    for _, extractor in ipairs(self.extractors) do
        if extractor:get_name() == "deck_card_extractor" then
            return extractor:extract_remaining_deck_cards()
        end
    end
    return {} -- Safe default if DeckCardExtractor not found
end

function StateExtractor:extract_jokers()
    -- Delegate to JokerExtractor for backward compatibility
    for _, extractor in ipairs(self.extractors) do
        if extractor:get_name() == "joker_extractor" then
            return extractor:extract_jokers()
        end
    end
    return {} -- Safe default if JokerExtractor not found
end

function StateExtractor:extract_consumables()
    -- Delegate to ConsumableExtractor for backward compatibility
    for _, extractor in ipairs(self.extractors) do
        if extractor:get_name() == "consumable_extractor" then
            return extractor:extract_consumables()
        end
    end
    return {} -- Safe default if ConsumableExtractor not found
end

function StateExtractor:extract_current_blind()
    -- Delegate to BlindExtractor for backward compatibility
    for _, extractor in ipairs(self.extractors) do
        if extractor:get_name() == "blind_extractor" then
            return extractor:extract_current_blind()
        end
    end
    return {
        name = "",
        blind_type = "small",
        requirement = 0,
        reward = 0,
        properties = {}
    } -- Safe default if BlindExtractor not found
end

function StateExtractor:extract_shop_contents()
    -- Delegate to ShopExtractor for backward compatibility
    for _, extractor in ipairs(self.extractors) do
        if extractor:get_name() == "shop_extractor" then
            return extractor:extract_shop_contents()
        end
    end
    return {} -- Safe default if ShopExtractor not found
end

function StateExtractor:get_available_actions()
    -- Delegate to ActionExtractor for backward compatibility
    for _, extractor in ipairs(self.extractors) do
        if extractor:get_name() == "action_extractor" then
            return extractor:get_available_actions()
        end
    end
    return {} -- Safe default if ActionExtractor not found
end

function StateExtractor:is_joker_reorder_available()
    -- Delegate to JokerReorderExtractor for backward compatibility
    for _, extractor in ipairs(self.extractors) do
        if extractor:get_name() == "joker_reorder_extractor" then
            return extractor:is_joker_reorder_available()
        end
    end
    return false -- Safe default if JokerReorderExtractor not found
end

-- Original validation methods preserved for backward compatibility
function StateExtractor:validate_g_object()
    if not G then
        return false
    end
    
    local critical_properties = {
        "STATE", "STATES", "GAME", "hand", "jokers", "consumeables", "shop_jokers", "FUNCS"
    }
    
    local missing_properties = {}
    for _, prop in ipairs(critical_properties) do
        if G[prop] == nil then
            table.insert(missing_properties, prop)
        end
    end
    
    self:validate_game_object()
    self:validate_card_areas()
    self:validate_states()
    
    return #missing_properties == 0
end

function StateExtractor:validate_game_object()
    if not G or not G.GAME then
        return
    end
end

function StateExtractor:validate_card_areas()
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

function StateExtractor:validate_card_structure(card, card_name)
    if not card then
        return
    end
end

function StateExtractor:validate_states()
    if not G.STATE or not G.STATES then
        return
    end
end

return StateExtractor