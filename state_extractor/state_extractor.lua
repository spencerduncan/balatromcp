-- Main StateExtractor orchestrator class
-- Manages collection of specialized extractors and provides unified interface

local StateExtractorUtils = assert(SMODS.load_file("state_extractor/utils/state_extractor_utils.lua"))()
local CardUtils = assert(SMODS.load_file("state_extractor/utils/card_utils.lua"))()

-- Import all specialized extractors
local SessionExtractor = assert(SMODS.load_file("state_extractor/extractors/session_extractor.lua"))()
local PhaseExtractor = assert(SMODS.load_file("state_extractor/extractors/phase_extractor.lua"))()
local GameStateExtractor = assert(SMODS.load_file("state_extractor/extractors/game_state_extractor.lua"))()
local RoundStateExtractor = assert(SMODS.load_file("state_extractor/extractors/round_state_extractor.lua"))()
local HandCardExtractor = assert(SMODS.load_file("state_extractor/extractors/hand_card_extractor.lua"))()
local JokerExtractor = assert(SMODS.load_file("state_extractor/extractors/joker_extractor.lua"))()
local ConsumableExtractor = assert(SMODS.load_file("state_extractor/extractors/consumable_extractor.lua"))()
local DeckCardExtractor = assert(SMODS.load_file("state_extractor/extractors/deck_card_extractor.lua"))()
local BlindExtractor = assert(SMODS.load_file("state_extractor/extractors/blind_extractor.lua"))()
local ShopExtractor = assert(SMODS.load_file("state_extractor/extractors/shop_extractor.lua"))()
local ActionExtractor = assert(SMODS.load_file("state_extractor/extractors/action_extractor.lua"))()
local JokerReorderExtractor = assert(SMODS.load_file("state_extractor/extractors/joker_reorder_extractor.lua"))()
local VoucherAnteExtractor = assert(SMODS.load_file("state_extractor/extractors/voucher_ante_extractor.lua"))()
local PackExtractor = assert(SMODS.load_file("state_extractor/extractors/pack_extractor.lua"))()
local HandLevelsExtractor = assert(SMODS.load_file("state_extractor/extractors/hand_levels_extractor.lua"))()

local StateExtractor = {}
StateExtractor.__index = StateExtractor

function StateExtractor.new()
    local self = setmetatable({}, StateExtractor)
    self.component_name = "STATE_EXTRACTOR"
    self.extractors = {}
    self.extractor_lookup = {}
    
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
    self:register_extractor(VoucherAnteExtractor.new())
    self:register_extractor(PackExtractor.new())
    self:register_extractor(HandLevelsExtractor.new())
    
    -- Immediately test G object availability and structure
    self:validate_g_object()
    
    return self
end

function StateExtractor:register_extractor(extractor)
    -- Import IExtractor for validation
    -- Use direct require for better test compatibility
    local IExtractor
    if SMODS and SMODS.load_file then
        -- Production environment - use SMODS
        local load_result = SMODS.load_file("state_extractor/extractors/i_extractor.lua")
        if load_result then
            IExtractor = load_result()
        end
    end
    
    -- Fallback to direct require for test environments
    if not IExtractor then
        IExtractor = require("state_extractor.extractors.i_extractor")
    end
    
    if not IExtractor then
        error("Failed to load IExtractor interface")
    end
    
    -- Validate extractor implements required interface
    if IExtractor.validate_implementation(extractor) then
        table.insert(self.extractors, extractor)
        
        -- Add to lookup table for O(1) access
        local extractor_name = extractor:get_name()
        if extractor_name then
            self.extractor_lookup[extractor_name] = extractor
        end
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
    
    -- Include extraction errors in output for debugging if any occurred
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

-- Backward compatibility method for session ID access
function StateExtractor:get_session_id()
    -- Use existing session_id if available
    if self.session_id then
        return self.session_id
    end
    
    -- Use O(1) lookup instead of O(n) search
    local extractor = self.extractor_lookup["session_extractor"]
    if extractor and extractor.get_session_id then
        self.session_id = extractor:get_session_id()
        return self.session_id
    end
    
    -- Fallback if SessionExtractor not found
    self.session_id = "session_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
    return self.session_id
end

-- Delegation method for deck cards extraction
function StateExtractor:extract_deck_cards()
    local extractor = self.extractor_lookup["deck_card_extractor"]
    if extractor and extractor.extract_deck_cards then
        return extractor:extract_deck_cards()
    end
    return {}
end

-- Delegation method for remaining deck cards extraction
function StateExtractor:extract_remaining_deck_cards()
    local extractor = self.extractor_lookup["deck_card_extractor"]
    if extractor and extractor.extract_remaining_deck_cards then
        return extractor:extract_remaining_deck_cards()
    end
    return {}
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

-- Enhanced G object validation for extraction diagnostics
function StateExtractor:validate_g_object_for_extraction()
    local validation_result = {
        valid = true,
        reason = "",
        missing_properties = {}
    }
    
    if not G then
        validation_result.valid = false
        validation_result.reason = "Global G object is nil"
        return validation_result
    end
    
    local critical_properties = {
        "STATE", "STATES", "GAME", "hand", "jokers", "consumeables", "shop_jokers"
    }
    
    for _, prop in ipairs(critical_properties) do
        if G[prop] == nil then
            table.insert(validation_result.missing_properties, prop)
            validation_result.valid = false
        end
    end
    
    if not validation_result.valid then
        validation_result.reason = "Missing critical properties: " .. table.concat(validation_result.missing_properties, ", ")
    end
    
    return validation_result
end

-- Get required G object paths for each extractor type
function StateExtractor:get_extractor_required_paths(extractor_name)
    local extractor_paths = {
        session_extractor = {},
        phase_extractor = {{"STATE"}, {"STATES"}},
        game_state_extractor = {{"GAME", "round_resets", "ante"}, {"GAME", "dollars"}},
        round_state_extractor = {{"GAME", "current_round", "hands_left"}, {"GAME", "current_round", "discards_left"}},
        hand_card_extractor = {{"hand", "cards"}},
        joker_extractor = {{"jokers", "cards"}},
        consumable_extractor = {{"consumeables", "cards"}},
        deck_card_extractor = {{"deck", "cards"}, {"playing_cards"}},
        blind_extractor = {{"GAME", "blind"}},
        shop_extractor = {{"shop_jokers", "cards"}},
        action_extractor = {},
        joker_reorder_extractor = {{"jokers", "cards"}},
        pack_extractor = {{"pack_cards", "cards"}},
        voucher_ante_extractor = {{"GAME", "vouchers"}, {"shop_vouchers", "cards"}},
        hand_levels_extractor = {{"GAME", "hands"}, {"GAME", "hand_levels"}, {"GAME", "poker_hands"}}
    }
    
    return extractor_paths[extractor_name] or {}
end

-- Check if a specific G object path exists
function StateExtractor:check_g_object_path(path)
    if not G then
        return false
    end
    
    local current = G
    for _, segment in ipairs(path) do
        if type(current) ~= "table" or current[segment] == nil then
            return false
        end
        current = current[segment]
    end
    
    return true
end

return StateExtractor