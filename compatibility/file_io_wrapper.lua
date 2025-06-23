-- Backward Compatibility Wrapper for FileIO
-- Maintains existing API while using the new refactored architecture internally
-- Allows gradual migration from old FileIO to new MessageManager + FileTransport

local MessageManager = require("message_manager")
local FileTransport = require("transports.file_transport")

local FileIO = {}
FileIO.__index = FileIO

function FileIO.new(base_path)
    local self = setmetatable({}, FileIO)
    
    -- Create the new architecture components
    local transport = FileTransport.new(base_path)
    self.message_manager = MessageManager.new(transport, "FILE_IO_COMPAT")
    
    -- Expose transport properties for backward compatibility
    self.base_path = transport.base_path
    self.sequence_id = 0  -- Will be managed by message_manager
    self.last_read_sequences = transport.last_read_sequences
    self.component_name = "FILE_IO"
    self.json = self.message_manager.json
    
    -- Direct access to transport for specific operations
    self.transport = transport
    
    return self
end

-- Backward compatible logging method
function FileIO:log(message)
    -- Delegate to message manager which handles logging
    self.message_manager:log(message)
end

-- Backward compatible sequence ID method
function FileIO:get_next_sequence_id()
    -- Delegate to message manager
    return self.message_manager:get_next_sequence_id()
end

-- Backward compatible write_game_state
function FileIO:write_game_state(state_data)
    -- Delegate to message manager
    return self.message_manager:write_game_state(state_data)
end

-- Backward compatible write_deck_state
function FileIO:write_deck_state(deck_data)
    -- Delegate to message manager
    return self.message_manager:write_deck_state(deck_data)
end

-- Backward compatible read_actions
function FileIO:read_actions()
    -- Delegate to message manager
    return self.message_manager:read_actions()
end

-- Backward compatible write_action_result
function FileIO:write_action_result(result_data)
    -- Delegate to message manager
    return self.message_manager:write_action_result(result_data)
end

-- Backward compatible cleanup_old_files
function FileIO:cleanup_old_files(max_age_seconds)
    -- Delegate to message manager
    return self.message_manager:cleanup_old_messages(max_age_seconds)
end

return FileIO