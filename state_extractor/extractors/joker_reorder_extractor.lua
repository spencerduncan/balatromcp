-- Joker reorder availability detection module
-- Handles joker reorder availability

local IExtractor = require("state_extractor.extractors.i_extractor")
local StateExtractorUtils = require("state_extractor.utils.state_extractor_utils")

local JokerReorderExtractor = {}
JokerReorderExtractor.__index = JokerReorderExtractor
setmetatable(JokerReorderExtractor, {__index = IExtractor})

function JokerReorderExtractor.new()
    local self = setmetatable({}, JokerReorderExtractor)
    return self
end

function JokerReorderExtractor:get_name()
    return "joker_reorder_extractor"
end

function JokerReorderExtractor:extract()
    local success, result = pcall(function()
        return self:is_joker_reorder_available()
    end)
    
    if success then
        return {post_hand_joker_reorder_available = result}
    else
        return {post_hand_joker_reorder_available = false}
    end
end

function JokerReorderExtractor:is_joker_reorder_available()
    return false -- Placeholder - needs implementation
end

return JokerReorderExtractor