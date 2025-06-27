-- Game phase detection module
-- Handles current game phase detection

local IExtractor = assert(SMODS.load_file("state_extractor/extractors/i_extractor.lua"))()
local StateExtractorUtils = assert(SMODS.load_file("state_extractor/utils/state_extractor_utils.lua"))()

local PhaseExtractor = {}
PhaseExtractor.__index = PhaseExtractor
setmetatable(PhaseExtractor, {__index = IExtractor})

function PhaseExtractor.new()
    local self = setmetatable({}, PhaseExtractor)
    return self
end

function PhaseExtractor:get_name()
    return "phase_extractor"
end

function PhaseExtractor:extract()
    local success, result = pcall(function()
        return self:get_current_phase()
    end)
    
    if success then
        return {phase = result}
    else
        return {phase = "hand_selection"}
    end
end

function PhaseExtractor:validate_g_object()
    if not G then
        return false
    end
    
    -- Test critical G object properties
    local critical_properties = {
        "STATE", "STATES", "GAME", "hand", "jokers", "consumeables", "shop_jokers", "FUNCS"
    }
    
    local missing_properties = {}
    for _, prop in ipairs(critical_properties) do
        if G[prop] == nil then
            table.insert(missing_properties, prop)
        end
    end
    
    return #missing_properties == 0
end

function PhaseExtractor:get_current_phase()
    -- Validate G object structure
    if not StateExtractorUtils.safe_check_path(G, {"STATE"}) then
        return "hand_selection"
    end
    
    if not StateExtractorUtils.safe_check_path(G, {"STATES"}) then
        return "hand_selection"
    end
    
    -- Use consistent direct access to G object
    local current_state = G.STATE
    local states = G.STATES
    
    -- Comprehensive state mapping using G.STATES constants
    -- Hand/Card Selection States
    if current_state == states.SELECTING_HAND then
        return "hand_selection"
    elseif current_state == states.DRAW_TO_HAND then
        return "drawing_cards"
    elseif current_state == states.HAND_PLAYED then
        return "hand_played"
    
    -- Shop and Purchase States
    elseif current_state == states.SHOP then
        return "shop"
    
    -- Blind Selection and Round States
    elseif current_state == states.BLIND_SELECT then
        return "blind_selection"
    elseif current_state == states.NEW_ROUND then
        return "new_round"
    elseif current_state == states.ROUND_EVAL then
        return "round_evaluation"
    
    -- Pack Opening States
    elseif current_state == states.STANDARD_PACK then
        return "pack_opening"
    elseif current_state == states.BUFFOON_PACK then
        return "pack_opening"
    elseif current_state == states.TAROT_PACK then
        return "pack_opening"
    elseif current_state == states.PLANET_PACK then
        return "pack_opening"
    elseif current_state == states.SPECTRAL_PACK then
        return "pack_opening"
    elseif current_state == states.SMODS_BOOSTER_OPENED then
        return "pack_opening"
    
    -- Consumable Usage States
    elseif current_state == states.PLAY_TAROT then
        return "using_consumable"
    
    -- Menu and Navigation States
    elseif current_state == states.MENU then
        return "menu"
    elseif current_state == states.SPLASH then
        return "splash"
    elseif current_state == states.TUTORIAL then
        return "tutorial"
    elseif current_state == states.DEMO_CTA then
        return "demo_prompt"
    
    -- Game End States
    elseif current_state == states.GAME_OVER then
        return "game_over"
    
    -- Special Game Modes
    elseif current_state == states.SANDBOX then
        return "sandbox"
    
    -- Fallback for unknown states
    else
        return "hand_selection" -- Safe default
    end
end

return PhaseExtractor