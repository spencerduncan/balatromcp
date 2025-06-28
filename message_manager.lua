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
    if not state_data then
        return false
    end
    
    if not self.transport:is_available() then
        return false
    end
    
    -- Create message structure and encode to JSON
    local message = self:create_message(state_data, "game_state")
    local encode_success, encoded_data = pcall(self.json.encode, message)
    if not encode_success then
        return false
    end
    
    -- Pass pre-encoded JSON to async transport
    if self.transport.async_enabled then
        return self.transport:write_message(encoded_data, "game_state")
    else
        -- Synchronous fallback
        local write_success = self.transport:write_message(encoded_data, "game_state")
        if not write_success then
            return false
        end
        
        return self.transport:verify_message(encoded_data, "game_state")
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

function MessageManager:write_full_deck(full_deck_data)
    self:log("Attempting to write full deck state")
    
    if not full_deck_data then
        self:log("ERROR: No full deck data provided")
        return false
    end
    
    if not self.transport:is_available() then
        self:log("ERROR: Transport is not available")
        return false
    end
    
    local message = self:create_message(full_deck_data, "full_deck")
    self:log("Created full deck message structure with sequence_id: " .. message.sequence_id)
    
    -- Encode message to JSON
    local encode_success, encoded_data = pcall(self.json.encode, message)
    if not encode_success then
        self:log("ERROR: JSON encoding failed: " .. tostring(encoded_data))
        return false
    end
    
    self:log("JSON encoding successful, data length: " .. #encoded_data)
    
    -- Delegate to transport
    local write_success = self.transport:write_message(encoded_data, "full_deck")
    if not write_success then
        self:log("ERROR: Transport write failed")
        return false
    end
    
    -- Verify through transport
    local verify_success = self.transport:verify_message(encoded_data, "full_deck")
    if not verify_success then
        self:log("ERROR: Message verification failed")
        return false
    end
    
    self:log("Full deck state written and verified successfully")
    return true
end

function MessageManager:write_hand_levels(hand_levels_data)
    self:log("Attempting to write hand levels state")
    
    if not hand_levels_data then
        self:log("ERROR: No hand levels data provided")
        return false
    end
    
    if not self.transport:is_available() then
        self:log("ERROR: Transport is not available")
        return false
    end
    
    -- Create message structure that matches the JSON specification
    local hand_levels_message = {
        session_id = hand_levels_data.session_id or "session_unknown",
        timestamp = os.time(),
        total_hands_played = self:calculate_total_hands_played(hand_levels_data.hand_levels),
        hands = hand_levels_data.hand_levels or {}
    }
    
    self:log("Created hand levels message structure")
    
    -- Encode message to JSON
    local encode_success, encoded_data = pcall(self.json.encode, hand_levels_message)
    if not encode_success then
        self:log("ERROR: JSON encoding failed: " .. tostring(encoded_data))
        return false
    end
    
    self:log("JSON encoding successful, data length: " .. #encoded_data)
    
    -- Use async transport write if available
    if self.transport.async_enabled then
        self:log("Using async write for hand levels")
        local write_success = self.transport:write_message(encoded_data, "hand_levels", function(success)
            if success then
                self:log("Async hand levels write completed successfully")
            else
                self:log("ERROR: Async hand levels write failed")
            end
        end)
        return write_success
    else
        -- Fallback to synchronous operation
        local write_success = self.transport:write_message(encoded_data, "hand_levels")
        if not write_success then
            self:log("ERROR: Transport write failed")
            return false
        end
        
        -- Verify through transport
        local verify_success = self.transport:verify_message(encoded_data, "hand_levels")
        if not verify_success then
            self:log("ERROR: Message verification failed")
            return false
        end
        
        self:log("Hand levels state written and verified successfully")
        return true
    end
end

function MessageManager:calculate_total_hands_played(hands_data)
    if not hands_data or type(hands_data) ~= "table" then
        return 0
    end
    
    local total = 0
    for hand_name, hand_info in pairs(hands_data) do
        if hand_info and hand_info.times_played then
            total = total + hand_info.times_played
        end
    end
    
    return total
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

function MessageManager:write_vouchers_ante(vouchers_ante_data)
    self:log("Attempting to write vouchers ante data")
    
    if not vouchers_ante_data then
        self:log("ERROR: No vouchers ante data provided")
        return false
    end
    
    if not self.transport:is_available() then
        self:log("ERROR: Transport is not available")
        return false
    end
    
    local message = self:create_message(vouchers_ante_data, "vouchers_ante")
    self:log("Created vouchers ante message structure with sequence_id: " .. message.sequence_id)
    
    -- Encode message to JSON
    local encode_success, encoded_data = pcall(self.json.encode, message)
    if not encode_success then
        self:log("ERROR: JSON encoding failed: " .. tostring(encoded_data))
        return false
    end
    
    self:log("JSON encoding successful, data length: " .. #encoded_data)
    
    -- Delegate to transport
    local write_success = self.transport:write_message(encoded_data, "vouchers_ante")
    if not write_success then
        self:log("ERROR: Transport write failed")
        return false
    end
    
    -- Verify through transport
    local verify_success = self.transport:verify_message(encoded_data, "vouchers_ante")
    if not verify_success then
        self:log("ERROR: Message verification failed")
        return false
    end
    
    self:log("Vouchers ante data written and verified successfully")
    return true
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