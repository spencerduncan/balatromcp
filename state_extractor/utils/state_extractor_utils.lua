-- Core safe access utility functions for state extraction
-- Provides circular reference safe methods for accessing nested table structures

local StateExtractorUtils = {}

-- Safe path checking utility
function StateExtractorUtils.safe_check_path(root, path)
    if not root then
        return false
    end
    
    local current = root
    for _, key in ipairs(path) do
        if type(current) ~= "table" or current[key] == nil then
            return false
        end
        current = current[key]
    end
    return true
end

-- Safe value retrieval with default fallback
function StateExtractorUtils.safe_get_value(table, key, default)
    if not table or type(table) ~= "table" then
        return default
    end
    
    if table[key] ~= nil then
        return table[key]
    end
    
    return default
end

-- Safe nested value retrieval with path array
function StateExtractorUtils.safe_get_nested_value(root, path, default)
    if not root then
        return default
    end
    
    local current = root
    for _, key in ipairs(path) do
        if type(current) ~= "table" or current[key] == nil then
            return default
        end
        current = current[key]
    end
    return current
end

-- CIRCULAR REFERENCE SAFE utility functions
function StateExtractorUtils.safe_primitive_value(table, key, default)
    -- Safely get a PRIMITIVE VALUE ONLY from a table with default fallback
    -- This prevents circular references by only returning primitive types
    if not table or type(table) ~= "table" then
        return default
    end
    
    local value = table[key]
    if value ~= nil then
        local value_type = type(value)
        if value_type == "string" or value_type == "number" or value_type == "boolean" then
            return value
        else
            -- Non-primitive type detected, return default to avoid circular reference
            return default
        end
    end
    
    return default
end

function StateExtractorUtils.safe_primitive_nested_value(root, path, default)
    -- Safely get a nested PRIMITIVE VALUE ONLY from a table structure
    -- This prevents circular references by only returning primitive types
    if not root then
        return default
    end
    
    local current = root
    for _, key in ipairs(path) do
        if type(current) ~= "table" or current[key] == nil then
            return default
        end
        current = current[key]
    end
    
    -- Only return if it's a primitive type
    local value_type = type(current)
    if value_type == "string" or value_type == "number" or value_type == "boolean" then
        return current
    else
        -- Non-primitive type detected, return default to avoid circular reference
        return default
    end
end

return StateExtractorUtils