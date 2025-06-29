-- Central action validation orchestrator with plugin architecture
-- Manages registration and execution of action-specific validators

local ValidationResult = assert(SMODS.load_file("action_executor/validators/validation_result.lua"))()

local ActionValidator = {}
ActionValidator.__index = ActionValidator

function ActionValidator.new()
    local self = setmetatable({}, ActionValidator)
    self.validators = {} -- Action type -> array of validators mapping
    self.initialized = false
    return self
end

-- Initialize the validation framework
function ActionValidator:initialize()
    if self.initialized then
        return
    end
    
    -- Initialize all registered validators
    for action_type, validator_list in pairs(self.validators) do
        for _, validator in ipairs(validator_list) do
            if validator.initialize then
                local success, error_msg = pcall(function()
                    validator:initialize()
                end)
                if not success then
                    print("BalatroMCP: Warning - Failed to initialize validator for " .. action_type .. ": " .. tostring(error_msg))
                end
            end
        end
    end
    
    self.initialized = true
    print("BalatroMCP: ActionValidator framework initialized with " .. self:get_validator_count() .. " validators")
end

-- Register a validator for specific action types
function ActionValidator:register_validator(validator)
    if not validator or not validator.get_action_types or not validator.validate then
        return false, "Invalid validator: must implement get_action_types() and validate()"
    end
    
    local success, action_types = pcall(function()
        return validator:get_action_types()
    end)
    
    if not success or not action_types then
        return false, "Failed to get action types from validator: " .. tostring(action_types)
    end
    
    -- Register validator for each action type it handles
    for _, action_type in ipairs(action_types) do
        if not self.validators[action_type] then
            self.validators[action_type] = {}
        end
        table.insert(self.validators[action_type], validator)
        print("BalatroMCP: Registered validator for action type: " .. action_type)
    end
    
    return true, "Validator registered successfully"
end

-- Get all validators for a specific action type
function ActionValidator:get_validators_for_action(action_type)
    return self.validators[action_type] or {}
end

-- Get total number of registered validators across all action types
function ActionValidator:get_validator_count()
    local count = 0
    for _, validator_list in pairs(self.validators) do
        count = count + #validator_list
    end
    return count
end

-- Validate an action using all registered validators for that action type
function ActionValidator:validate_action(action_type, action_data, game_state)
    if not self.initialized then
        self:initialize()
    end
    
    if not action_type then
        return ValidationResult.error("No action type specified")
    end
    
    if not action_data then
        return ValidationResult.error("No action data provided")
    end
    
    local validators = self:get_validators_for_action(action_type)
    
    if #validators == 0 then
        -- No validators registered for this action type - allow by default
        return ValidationResult.success("No validation required for action type: " .. action_type)
    end
    
    -- Run all validators for this action type
    for i, validator in ipairs(validators) do
        local success, result = pcall(function()
            return validator:validate(action_data, game_state)
        end)
        
        if not success then
            -- Validator threw an error - treat as validation failure
            return ValidationResult.error("Validator error for " .. action_type .. ": " .. tostring(result))
        end
        
        if not result or not result.is_valid then
            -- Validation failed - return the error immediately
            local error_msg = "Validation failed for " .. action_type
            if result and result.error_message then
                error_msg = result.error_message
            end
            return ValidationResult.error(error_msg)
        end
        
        -- Log successful validation step
        print("BalatroMCP: Validator " .. i .. " passed for action type: " .. action_type)
    end
    
    -- All validators passed
    return ValidationResult.success("All validation passed for action type: " .. action_type)
end

-- Get current game state for validation (extracted from game state)
function ActionValidator:get_current_game_state()
    -- Extract relevant game state information for validation
    local game_state = {}
    
    -- Safe extraction with fallbacks
    if G and G.GAME then
        -- Blind progression information
        game_state.blind_on_deck = G.GAME.blind_on_deck
        
        -- Current ante information
        if G.GAME.round_resets then
            game_state.current_ante = G.GAME.round_resets.ante or 1
        else
            game_state.current_ante = 1
        end
        
        -- Available money
        game_state.dollars = G.GAME.dollars or 0
        game_state.bankrupt_at = G.GAME.bankrupt_at or 0
        
        -- Reroll tracking data
        game_state.reroll_tracking = G.GAME.balatromcp_reroll_tracking
    else
        -- Fallback values when game state unavailable
        game_state.blind_on_deck = nil
        game_state.current_ante = 1
        game_state.dollars = 0
        game_state.bankrupt_at = 0
        game_state.reroll_tracking = nil
    end
    
    -- Blind selection options
    if G and G.blind_select_opts then
        game_state.blind_select_opts = G.blind_select_opts
    else
        game_state.blind_select_opts = {}
    end
    
    -- Placeholder for voucher information (will be populated by extractors)
    game_state.owned_vouchers = {}
    
    return game_state
end

-- Cleanup resources when validator is no longer needed
function ActionValidator:cleanup()
    if not self.initialized then
        return
    end
    
    -- Cleanup all registered validators
    for action_type, validator_list in pairs(self.validators) do
        for _, validator in ipairs(validator_list) do
            if validator.cleanup then
                local success, error_msg = pcall(function()
                    validator:cleanup()
                end)
                if not success then
                    print("BalatroMCP: Warning - Failed to cleanup validator for " .. action_type .. ": " .. tostring(error_msg))
                end
            end
        end
    end
    
    self.initialized = false
    print("BalatroMCP: ActionValidator framework cleaned up")
end

return ActionValidator