-- Generic message transport interface
-- Defines the contract for all message I/O implementations
-- Follows Dependency Inversion Principle - abstracts I/O operations

local IMessageTransport = {}
IMessageTransport.__index = IMessageTransport

-- Interface contract documentation
-- All concrete implementations must provide these methods:

-- write_message(message_data, message_type) -> boolean
-- Writes a complete message to the transport medium
-- @param message_data: table containing the full message structure
-- @param message_type: string identifying the message type ("game_state", "deck_state", etc.)
-- @return: boolean - true on success, false on failure

-- read_message(message_type) -> table|nil
-- Reads the most recent unprocessed message of the specified type
-- @param message_type: string identifying the message type to read
-- @return: table - message data on success, nil if no new messages

-- verify_message(message_data, message_type) -> boolean
-- Verifies message integrity after write operation
-- @param message_data: table containing the message to verify
-- @param message_type: string identifying the message type
-- @return: boolean - true if verification successful, false otherwise

-- cleanup_old_messages(max_age_seconds) -> boolean
-- Removes messages older than specified age
-- @param max_age_seconds: number of seconds for message retention
-- @return: boolean - true on successful cleanup, false on failure

-- is_available() -> boolean
-- Checks if the transport medium is available and operational
-- @return: boolean - true if transport is ready, false otherwise

function IMessageTransport.new()
    error("IMessageTransport is an interface and cannot be instantiated directly")
end

-- Interface validation helper
function IMessageTransport.validate_implementation(instance)
    local required_methods = {
        "write_message",
        "read_message", 
        "verify_message",
        "cleanup_old_messages",
        "is_available"
    }
    
    for _, method in ipairs(required_methods) do
        if type(instance[method]) ~= "function" then
            error("Implementation missing required method: " .. method)
        end
    end
    
    return true
end

return IMessageTransport