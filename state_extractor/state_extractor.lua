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

local StateExtractor = {}
StateExtractor.__index = StateExtractor

function StateExtractor.new()
    local self = setmetatable({}, StateExtractor)
    self.component_name = "STATE_EXTRACTOR"
    self.extractors = {}
    
    -- Load IExtractor once and cache it for all registrations
    self.IExtractor = assert(SMODS.load_file("state_extractor/extractors/i_extractor.lua"))()
    
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
    
    -- Immediately test G object availability and structure
    self:validate_g_object()
    
    return self
end

function StateExtractor:register_extractor(extractor)
    -- Use cached IExtractor for validation
    local IExtractor = self.IExtractor
    
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

-- Backward compatibility method for session ID access
function StateExtractor:get_session_id()
    -- Use existing session_id if available
    if self.session_id then
        return self.session_id
    end
    
    -- Find SessionExtractor and delegate to it
    for _, extractor in ipairs(self.extractors) do
        if extractor:get_name() == "session_extractor" then
            self.session_id = extractor:get_session_id()
            return self.session_id
        end
    end
    
    -- Fallback if SessionExtractor not found
    self.session_id = "session_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
    return self.session_id
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