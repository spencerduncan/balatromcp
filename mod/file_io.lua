-- File I/O module for Balatro MCP mod
-- Handles communication through JSON files with the MCP server

local FileIO = {}
FileIO.__index = FileIO

function FileIO.new(base_path)
    local self = setmetatable({}, FileIO)
    self.base_path = base_path or "shared"
    self.sequence_id = 0
    self.last_read_sequences = {}
    
    -- Initialize debug logging for this component
    self.component_name = "FILE_IO"
    
    -- Initialize JSON handling with robust fallback
    self:_initialize_json()
    
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
    -- Simple logging for this component
    local log_msg = "BalatroMCP [" .. self.component_name .. "]: " .. message
    print(log_msg)
    
    -- Try to write to debug log if possible
    if love and love.filesystem and self.base_path then
        local success, err = pcall(function()
            local log_file = self.base_path .. "/file_io_debug.log"
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
-- Initialize JSON handling
function FileIO:_initialize_json()
    -- Load the main JSON library using Steammodded loading
    local json_success, json_result = pcall(function()
        return assert(SMODS.load_file("libs/json.lua"))()
    end)
    if json_success then
        self.json = json_result
        self:log("JSON library loaded successfully")
    else
        self:log("ERROR: JSON library failed to load: " .. tostring(json_result))
        error("Failed to load required JSON library via SMODS")
    end
end

function FileIO:get_next_sequence_id()
    self.sequence_id = self.sequence_id + 1
    return self.sequence_id
end

function FileIO:write_game_state(state_data)
    self:log("Attempting to write game state")
    
    -- Validate inputs
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
    
    -- Test JSON encoding
    local encode_success, encoded_data = pcall(self.json.encode, message)
    if not encode_success then
        self:log("ERROR: JSON encoding failed: " .. tostring(encoded_data))
        return false
    end
    
    self:log("JSON encoding successful, data length: " .. #encoded_data)
    
    local filepath = self.base_path .. "/game_state.json"
    self:log("Writing to file: " .. filepath)
    
    local write_success = love.filesystem.write(filepath, encoded_data)
    
    if not write_success then
        self:log("ERROR: File write failed")
        return false
    end
    
    self:log("Game state written successfully")
    
    -- Verify file was written correctly
    local verify_content, verify_size = love.filesystem.read(filepath)
    if verify_content then
        self:log("File verification successful, size: " .. (verify_size or 0))
    else
        self:log("WARNING: File verification failed")
    end
    
    return true
end

function FileIO:read_actions()
    self:log("Attempting to read actions")
    
    local filepath = self.base_path .. "/actions.json"
    self:log("Looking for actions file: " .. filepath)
    
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
    
    return data.data
end

function FileIO:write_action_result(result_data)
    self:log("Attempting to write action result")
    
    -- Validate inputs
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
    
    -- Test JSON encoding with proper error handling
    local encode_success, encoded_data = pcall(self.json.encode, message)
    if not encode_success then
        self:log("ERROR: JSON encoding failed: " .. tostring(encoded_data))
        return false
    end
    
    self:log("JSON encoding successful, data length: " .. #encoded_data)
    
    local filepath = self.base_path .. "/action_results.json"
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
        local filepath = self.base_path .. "/" .. filename
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