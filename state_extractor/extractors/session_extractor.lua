-- Session ID extraction module
-- Handles session ID generation and management

local IExtractor = assert(SMODS.load_file("state_extractor/extractors/i_extractor.lua"))()
local StateExtractorUtils = assert(SMODS.load_file("state_extractor/utils/state_extractor_utils.lua"))()

local SessionExtractor = {}
SessionExtractor.__index = SessionExtractor
setmetatable(SessionExtractor, {__index = IExtractor})

function SessionExtractor.new()
    local self = setmetatable({}, SessionExtractor)
    self.session_id = nil -- Store session ID for persistence
    return self
end

function SessionExtractor:get_name()
    return "session_extractor"
end

function SessionExtractor:extract()
    local success, result = pcall(function()
        return self:get_session_id()
    end)
    
    if success then
        return {session_id = result}
    else
        return {session_id = nil}
    end
end

function SessionExtractor:get_session_id()
    if not self.session_id then
        self.session_id = "session_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
    end
    return self.session_id
end

return SessionExtractor