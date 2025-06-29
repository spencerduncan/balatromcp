-- Interface definition for action validators
-- All validators must implement this interface to be compatible with ActionValidator framework

local IActionValidator = {}
IActionValidator.__index = IActionValidator

-- Create a new validator instance
function IActionValidator.new()
    local self = setmetatable({}, IActionValidator)
    return self
end

-- Get the name of this validator (must be implemented by subclasses)
function IActionValidator:get_name()
    error("get_name() must be implemented by validator subclass")
end

-- Get the action types this validator handles (must be implemented by subclasses)
-- Should return an array of action type strings, e.g., {"select_blind", "reroll_boss"}
function IActionValidator:get_action_types()
    error("get_action_types() must be implemented by validator subclass")
end

-- Validate an action and return ValidationResult (must be implemented by subclasses)
-- Parameters:
--   action_data: The action data from the agent (may be modified by validation)
--   game_state: Current game state extracted from extractors
-- Returns: ValidationResult indicating success or failure with error message
function IActionValidator:validate(action_data, game_state)
    error("validate() must be implemented by validator subclass")
end

-- Optional: Perform any setup required for validation (can be overridden by subclasses)
function IActionValidator:initialize()
    -- Default implementation does nothing
end

-- Optional: Cleanup resources when validator is no longer needed (can be overridden by subclasses)
function IActionValidator:cleanup()
    -- Default implementation does nothing
end

-- Helper method to check if this validator handles a specific action type
function IActionValidator:handles_action_type(action_type)
    local action_types = self:get_action_types()
    for _, supported_type in ipairs(action_types) do
        if supported_type == action_type then
            return true
        end
    end
    return false
end

return IActionValidator