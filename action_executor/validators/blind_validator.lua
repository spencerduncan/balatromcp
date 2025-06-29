-- Blind selection validation against game progression rules
-- Ignores agent-provided blind_type and enforces G.GAME.blind_on_deck selection

local IActionValidator = assert(SMODS.load_file("action_executor/validators/i_action_validator.lua"))()
local ValidationResult = assert(SMODS.load_file("action_executor/validators/validation_result.lua"))()

local BlindValidator = {}
BlindValidator.__index = BlindValidator
setmetatable(BlindValidator, {__index = IActionValidator})

function BlindValidator.new()
    local self = setmetatable({}, BlindValidator)
    return self
end

function BlindValidator:get_name()
    return "blind_validator"
end

function BlindValidator:get_action_types()
    return {"select_blind"}
end

function BlindValidator:validate(action_data, game_state)
    -- Validate that we have the necessary game state information
    if not game_state then
        return ValidationResult.error("No game state available for blind validation")
    end
    
    -- Get the required blind from game progression
    local required_blind = game_state.blind_on_deck
    if not required_blind then
        return ValidationResult.error("No blind progression available - blind_on_deck not set")
    end
    
    -- Validate that the required blind is available for selection
    if not game_state.blind_select_opts then
        return ValidationResult.error("Blind selection options not available")
    end
    
    -- Normalize both required blind and available blind keys for case-insensitive comparison
    local normalized_required = string.lower(required_blind)
    local blind_option = nil
    local available_blinds = {}
    
    -- Find matching blind with case-insensitive comparison
    for key, option in pairs(game_state.blind_select_opts) do
        local normalized_key = string.lower(key)
        available_blinds[normalized_key] = key  -- Store original key for error reporting
        if normalized_key == normalized_required then
            blind_option = option
            break
        end
    end
    
    if not blind_option then
        -- Get list of available blinds for error message (use original case)
        local available_list = {}
        for _, original_key in pairs(available_blinds) do
            table.insert(available_list, original_key)
        end
        
        local available_str = #available_list > 0 and table.concat(available_list, ", ") or "none"
        return ValidationResult.error("Required blind '" .. required_blind .. "' not available. Available: " .. available_str)
    end
    
    -- CRITICAL: Override agent selection with game progression requirement
    -- This completely ignores what the agent requested and enforces the correct blind
    local original_blind = action_data.blind_type
    action_data.blind_type = required_blind
    
    -- Log the override for transparency
    if original_blind and original_blind ~= required_blind then
        print("BalatroMCP: BlindValidator - Overriding agent blind selection '" .. original_blind .. "' with required progression blind '" .. required_blind .. "'")
    else
        print("BalatroMCP: BlindValidator - Enforcing progression blind '" .. required_blind .. "'")
    end
    
    return ValidationResult.success("Blind selection validated and enforced: " .. required_blind)
end

-- Additional helper method to check if a blind is valid for the current progression
function BlindValidator:is_blind_available(blind_type, game_state)
    if not game_state or not game_state.blind_select_opts then
        return false
    end
    
    return game_state.blind_select_opts[string.lower(blind_type)] ~= nil
end

-- Helper method to get the current required blind
function BlindValidator:get_required_blind(game_state)
    if not game_state then
        return nil
    end
    
    return game_state.blind_on_deck
end

-- Helper method to get all available blinds for debugging
function BlindValidator:get_available_blinds(game_state)
    if not game_state or not game_state.blind_select_opts then
        return {}
    end
    
    local available = {}
    for blind_key, _ in pairs(game_state.blind_select_opts) do
        table.insert(available, blind_key)
    end
    
    return available
end

return BlindValidator