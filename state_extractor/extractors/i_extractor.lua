-- Interface definition for state extractors
-- All concrete extractors must implement this interface

local IExtractor = {}
IExtractor.__index = IExtractor

-- Factory method to create a new extractor interface
function IExtractor.new()
    local self = setmetatable({}, IExtractor)
    return self
end

-- Abstract method: Extract state data
-- Must be implemented by concrete extractors
-- @return table - The extracted state data
function IExtractor:extract()
    error("extract() method must be implemented by concrete extractor")
end

-- Abstract method: Get extractor name/identifier
-- Must be implemented by concrete extractors
-- @return string - The name/identifier of this extractor
function IExtractor:get_name()
    error("get_name() method must be implemented by concrete extractor")
end

-- Utility method to validate that a class implements the interface
-- @param extractor - The extractor instance to validate
-- @return boolean - True if the extractor implements the interface correctly
function IExtractor.validate_implementation(extractor)
    if not extractor then
        return false
    end
    
    -- Check that required methods exist
    if type(extractor.extract) ~= "function" then
        return false
    end
    
    if type(extractor.get_name) ~= "function" then
        return false
    end
    
    return true
end

return IExtractor