-- Current blind extraction module
-- Handles current blind information extraction

local IExtractor = assert(SMODS.load_file("state_extractor/extractors/i_extractor.lua"))()
local StateExtractorUtils = assert(SMODS.load_file("state_extractor/utils/state_extractor_utils.lua"))()
local CardUtils = assert(SMODS.load_file("state_extractor/utils/card_utils.lua"))()

local BlindExtractor = {}
BlindExtractor.__index = BlindExtractor
setmetatable(BlindExtractor, {__index = IExtractor})

function BlindExtractor.new()
    local self = setmetatable({}, BlindExtractor)
    return self
end

function BlindExtractor:get_name()
    return "blind_extractor"
end

function BlindExtractor:extract()
    local success, result = pcall(function()
        return self:extract_current_blind()
    end)
    
    if success then
        return {current_blind = result}
    else
        return {current_blind = {
            name = "",
            blind_type = "small",
            requirement = 0,
            reward = 0,
            properties = {}
        }}
    end
end


function BlindExtractor:extract_current_blind()
    -- Extract current blind information with CIRCULAR REFERENCE SAFE access
    -- Inline phase detection logic
    local current_phase = "hand_selection" -- Safe default
    if StateExtractorUtils.safe_check_path(G, {"STATE"}) and StateExtractorUtils.safe_check_path(G, {"STATES"}) then
        local current_state = G.STATE
        local states = G.STATES
        
        -- Comprehensive state mapping using G.STATES constants
        -- Hand/Card Selection States
        if current_state == states.SELECTING_HAND then
            current_phase = "hand_selection"
        elseif current_state == states.DRAW_TO_HAND then
            current_phase = "drawing_cards"
        elseif current_state == states.HAND_PLAYED then
            current_phase = "hand_played"
        
        -- Shop and Purchase States
        elseif current_state == states.SHOP then
            current_phase = "shop"
        
        -- Blind Selection and Round States
        elseif current_state == states.BLIND_SELECT then
            current_phase = "blind_selection"
        elseif current_state == states.NEW_ROUND then
            current_phase = "new_round"
        elseif current_state == states.ROUND_EVAL then
            current_phase = "round_evaluation"
        
        -- Pack Opening States
        elseif current_state == states.STANDARD_PACK then
            current_phase = "pack_opening"
        elseif current_state == states.BUFFOON_PACK then
            current_phase = "pack_opening"
        elseif current_state == states.TAROT_PACK then
            current_phase = "pack_opening"
        elseif current_state == states.PLANET_PACK then
            current_phase = "pack_opening"
        elseif current_state == states.SPECTRAL_PACK then
            current_phase = "pack_opening"
        elseif current_state == states.SMODS_BOOSTER_OPENED then
            current_phase = "pack_opening"
        
        -- Consumable Usage States
        elseif current_state == states.PLAY_TAROT then
            current_phase = "using_consumable"
        
        -- Menu and Navigation States
        elseif current_state == states.MENU then
            current_phase = "menu"
        elseif current_state == states.SPLASH then
            current_phase = "splash"
        elseif current_state == states.TUTORIAL then
            current_phase = "tutorial"
        elseif current_state == states.DEMO_CTA then
            current_phase = "demo_prompt"
        
        -- Game End States
        elseif current_state == states.GAME_OVER then
            current_phase = "game_over"
        
        -- Special Game Modes
        elseif current_state == states.SANDBOX then
            current_phase = "sandbox"
        
        -- Fallback for unknown states
        else
            current_phase = "hand_selection" -- Safe default
        end
    end
    
    -- During blind selection phase, extract information from blind selection options
    if current_phase == "blind_selection" then
        return self:extract_blind_selection_info()
    end
    
    -- For other phases, extract from current blind
    if not StateExtractorUtils.safe_check_path(G, {"GAME", "blind"}) then
        return {
            name = "",
            blind_type = "small",
            requirement = 0,
            reward = 0,
            properties = {}
        }
    end
    
    local blind = G.GAME.blind
    return {
        name = StateExtractorUtils.safe_primitive_value(blind, "name", ""),
        blind_type = CardUtils.determine_blind_type_safe(blind),
        requirement = StateExtractorUtils.safe_primitive_value(blind, "chips", 0),
        reward = StateExtractorUtils.safe_primitive_value(blind, "dollars", 0),
        -- AVOID CIRCULAR REFERENCE: Don't extract complex config object
        properties = {}
    }
end

function BlindExtractor:extract_blind_selection_info()
    -- Extract blind information during blind selection phase
    local blind_info = {
        name = "",
        blind_type = "small",
        requirement = 0,
        reward = 0,
        properties = {}
    }
    
    -- Try to determine which blind is being selected from game progression
    if StateExtractorUtils.safe_check_path(G, {"GAME", "blind_on_deck"}) then
        local blind_on_deck = G.GAME.blind_on_deck
        if blind_on_deck then
            blind_info.blind_type = string.lower(blind_on_deck)
            
            -- Try to get blind details from selection options
            if StateExtractorUtils.safe_check_path(G, {"blind_select_opts"}) then
                local blind_option = G.blind_select_opts[string.lower(blind_on_deck)]
                if blind_option and blind_option.config and blind_option.config.blind then
                    local blind_config = blind_option.config.blind
                    blind_info.name = StateExtractorUtils.safe_primitive_value(blind_config, "name", "")
                    blind_info.requirement = StateExtractorUtils.safe_primitive_value(blind_config, "chips", 0)
                    blind_info.reward = StateExtractorUtils.safe_primitive_value(blind_config, "dollars", 0)
                end
            end
        end
    else
        -- Fallback: determine from available blind options
        if StateExtractorUtils.safe_check_path(G, {"blind_select_opts"}) then
            -- If we have both small and big, we're likely selecting big blind
            if G.blind_select_opts["big"] and G.blind_select_opts["small"] then
                blind_info.blind_type = "big"
                
                local blind_option = G.blind_select_opts["big"]
                if blind_option and blind_option.config and blind_option.config.blind then
                    local blind_config = blind_option.config.blind
                    blind_info.name = StateExtractorUtils.safe_primitive_value(blind_config, "name", "Big Blind")
                    blind_info.requirement = StateExtractorUtils.safe_primitive_value(blind_config, "chips", 0)
                    blind_info.reward = StateExtractorUtils.safe_primitive_value(blind_config, "dollars", 0)
                end
            elseif G.blind_select_opts["small"] then
                blind_info.blind_type = "small"
                
                local blind_option = G.blind_select_opts["small"]
                if blind_option and blind_option.config and blind_option.config.blind then
                    local blind_config = blind_option.config.blind
                    blind_info.name = StateExtractorUtils.safe_primitive_value(blind_config, "name", "Small Blind")
                    blind_info.requirement = StateExtractorUtils.safe_primitive_value(blind_config, "chips", 0)
                    blind_info.reward = StateExtractorUtils.safe_primitive_value(blind_config, "dollars", 0)
                end
            elseif G.blind_select_opts["boss"] then
                blind_info.blind_type = "boss"
                
                local blind_option = G.blind_select_opts["boss"]
                if blind_option and blind_option.config and blind_option.config.blind then
                    local blind_config = blind_option.config.blind
                    blind_info.name = StateExtractorUtils.safe_primitive_value(blind_config, "name", "Boss Blind")
                    blind_info.requirement = StateExtractorUtils.safe_primitive_value(blind_config, "chips", 0)
                    blind_info.reward = StateExtractorUtils.safe_primitive_value(blind_config, "dollars", 0)
                end
            end
        end
    end
    
    return blind_info
end

return BlindExtractor