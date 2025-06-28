-- File Transport - Concrete implementation of IMessageTransport for file-based I/O
-- Handles all file system operations, path management, and file verification
-- Follows Single Responsibility Principle - focused solely on file I/O operations

local FileTransport = {}
FileTransport.__index = FileTransport

-- Thread code for async file operations
local FILE_WORKER_CODE = [[
local love = require('love')
require('love.filesystem')

-- Worker thread for handling file operations
local request_channel = love.thread.getChannel('file_requests')
local response_channel = love.thread.getChannel('file_responses')

while true do
    local request = request_channel:demand()
    if request.operation == 'exit' then
        break
    end
    
    local response = {
        id = request.id,
        operation = request.operation,
        success = false,
        data = nil,
        error = nil
    }
    
    local ok, result = pcall(function()
        if request.operation == 'read' then
            return love.filesystem.read(request.filepath)
        elseif request.operation == 'write' then
            return love.filesystem.write(request.filepath, request.content)
        elseif request.operation == 'remove' then
            return love.filesystem.remove(request.filepath)
        elseif request.operation == 'getInfo' then
            return love.filesystem.getInfo(request.filepath)
        elseif request.operation == 'createDirectory' then
            return love.filesystem.createDirectory(request.filepath)
        else
            error("Unknown operation: " .. tostring(request.operation))
        end
    end)
    
    if ok then
        response.success = true
        response.data = result
    else
        response.success = false
        response.error = tostring(result)
    end
    
    response_channel:push(response)
end
]]

function FileTransport.new(base_path)
    local self = setmetatable({}, FileTransport)
    -- Use relative path within mod directory (Love2D filesystem sandbox)
    self.base_path = base_path or "shared"
    self.last_read_sequences = {}
    self.component_name = "FILE_TRANSPORT"
    self.write_success_count = 0
    
    -- Async operation tracking
    self.async_enabled = false
    self.request_id_counter = 0
    self.pending_requests = {}
    self.worker_thread = nil
    self.request_channel = nil
    self.response_channel = nil
    
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
    
    -- Initialize async if available
    self:initialize_async()
    
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

function FileTransport:initialize_async()
    -- Check if threading is available
    if not (love and love.thread) then
        self:log("Threading not available - using synchronous operations")
        return
    end
    
    -- Create communication channels
    self.request_channel = love.thread.getChannel('file_requests')
    self.response_channel = love.thread.getChannel('file_responses')
    
    -- Create worker thread
    local success, thread_or_error = pcall(love.thread.newThread, FILE_WORKER_CODE)
    if not success then
        self:log("Failed to create worker thread: " .. tostring(thread_or_error))
        return
    end
    
    self.worker_thread = thread_or_error
    self.worker_thread:start()
    
    self.async_enabled = true
    self:log("Async file operations initialized")
end

-- Private method - constructs file path based on message type
function FileTransport:get_filepath(message_type)
    local filename_map = {
        game_state = "game_state.json",
        deck_state = "deck_state.json",
        remaining_deck = "remaining_deck.json",
        full_deck = "full_deck.json",
        hand_levels = "hand_levels.json",
        vouchers_ante = "vouchers_ante.json",
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

-- Async operation helpers
function FileTransport:submit_async_request(operation, params, callback)
    if not self.async_enabled then
        -- Fallback to synchronous operation
        return self:execute_sync_operation(operation, params, callback)
    end
    
    self.request_id_counter = self.request_id_counter + 1
    local request_id = self.request_id_counter
    
    local request = {
        id = request_id,
        operation = operation,
        filepath = params.filepath,
        content = params.content
    }
    
    -- Store the callback
    self.pending_requests[request_id] = {
        callback = callback,
        submitted_time = os.clock()
    }
    
    -- Submit to worker thread
    self.request_channel:push(request)
    
    return request_id
end

function FileTransport:execute_sync_operation(operation, params, callback)
    local success, result = pcall(function()
        if operation == 'read' then
            return love.filesystem.read(params.filepath)
        elseif operation == 'write' then
            return love.filesystem.write(params.filepath, params.content)
        elseif operation == 'remove' then
            return love.filesystem.remove(params.filepath)
        elseif operation == 'getInfo' then
            return love.filesystem.getInfo(params.filepath)
        elseif operation == 'createDirectory' then
            return love.filesystem.createDirectory(params.filepath)
        else
            error("Unknown operation: " .. tostring(operation))
        end
    end)
    
    if callback then
        callback(success, result)
    end
    
    return success, result
end

function FileTransport:process_async_responses()
    if not self.async_enabled then
        return
    end
    
    -- Process all available responses
    while true do
        local response = self.response_channel:pop()
        if not response then
            break
        end
        
        local pending = self.pending_requests[response.id]
        if pending then
            -- Track successful write operations
            if response.success and response.operation == 'write' then
                self.write_success_count = self.write_success_count + 1
            end
            
            if pending.callback then
                pending.callback(response.success, response.data, response.error)
            end
        end
        
        self.pending_requests[response.id] = nil
    end
end

function FileTransport:update()
    -- Process async responses
    self:process_async_responses()
    
    -- Clean up old pending requests (timeout after 30 seconds)
    local current_time = os.clock()
    for id, request in pairs(self.pending_requests) do
        if current_time - request.submitted_time > 30 then
            self:log("WARNING: Async request " .. id .. " timed out")
            if request.callback then
                request.callback(false, nil, "Request timed out")
            end
            self.pending_requests[id] = nil
        end
    end
end

function FileTransport:cleanup()
    if self.async_enabled and self.worker_thread then
        -- Send exit signal to worker thread
        self.request_channel:push({operation = 'exit'})
        
        -- Wait for thread to finish (with timeout)
        local start_time = os.clock()
        while self.worker_thread:isRunning() and (os.clock() - start_time) < 5 do
            love.timer.sleep(0.01)
        end
        
        self.worker_thread = nil
        self.async_enabled = false
        self:log("Async worker thread cleaned up")
    end
end

-- IMessageTransport interface implementation
function FileTransport:is_available()
    return love and love.filesystem and true or false
end

function FileTransport:write_message(message_data, message_type, callback)
    if not self:is_available() then
        if callback then callback(false) end
        return false
    end
    
    if not message_data or not message_type then
        if callback then callback(false) end
        return false
    end
    
    local filepath = self:get_filepath(message_type)
    
    -- If async is enabled and callback provided, use async
    if self.async_enabled and callback then
        local request_id = self:submit_async_request('write', {
            filepath = filepath,
            content = message_data
        }, callback)
        
        return true -- Request submitted
    else
        -- Synchronous fallback
        local write_success = love.filesystem.write(filepath, message_data)
        if write_success then
            self.write_success_count = self.write_success_count + 1
        end
        if callback then callback(write_success) end
        return write_success
    end
end

function FileTransport:read_message(message_type, callback)
    if not self:is_available() then
        self:log("ERROR: Filesystem not available")
        if callback then callback(false, nil) end
        return nil
    end
    
    local filepath = self:get_filepath(message_type)
    
    -- If async is enabled and callback provided, use async
    if self.async_enabled and callback then
        -- First check if file exists async
        self:submit_async_request('getInfo', {
            filepath = filepath
        }, function(success, info, error)
            if not success or not info then
                callback(true, nil) -- File doesn't exist, not an error
                return
            end
            
            self:log(message_type .. " file exists, attempting to read")
            
            -- Read the file async
            self:submit_async_request('read', {
                filepath = filepath
            }, function(read_success, content, read_error)
                if not read_success then
                    self:log("ERROR: Failed to read " .. message_type .. " file content: " .. tostring(read_error))
                    callback(false, nil)
                    return
                end
                
                self:log(message_type .. " file read successfully, size: " .. string.len(content or ""))
                
                -- For actions, handle sequence tracking and file removal
                if message_type == "actions" then
                    -- Parse to check sequence
                    local decode_success, data = pcall(self.json.decode, content)
                    if not decode_success then
                        self:log("ERROR: Failed to parse " .. message_type .. " JSON: " .. tostring(data))
                        callback(false, nil)
                        return
                    end
                    
                    -- Check if this is a new message
                    local sequence_id = data.sequence_id or 0
                    local last_read = self.last_read_sequences[message_type] or 0
                    
                    self:log(message_type .. " sequence_id: " .. sequence_id .. ", last_read: " .. last_read)
                    
                    if sequence_id <= last_read then
                        self:log(message_type .. " already processed, ignoring")
                        callback(true, nil) -- Already processed
                        return
                    end
                    
                    self.last_read_sequences[message_type] = sequence_id
                    self:log("Processing new " .. message_type .. " with sequence_id: " .. sequence_id)
                    
                    -- Remove the file after reading async
                    self:submit_async_request('remove', {
                        filepath = filepath
                    }, function(remove_success, _, remove_error)
                        if remove_success then
                            self:log(message_type .. " file removed successfully")
                        else
                            self:log("WARNING: Failed to remove " .. message_type .. " file: " .. tostring(remove_error))
                        end
                    end)
                end
                
                callback(true, content)
            end)
        end)
        
        return nil -- Async operation initiated
    else
        -- Synchronous fallback
        if not love.filesystem.getInfo(filepath) then
            if callback then callback(true, nil) end
            return nil
        end
        
        self:log(message_type .. " file exists, attempting to read")
        
        local content, size = love.filesystem.read(filepath)
        if not content then
            self:log("ERROR: Failed to read " .. message_type .. " file content")
            if callback then callback(false, nil) end
            return nil
        end
        
        self:log(message_type .. " file read successfully, size: " .. (size or 0))
        
        -- For actions, handle sequence tracking and file removal
        if message_type == "actions" then
            -- Parse to check sequence
            local decode_success, data = pcall(self.json.decode, content)
            if not decode_success then
                self:log("ERROR: Failed to parse " .. message_type .. " JSON: " .. tostring(data))
                if callback then callback(false, nil) end
                return nil
            end
            
            -- Check if this is a new message
            local sequence_id = data.sequence_id or 0
            local last_read = self.last_read_sequences[message_type] or 0
            
            self:log(message_type .. " sequence_id: " .. sequence_id .. ", last_read: " .. last_read)
            
            if sequence_id <= last_read then
                self:log(message_type .. " already processed, ignoring")
                if callback then callback(true, nil) end
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
        
        if callback then callback(true, content) end
        return content
    end
end

function FileTransport:verify_message(message_data, message_type, callback)
    if not self:is_available() then
        self:log("ERROR: Filesystem not available for verification")
        if callback then callback(false) end
        return false
    end
    
    local filepath = self:get_filepath(message_type)
    
    -- If async is enabled and callback provided, use async
    if self.async_enabled and callback then
        local verify_start_time = os.clock()
        
        self:submit_async_request('read', {
            filepath = filepath
        }, function(success, verify_content, error)
            local verify_end_time = os.clock()
            local verify_duration = verify_end_time - verify_start_time
            
            self:log("DIAGNOSTIC: Async file verification duration: " .. tostring(verify_duration) .. " seconds")
            
            if not success or not verify_content then
                self:log("WARNING: File verification failed - file may be corrupted or missing: " .. tostring(error))
                self:log("DIAGNOSTIC: This may cause file update cessation issue")
                callback(false)
                return
            end
            
            self:log("File verification successful, size: " .. string.len(verify_content or ""))
            
            -- CORRUPTION CHECK: Verify JSON can be parsed back
            local parse_success, parsed_data = pcall(self.json.decode, verify_content)
            if not parse_success then
                self:log("ERROR: File content is corrupted JSON: " .. tostring(parsed_data))
                self:log("DIAGNOSTIC: Corrupted content preview: " .. string.sub(verify_content, 1, 100))
                callback(false)
                return
            end
            
            self:log("DIAGNOSTIC: File content is valid JSON")
            
            -- Verify content matches what was written
            local original_parse_success, original_data = pcall(self.json.decode, message_data)
            if original_parse_success and parsed_data.sequence_id == original_data.sequence_id then
                self:log("DIAGNOSTIC: Sequence ID matches - write integrity confirmed")
            else
                self:log("WARNING: Sequence ID mismatch - possible write corruption")
            end
            
            callback(true)
        end)
        
        return true -- Async operation initiated
    else
        -- Synchronous fallback
        local verify_start_time = os.clock()
        local verify_content, verify_size = love.filesystem.read(filepath)
        local verify_end_time = os.clock()
        local verify_duration = verify_end_time - verify_start_time
        
        self:log("DIAGNOSTIC: File verification duration: " .. tostring(verify_duration) .. " seconds")
        
        if not verify_content then
            self:log("WARNING: File verification failed - file may be corrupted or missing")
            self:log("DIAGNOSTIC: This may cause file update cessation issue")
            if callback then callback(false) end
            return false
        end
        
        self:log("File verification successful, size: " .. (verify_size or 0))
        
        -- CORRUPTION CHECK: Verify JSON can be parsed back
        local parse_success, parsed_data = pcall(self.json.decode, verify_content)
        if not parse_success then
            self:log("ERROR: File content is corrupted JSON: " .. tostring(parsed_data))
            self:log("DIAGNOSTIC: Corrupted content preview: " .. string.sub(verify_content, 1, 100))
            if callback then callback(false) end
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
        
        if callback then callback(true) end
        return true
    end
end

function FileTransport:cleanup_old_messages(max_age_seconds, callback)
    if not self:is_available() then
        self:log("ERROR: Filesystem not available for cleanup")
        if callback then callback(false) end
        return false
    end
    
    max_age_seconds = max_age_seconds or 300 -- 5 minutes default
    
    local files = {"game_state.json", "deck_state.json", "remaining_deck.json", "full_deck.json", "hand_levels.json", "actions.json", "action_results.json"}
    local current_time = os.time()
    local cleanup_count = 0
    local files_to_check = #files
    local checked_count = 0
    
    -- If async is enabled and callback provided, use async
    if self.async_enabled and callback then
        local function check_complete()
            checked_count = checked_count + 1
            if checked_count >= files_to_check then
                self:log("Async cleanup completed: " .. cleanup_count .. " files removed")
                callback(true, cleanup_count)
            end
        end
        
        for _, filename in ipairs(files) do
            local filepath = self:get_filepath(filename:gsub("%.json$", ""))
            
            self:submit_async_request('getInfo', {
                filepath = filepath
            }, function(success, info, error)
                if success and info and info.modtime then
                    local age = current_time - info.modtime
                    if age > max_age_seconds then
                        self:submit_async_request('remove', {
                            filepath = filepath
                        }, function(remove_success, _, remove_error)
                            if remove_success then
                                self:log("Cleaned up old file: " .. filename)
                                cleanup_count = cleanup_count + 1
                            else
                                self:log("WARNING: Failed to remove old file: " .. filename .. " - " .. tostring(remove_error))
                            end
                            check_complete()
                        end)
                    else
                        check_complete()
                    end
                else
                    check_complete()
                end
            end)
        end
        
        return true -- Async operation initiated
    else
        -- Synchronous fallback
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
        if callback then callback(true, cleanup_count) end
        return true
    end
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