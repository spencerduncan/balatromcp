-- File Transport - Concrete implementation of IMessageTransport for file-based I/O
-- Handles all file system operations, path management, and file verification
-- Follows Single Responsibility Principle - focused solely on file I/O operations

local FileTransport = {}
FileTransport.__index = FileTransport

function FileTransport.new(base_path)
    local self = setmetatable({}, FileTransport)
    -- Use relative path within mod directory (Love2D filesystem sandbox)
    self.base_path = base_path or "shared"
    self.last_read_sequences = {}
    self.component_name = "FILE_TRANSPORT"
    self.write_success_count = 0
    
    -- Load JSON library for verification operations
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
    
    -- Initialize and test filesystem
    self:initialize_filesystem()
    
    return self
end

function FileTransport:log(message)
    local log_msg = "BalatroMCP [" .. self.component_name .. "]: " .. message
    print(log_msg)
    
    -- Try to write to debug log if possible
    if love and love.filesystem and self.base_path then
        local success, err = pcall(function()
            local log_file = self:get_filepath("debug.log")
            local timestamp = os.date("%Y-%m-%d %H:%M:%S")
            local log_entry = "[" .. timestamp .. "] " .. message .. "\n"
            
            local existing_content = ""
            if love.filesystem.getInfo(log_file) then
                existing_content = love.filesystem.read(log_file) or ""
            end
            love.filesystem.write(log_file, existing_content .. log_entry)
        end)
        
        if not success then
            print("BalatroMCP [FILE_TRANSPORT]: Failed to write debug log: " .. tostring(err))
        end
    end
end

function FileTransport:initialize_filesystem()
    -- Test and log filesystem availability
    if love and love.filesystem then
        self:log("love.filesystem available")
        
        -- Test directory creation
        local dir_success = love.filesystem.createDirectory(self.base_path)
        if dir_success then
            self:log("Directory creation successful: " .. self.base_path)
        else
            self:log("ERROR: Directory creation failed: " .. self.base_path)
        end
        
        -- Test directory existence
        local dir_info = love.filesystem.getInfo(self.base_path)
        if dir_info and dir_info.type == "directory" then
            self:log("Directory confirmed to exist: " .. self.base_path)
        else
            self:log("ERROR: Directory does not exist after creation attempt")
        end
    else
        self:log("CRITICAL: love.filesystem not available - file operations will fail")
    end
end

-- Private method - constructs file path based on message type
function FileTransport:get_filepath(message_type)
    local filename_map = {
        game_state = "game_state.json",
        deck_state = "deck_state.json",
        actions = "actions.json",
        action_result = "action_results.json",
        ["debug.log"] = "file_transport_debug.log"
    }
    
    local filename = filename_map[message_type] or (message_type .. ".json")
    
    if self.base_path == "." then
        return filename
    else
        return self.base_path .. "/" .. filename
    end
end

-- IMessageTransport interface implementation
function FileTransport:is_available()
    return love and love.filesystem and true or false
end

function FileTransport:write_message(message_data, message_type)
    if not self:is_available() then
        self:log("ERROR: Filesystem not available")
        return false
    end
    
    if not message_data then
        self:log("ERROR: No message data provided")
        return false
    end
    
    if not message_type then
        self:log("ERROR: No message type provided")
        return false
    end
    
    local filepath = self:get_filepath(message_type)
    self:log("Writing to file: " .. filepath)
    
    local write_success = love.filesystem.write(filepath, message_data)
    
    if not write_success then
        self:log("ERROR: File write failed")
        self:diagnose_write_failure()
        return false
    end
    
    self:log("Message written successfully to: " .. filepath)
    
    -- Track successful writes
    self.write_success_count = self.write_success_count + 1
    self:log("DIAGNOSTIC: Total successful writes: " .. self.write_success_count)
    
    return true
end

function FileTransport:read_message(message_type)
    if not self:is_available() then
        self:log("ERROR: Filesystem not available")
        return nil
    end
    
    local filepath = self:get_filepath(message_type)
    
    if not love.filesystem.getInfo(filepath) then
        return nil
    end
    
    self:log(message_type .. " file exists, attempting to read")
    
    local content, size = love.filesystem.read(filepath)
    if not content then
        self:log("ERROR: Failed to read " .. message_type .. " file content")
        return nil
    end
    
    self:log(message_type .. " file read successfully, size: " .. (size or 0))
    
    -- For actions, handle sequence tracking and file removal
    if message_type == "actions" then
        -- Parse to check sequence
        local decode_success, data = pcall(self.json.decode, content)
        if not decode_success then
            self:log("ERROR: Failed to parse " .. message_type .. " JSON: " .. tostring(data))
            return nil
        end
        
        -- Check if this is a new message
        local sequence_id = data.sequence_id or 0
        local last_read = self.last_read_sequences[message_type] or 0
        
        self:log(message_type .. " sequence_id: " .. sequence_id .. ", last_read: " .. last_read)
        
        if sequence_id <= last_read then
            self:log(message_type .. " already processed, ignoring")
            return nil -- Already processed
        end
        
        self.last_read_sequences[message_type] = sequence_id
        self:log("Processing new " .. message_type .. " with sequence_id: " .. sequence_id)
        
        -- Remove the file after reading
        local remove_success = love.filesystem.remove(filepath)
        if remove_success then
            self:log(message_type .. " file removed successfully")
        else
            self:log("WARNING: Failed to remove " .. message_type .. " file")
        end
    end
    
    return content
end

function FileTransport:verify_message(message_data, message_type)
    if not self:is_available() then
        self:log("ERROR: Filesystem not available for verification")
        return false
    end
    
    local filepath = self:get_filepath(message_type)
    
    local verify_start_time = os.clock()
    local verify_content, verify_size = love.filesystem.read(filepath)
    local verify_end_time = os.clock()
    local verify_duration = verify_end_time - verify_start_time
    
    self:log("DIAGNOSTIC: File verification duration: " .. tostring(verify_duration) .. " seconds")
    
    if not verify_content then
        self:log("WARNING: File verification failed - file may be corrupted or missing")
        self:log("DIAGNOSTIC: This may cause file update cessation issue")
        return false
    end
    
    self:log("File verification successful, size: " .. (verify_size or 0))
    
    -- CORRUPTION CHECK: Verify JSON can be parsed back
    local parse_success, parsed_data = pcall(self.json.decode, verify_content)
    if not parse_success then
        self:log("ERROR: File content is corrupted JSON: " .. tostring(parsed_data))
        self:log("DIAGNOSTIC: Corrupted content preview: " .. string.sub(verify_content, 1, 100))
        return false
    end
    
    self:log("DIAGNOSTIC: File content is valid JSON")
    
    -- Verify content matches what was written
    local original_parse_success, original_data = pcall(self.json.decode, message_data)
    if original_parse_success and parsed_data.sequence_id == original_data.sequence_id then
        self:log("DIAGNOSTIC: Sequence ID matches - write integrity confirmed")
    else
        self:log("WARNING: Sequence ID mismatch - possible write corruption")
    end
    
    return true
end

function FileTransport:cleanup_old_messages(max_age_seconds)
    if not self:is_available() then
        self:log("ERROR: Filesystem not available for cleanup")
        return false
    end
    
    max_age_seconds = max_age_seconds or 300 -- 5 minutes default
    
    local files = {"game_state.json", "deck_state.json", "actions.json", "action_results.json"}
    local current_time = os.time()
    local cleanup_count = 0
    
    for _, filename in ipairs(files) do
        local filepath = self:get_filepath(filename:gsub("%.json$", ""))
        local info = love.filesystem.getInfo(filepath)
        
        if info and info.modtime then
            local age = current_time - info.modtime
            if age > max_age_seconds then
                local remove_success = love.filesystem.remove(filepath)
                if remove_success then
                    self:log("Cleaned up old file: " .. filename)
                    cleanup_count = cleanup_count + 1
                else
                    self:log("WARNING: Failed to remove old file: " .. filename)
                end
            end
        end
    end
    
    self:log("Cleanup completed: " .. cleanup_count .. " files removed")
    return true
end

-- Private method - diagnose write failures
function FileTransport:diagnose_write_failure()
    self:log("DIAGNOSTIC: Attempting to diagnose write failure...")
    
    -- Check directory permissions
    local dir_info = love.filesystem.getInfo(self.base_path or ".")
    if dir_info then
        self:log("DIAGNOSTIC: Base directory exists: " .. tostring(dir_info.type == "directory"))
    else
        self:log("DIAGNOSTIC: Base directory does not exist - attempting to create")
        local create_success = love.filesystem.createDirectory(self.base_path or ".")
        self:log("DIAGNOSTIC: Directory creation result: " .. tostring(create_success))
    end
    
    -- Check filesystem availability
    if love.filesystem.isFused() then
        self:log("DIAGNOSTIC: Running in fused mode - filesystem limited")
    else
        self:log("DIAGNOSTIC: Running in development mode - full filesystem access")
    end
end

return FileTransport