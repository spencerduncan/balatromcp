-- Standardized validation result structure for action validation
-- Provides consistent success/error handling across all validators

local ValidationResult = {}
ValidationResult.__index = ValidationResult

-- Create a successful validation result
function ValidationResult.success(message)
    local self = setmetatable({}, ValidationResult)
    self.is_valid = true
    self.error_message = nil
    self.success_message = message or "Validation passed"
    return self
end

-- Create an error validation result
function ValidationResult.error(error_message)
    local self = setmetatable({}, ValidationResult)
    self.is_valid = false
    self.error_message = error_message or "Validation failed"
    self.success_message = nil
    return self
end

-- Check if the validation result indicates success
function ValidationResult:is_success()
    return self.is_valid == true
end

-- Check if the validation result indicates failure
function ValidationResult:is_failure()
    return self.is_valid == false
end

-- Get the appropriate message (error or success)
function ValidationResult:get_message()
    if self.is_valid then
        return self.success_message
    else
        return self.error_message
    end
end

-- Convert validation result to string for logging
function ValidationResult:to_string()
    if self.is_valid then
        return "SUCCESS: " .. (self.success_message or "Validation passed")
    else
        return "ERROR: " .. (self.error_message or "Validation failed")
    end
end

return ValidationResult