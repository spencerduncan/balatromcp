-- Message Manager - Handles message creation, metadata management, and transport coordination
-- Follows Single Responsibility Principle - focused on message structure and coordination
-- Uses Dependency Injection - accepts IMessageTransport implementation

local MessageManager = {}
MessageManager.__index = MessageManager

function MessageManager.new(transport, component_name)
    if not transport then
        error("MessageManager requires a transport implementation")
    end
    
    -- Validate transport implements the interface
    local required_methods = {"write_message", "read_message", "verify_message", "cleanup_old_messages", "is_available"}
    for _, method in ipairs(required_methods) do
        if type(transport[method]) ~= "function" then
            error("Transport implementation missing required method: " .. method)
        end
    end
    
    local self = setmetatable({}, MessageManager)
    self.transport = transport
    self.sequence_id = 0
    self.component_name = component_name or "MESSAGE_MANAGER"
    
    -- Load JSON library via SMODS
    if not SMODS then
        error("SMODS not available - required for JSON library loading")
    end
    
    local json_loader = SMODS.load_file("libs/json.lua")
    if not json_loader then
        error("Failed to load required JSON library via SMODS")
    end
    
    self.json = json_loader()
    if not self.json then
        error("Failed to load required JSON library")
    end
    
    self:log("MessageManager initialized with transport: " .. tostring(transport))
    
    return self
end

function MessageManager:log(message)
    local log_msg = "BalatroMCP [" .. self.component_name .. "]: " .. message
    print(log_msg)
end

function MessageManager:get_next_sequence_id()
    self.sequence_id = self.sequence_id + 1
    return self.sequence_id
end

-- Private method - creates message structure with metadata
function MessageManager:create_message(data, message_type)
    if not data then
        error("Message data is required")
    end
    
    if not message_type then
        error("Message type is required")
    end
    
    local message = {
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        sequence_id = self:get_next_sequence_id(),
        message_type = message_type,
        data = data
    }
    
    return message
end

-- High-level message operations
function MessageManager:write_game_state(state_data)
    -- ADD COMPREHENSIVE DIAGNOSTIC LOGGING FOR STALE STATE DEBUG
    print("[DEBUG_STALE_STATE] MessageManager:write_game_state called")
    self:log("Attempting to write game state")
    
    if not state_data then
        self:log("ERROR: No state data provided")
        print("[DEBUG_STALE_STATE] *** WRITE_GAME_STATE FAILED - NO STATE DATA ***")
        return false
    end
    
    print("[DEBUG_STALE_STATE] State data received, checking transport availability")
    print("[DEBUG_STALE_STATE] Transport object: " .. tostring(self.transport))
    
    local transport_available = self.transport:is_available()
    print("[DEBUG_STALE_STATE] Transport available: " .. tostring(transport_available))
    
    if not transport_available then
        self:log("ERROR: Transport is not available")
        print("[DEBUG_STALE_STATE] *** WRITE_GAME_STATE FAILED - TRANSPORT NOT AVAILABLE ***")
        return false
    end
    
    print("[DEBUG_STALE_STATE] Creating message structure")
    local message = self:create_message(state_data, "game_state")
    self:log("Created message structure with sequence_id: " .. message.sequence_id)
    
    -- Encode message to JSON
    print("[DEBUG_STALE_STATE] Encoding message to JSON")
    local encode_success, encoded_data = pcall(self.json.encode, message)
    if not encode_success then
        self:log("ERROR: JSON encoding failed: " .. tostring(encoded_data))
        print("[DEBUG_STALE_STATE] *** JSON ENCODING FAILED ***")
        return false
    end
    
    self:log("JSON encoding successful, data length: " .. #encoded_data)
    print("[DEBUG_STALE_STATE] JSON encoded, calling transport:write_message")
    
    -- Use async transport write if available (fire-and-forget for game state)
    if self.transport.async_enabled then
        print("[DEBUG_STALE_STATE] Using async write for game state")
        local write_success = self.transport:write_message(encoded_data, "game_state", function(success)
            if success then
                print("[DEBUG_STALE_STATE] Async game state write completed successfully")
                -- Async verification
                self.transport:verify_message(encoded_data, "game_state", function(verify_success)
                    if verify_success then
                        print("[DEBUG_STALE_STATE] Async game state verification completed successfully")
                    else
                        print("[DEBUG_STALE_STATE] *** ASYNC GAME STATE VERIFICATION FAILED ***")
                    end
                end)
            else
                print("[DEBUG_STALE_STATE] *** ASYNC GAME STATE WRITE FAILED ***")
            end
        end)
        
        print("[DEBUG_STALE_STATE] Async write operation submitted: " .. tostring(write_success))
        return write_success
    else
        -- Fallback to synchronous operation
        print("[DEBUG_STALE_STATE] Using synchronous write for game state")
        local write_success = self.transport:write_message(encoded_data, "game_state")
        
        print("[DEBUG_STALE_STATE] Transport write_message result: " .. tostring(write_success))
        
        if not write_success then
            self:log("ERROR: Transport write failed")
            print("[DEBUG_STALE_STATE] *** TRANSPORT WRITE FAILED ***")
            return false
        end
        
        print("[DEBUG_STALE_STATE] Transport write successful, performing verification")
        
        -- Verify through transport
        local verify_success = self.transport:verify_message(encoded_data, "game_state")
        if not verify_success then
            self:log("ERROR: Message verification failed")
            print("[DEBUG_STALE_STATE] *** MESSAGE VERIFICATION FAILED ***")
            return false
        end
        
        self:log("Game state written and verified successfully")
        print("[DEBUG_STALE_STATE] *** WRITE_GAME_STATE COMPLETED SUCCESSFULLY ***")
        return true
    end
end

function MessageManager:write_deck_state(deck_data)
    self:log("Attempting to write deck state")
    
    if not deck_data then
        self:log("ERROR: No deck data provided")
        return false
    end
    
    if not self.transport:is_available() then
        self:log("ERROR: Transport is not available")
        return false
    end
    
    local message = self:create_message(deck_data, "deck_state")
    self:log("Created deck message structure with sequence_id: " .. message.sequence_id)
    
    -- Encode message to JSON
    local encode_success, encoded_data = pcall(self.json.encode, message)
    if not encode_success then
        self:log("ERROR: JSON encoding failed: " .. tostring(encoded_data))
        return false
    end
    
    self:log("JSON encoding successful, data length: " .. #encoded_data)
    
    -- Delegate to transport
    local write_success = self.transport:write_message(encoded_data, "deck_state")
    if not write_success then
        self:log("ERROR: Transport write failed")
        return false
    end
    
    -- Verify through transport
    local verify_success = self.transport:verify_message(encoded_data, "deck_state")
    if not verify_success then
        self:log("ERROR: Message verification failed")
        return false
    end
    
    self:log("Deck state written and verified successfully")
    return true
end
function MessageManager:write_remaining_deck(remaining_deck_data)
    self:log("Attempting to write remaining deck state")
    
    if not remaining_deck_data then
        self:log("ERROR: No remaining deck data provided")
        return false
    end
    
    if not self.transport:is_available() then
        self:log("ERROR: Transport is not available")
        return false
    end
    
    local message = self:create_message(remaining_deck_data, "remaining_deck")
    self:log("Created remaining deck message structure with sequence_id: " .. message.sequence_id)
    
    -- Encode message to JSON
    local encode_success, encoded_data = pcall(self.json.encode, message)
    if not encode_success then
        self:log("ERROR: JSON encoding failed: " .. tostring(encoded_data))
        return false
    end
    
    self:log("JSON encoding successful, data length: " .. #encoded_data)
    
    -- Delegate to transport
    local write_success = self.transport:write_message(encoded_data, "remaining_deck")
    if not write_success then
        self:log("ERROR: Transport write failed")
        return false
    end
    
    -- Verify through transport
    local verify_success = self.transport:verify_message(encoded_data, "remaining_deck")
    if not verify_success then
        self:log("ERROR: Message verification failed")
        return false
    end
    
    self:log("Remaining deck state written and verified successfully")
    return true
end

function MessageManager:read_actions()
    self:log("ACTION_POLLING - Checking transport availability")
    if not self.transport:is_available() then
        self:log("ERROR: Transport is not available for action polling")
        return nil
    end
    
    -- For action reading, we need synchronous behavior since the caller expects immediate response
    -- The async transport will use synchronous fallback when no callback is provided
    self:log("ACTION_POLLING - Calling transport:read_message('actions')")
    local message_data = self.transport:read_message("actions")
    if not message_data then
        self:log("ACTION_POLLING - No actions available from transport")
        return nil
    end
    
    self:log("ACTION_POLLING - Actions data received from transport")
    
    -- Decode JSON
    local decode_success, decoded_data = pcall(self.json.decode, message_data)
    if not decode_success then
        self:log("ERROR: Failed to parse actions JSON: " .. tostring(decoded_data))
        return nil
    end
    
    self:log("Actions read and decoded successfully")
    return decoded_data
end

function MessageManager:write_action_result(result_data)
    self:log("Attempting to write action result")
    
    if not result_data then
        self:log("ERROR: No result data provided")
        return false
    end
    
    if not self.transport:is_available() then
        self:log("ERROR: Transport is not available")
        return false
    end
    
    local message = self:create_message(result_data, "action_result")
    self:log("Created action result message with sequence_id: " .. message.sequence_id)
    
    -- Encode message to JSON
    local encode_success, encoded_data = pcall(self.json.encode, message)
    if not encode_success then
        self:log("ERROR: JSON encoding failed: " .. tostring(encoded_data))
        return false
    end
    
    self:log("JSON encoding successful, data length: " .. #encoded_data)
    
    -- Use async transport write if available (fire-and-forget for action results)
    if self.transport.async_enabled then
        self:log("Using async write for action result")
        local write_success = self.transport:write_message(encoded_data, "action_result", function(success)
            if success then
                self:log("Async action result write completed successfully")
            else
                self:log("ERROR: Async action result write failed")
            end
        end)
        return write_success
    else
        -- Fallback to synchronous operation
        local write_success = self.transport:write_message(encoded_data, "action_result")
        if not write_success then
            self:log("ERROR: Transport write failed")
            return false
        end
        
        self:log("Action result written successfully")
        return true
    end
end

function MessageManager:cleanup_old_messages(max_age_seconds)
    if not self.transport:is_available() then
        self:log("ERROR: Transport is not available for cleanup")
        return false
    end
    
    -- Use async cleanup if available (fire-and-forget)
    if self.transport.async_enabled then
        self:log("Using async cleanup")
        return self.transport:cleanup_old_messages(max_age_seconds, function(success, count)
            if success then
                self:log("Async cleanup completed: " .. (count or 0) .. " files removed")
            else
                self:log("ERROR: Async cleanup failed")
            end
        end)
    else
        -- Fallback to synchronous operation
        return self.transport:cleanup_old_messages(max_age_seconds)
    end
end

return MessageManager