-- File I/O module for Balatro MCP mod
-- Handles communication through JSON files with the MCP server

local FileIO = {}
FileIO.__index = FileIO

function FileIO.new(base_path)
    local self = setmetatable({}, FileIO)
    -- Use relative path within mod directory (Love2D filesystem sandbox)
    self.base_path = base_path or "shared"
    self.sequence_id = 0
    self.last_read_sequences = {}
    
    -- Initialize debug logging for this component
    self.component_name = "FILE_IO"
    
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
    
    return self
end

function FileIO:log(message)
    local log_msg = "BalatroMCP [" .. self.component_name .. "]: " .. message
    print(log_msg)
    
    -- Try to write to debug log if possible
    if love and love.filesystem and self.base_path then
        local success, err = pcall(function()
            -- Handle path construction for current directory vs subdirectory
            local log_file
            if self.base_path == "." then
                log_file = "file_io_debug.log"
            else
                log_file = self.base_path .. "/file_io_debug.log"
            end
            
            local timestamp = os.date("%Y-%m-%d %H:%M:%S")
            local log_entry = "[" .. timestamp .. "] " .. message .. "\n"
            
            local existing_content = ""
            if love.filesystem.getInfo(log_file) then
                existing_content = love.filesystem.read(log_file) or ""
            end
            love.filesystem.write(log_file, existing_content .. log_entry)
        end)
        
        if not success then
            print("BalatroMCP [FILE_IO]: Failed to write debug log: " .. tostring(err))
        end
    end
end

function FileIO:get_next_sequence_id()
    self.sequence_id = self.sequence_id + 1
    return self.sequence_id
end

function FileIO:write_game_state(state_data)
    self:log("Attempting to write game state")
    
    local filepath
    if self.base_path == "." then
        filepath = "game_state.json"
    else
        filepath = self.base_path .. "/game_state.json"
    end
    
    if not state_data then
        self:log("ERROR: No state data provided")
        return false
    end
    
    if not self.json then
        self:log("ERROR: No JSON library available for encoding")
        return false
    end
    
    if not love or not love.filesystem then
        self:log("ERROR: love.filesystem not available")
        return false
    end
    
    local message = {
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        sequence_id = self:get_next_sequence_id(),
        message_type = "game_state",
        data = state_data
    }
    
    self:log("Created message structure with sequence_id: " .. message.sequence_id)
    
    -- Test JSON encoding with enhanced error reporting
    local encode_success, encoded_data = pcall(self.json.encode, message)
    if not encode_success then
        self:log("ERROR: JSON encoding failed: " .. tostring(encoded_data))
        return false
    end
    
    self:log("JSON encoding successful, data length: " .. #encoded_data)
    
    self:log("Writing to file: " .. filepath)
    
    local write_success = love.filesystem.write(filepath, encoded_data)
    
    if not write_success then
        self:log("ERROR: File write failed")
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
        
        return false
    end
    
    self:log("Game state written successfully")
    
    -- ENHANCED VERIFICATION with corruption detection
    local verify_start_time = os.clock()
    local verify_content, verify_size = love.filesystem.read(filepath)
    local verify_end_time = os.clock()
    local verify_duration = verify_end_time - verify_start_time
    
    self:log("DIAGNOSTIC: File verification duration: " .. tostring(verify_duration) .. " seconds")
    
    if verify_content then
        self:log("File verification successful, size: " .. (verify_size or 0))
        
        -- CORRUPTION CHECK: Verify JSON can be parsed back
        local parse_success, parsed_data = pcall(self.json.decode, verify_content)
        if parse_success then
            self:log("DIAGNOSTIC: File content is valid JSON")
            if parsed_data.sequence_id == message.sequence_id then
                self:log("DIAGNOSTIC: Sequence ID matches - write integrity confirmed")
            else
                self:log("WARNING: Sequence ID mismatch - possible write corruption")
            end
        else
            self:log("ERROR: File content is corrupted JSON: " .. tostring(parsed_data))
            self:log("DIAGNOSTIC: Corrupted content preview: " .. string.sub(verify_content, 1, 100))
            return false
        end
    else
        self:log("WARNING: File verification failed - file may be corrupted or missing")
        self:log("DIAGNOSTIC: This may cause file update cessation issue")
        return false
    end
    
    -- PERSISTENCE TRACKING: Log successful write for monitoring
    if not self.write_success_count then
        self.write_success_count = 0
    end
    self.write_success_count = self.write_success_count + 1
    self:log("DIAGNOSTIC: Total successful writes: " .. self.write_success_count)
    
    return true
end

function FileIO:read_actions()
    
    -- Handle path construction for current directory vs subdirectory
    local filepath
    if self.base_path == "." then
        filepath = "actions.json"
    else
        filepath = self.base_path .. "/actions.json"
    end
    
    if not love or not love.filesystem then
        self:log("ERROR: love.filesystem not available")
        return nil
    end
    
    if not love.filesystem.getInfo(filepath) then
        self:log("No actions file found (this is normal)")
        return nil
    end
    
    self:log("Actions file exists, attempting to read")
    
    local content, size = love.filesystem.read(filepath)
    if not content then
        self:log("ERROR: Failed to read actions file content")
        return nil
    end
    
    self:log("Actions file read successfully, size: " .. (size or 0))
    
    if not self.json then
        self:log("ERROR: No JSON library available for decoding")
        return nil
    end
    
    local decode_success, data = pcall(self.json.decode, content)
    if not decode_success then
        self:log("ERROR: Failed to parse actions.json: " .. tostring(data))
        return nil
    end
    
    self:log("Actions JSON decoded successfully")
    
    -- Check if this is a new message
    local sequence_id = data.sequence_id or 0
    local last_read = self.last_read_sequences.actions or 0
    
    self:log("Action sequence_id: " .. sequence_id .. ", last_read: " .. last_read)
    
    if sequence_id <= last_read then
        self:log("Action already processed, ignoring")
        return nil -- Already processed
    end
    
    self.last_read_sequences.actions = sequence_id
    self:log("Processing new action with sequence_id: " .. sequence_id)
    
    -- Remove the file after reading
    local remove_success = love.filesystem.remove(filepath)
    if remove_success then
        self:log("Actions file removed successfully")
    else
        self:log("WARNING: Failed to remove actions file")
    end
    
    return data
end

function FileIO:write_action_result(result_data)
    self:log("Attempting to write action result")
    
    if not result_data then
        self:log("ERROR: No result data provided")
        return false
    end
    
    if not self.json then
        self:log("ERROR: No JSON library available for encoding")
        return false
    end
    
    if not love or not love.filesystem then
        self:log("ERROR: love.filesystem not available")
        return false
    end
    
    local message = {
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        sequence_id = self:get_next_sequence_id(),
        message_type = "action_result",
        data = result_data
    }
    
    self:log("Created action result message with sequence_id: " .. message.sequence_id)
    
    local encode_success, encoded_data = pcall(self.json.encode, message)
    if not encode_success then
        self:log("ERROR: JSON encoding failed: " .. tostring(encoded_data))
        return false
    end
    
    self:log("JSON encoding successful, data length: " .. #encoded_data)
    
    -- Handle path construction for current directory vs subdirectory
    local filepath
    if self.base_path == "." then
        filepath = "action_results.json"
    else
        filepath = self.base_path .. "/action_results.json"
    end
    self:log("Writing to file: " .. filepath)
    
    local write_success = love.filesystem.write(filepath, encoded_data)
    
    if not write_success then
        self:log("ERROR: Failed to write action result")
        return false
    end
    
    self:log("Action result written successfully")
    return true
end

function FileIO:cleanup_old_files(max_age_seconds)
    max_age_seconds = max_age_seconds or 300 -- 5 minutes default
    
    local files = {"game_state.json", "actions.json", "action_results.json"}
    local current_time = os.time()
    
    for _, filename in ipairs(files) do
        -- Handle path construction for current directory vs subdirectory
        local filepath
        if self.base_path == "." then
            filepath = filename
        else
            filepath = self.base_path .. "/" .. filename
        end
        local info = love.filesystem.getInfo(filepath)
        
        if info and info.modtime then
            local age = current_time - info.modtime
            if age > max_age_seconds then
                love.filesystem.remove(filepath)
                print("BalatroMCP: Cleaned up old file: " .. filename)
            end
        end
    end
end

return FileIO