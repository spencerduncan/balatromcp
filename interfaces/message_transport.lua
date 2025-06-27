-- Generic message transport interface
-- Defines the contract for all message I/O implementations
-- Follows Dependency Inversion Principle - abstracts I/O operations

local IMessageTransport = {}
IMessageTransport.__index = IMessageTransport

-- Interface contract documentation
-- All concrete implementations must provide these methods:

-- write_message(message_data, message_type, callback) -> boolean
-- Writes a complete message to the transport medium
-- @param message_data: table containing the full message structure
-- @param message_type: string identifying the message type ("game_state", "deck_state", etc.)
-- @param callback: optional function(success) - called when operation completes (for async implementations)
-- @return: boolean - true on success/submitted, false on failure

-- read_message(message_type, callback) -> table|nil
-- Reads the most recent unprocessed message of the specified type
-- @param message_type: string identifying the message type to read
-- @param callback: optional function(success, data) - called when operation completes (for async implementations)
-- @return: table - message data on success, nil if no new messages (sync) or async operation initiated

-- verify_message(message_data, message_type, callback) -> boolean
-- Verifies message integrity after write operation
-- @param message_data: table containing the message to verify
-- @param message_type: string identifying the message type
-- @param callback: optional function(success) - called when operation completes (for async implementations)
-- @return: boolean - true if verification successful/submitted, false otherwise

-- cleanup_old_messages(max_age_seconds, callback) -> boolean
-- Removes messages older than specified age
-- @param max_age_seconds: number of seconds for message retention
-- @param callback: optional function(success, count) - called when operation completes (for async implementations)
-- @return: boolean - true on successful cleanup/submitted, false on failure

-- update() -> void (optional for async implementations)
-- Processes pending async operations and responses
-- Should be called regularly in the main loop for async transports

-- cleanup() -> void (optional for async implementations)
-- Cleans up async resources (threads, channels, etc.)
-- Should be called when shutting down async transports

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