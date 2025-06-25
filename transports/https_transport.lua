-- HTTPS Transport - Concrete implementation of IMessageTransport for HTTPS-based I/O
-- Handles all HTTP operations, endpoint management, and network communication
-- Follows Single Responsibility Principle - focused solely on HTTPS I/O operations
-- Uses SMODS.https for reliable HTTP operations in Balatro environment

local HttpsTransport = {}
HttpsTransport.__index = HttpsTransport

function HttpsTransport.new(config)
    local self = setmetatable({}, HttpsTransport)
    
    -- Validate and set configuration
    if not config or type(config) ~= "table" then
        error("HttpsTransport requires a configuration table")
    end
    
    if not config.base_url or type(config.base_url) ~= "string" then
        error("HttpsTransport requires a valid base_url in configuration")
    end
    
    self.base_url = config.base_url:gsub("/$", "") -- Remove trailing slash
    self.game_data_endpoint = config.game_data_endpoint or "/game-data"
    self.actions_endpoint = config.actions_endpoint or "/actions"
    self.timeout = config.timeout or 5
    self.headers = config.headers or {}
    self.last_read_sequences = {}
    self.component_name = "HTTPS_TRANSPORT"
    self.request_count = 0
    
    -- Cached results for interface compatibility
    self.cached_availability = nil
    self.cached_availability_time = 0
    self.availability_cache_duration = 30 -- Cache for 30 seconds
    
    -- Load required libraries
    self:initialize_libraries()
    
    return self
end

function HttpsTransport:initialize_libraries()
    -- Load JSON library using SMODS
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
    
    -- Check for SMODS.https availability
    self.http_client = require("SMODS.https")
    if SMODS and self.http_client then
        self:log("SMODS.https available - HTTP operations enabled")
    else
        error("SMODS.https not available - HTTPS transport cannot function")
    end
    
    self:log("HTTPS transport initialized with base URL: " .. self.base_url .. " (using SMODS.https)")
end

function HttpsTransport:log(message)
    local log_msg = "[G] BalatroMCP [" .. self.component_name .. "]: " .. message
    print(log_msg)
    
    -- Try to write to debug log if possible
    if love and love.filesystem then
        local success, err = pcall(function()
            local log_file = "shared/https_transport_debug.log"
            local timestamp = os.date("%Y-%m-%d %H:%M:%S")
            local log_entry = "[" .. timestamp .. "] " .. message .. "\n"
            
            local existing_content = ""
            if love.filesystem.getInfo(log_file) then
                existing_content = love.filesystem.read(log_file) or ""
            end
            love.filesystem.write(log_file, existing_content .. log_entry)
        end)
        
        if not success then
            print("[G] BalatroMCP [HTTPS_TRANSPORT]: Failed to write debug log: " .. tostring(err))
        end
    end
end

-- Private method - construct full URL for endpoint
function HttpsTransport:get_endpoint_url(endpoint)
    return self.base_url .. endpoint
end

-- Private method - prepare HTTP headers
function HttpsTransport:prepare_headers(additional_headers)
    local headers = {
        ["Content-Type"] = "application/json",
        ["User-Agent"] = "BalatroMCP/1.0"
    }
    
    -- Add configured headers
    for key, value in pairs(self.headers) do
        headers[key] = value
    end
    
    -- Add any additional headers
    if additional_headers then
        for key, value in pairs(additional_headers) do
            headers[key] = value
        end
    end
    
    return headers
end

-- Private method - make HTTP request using SMODS.https
function HttpsTransport:make_request(method, url, body, headers)
    self.request_count = self.request_count + 1
    local request_id = self.request_count
    
    self:log("Making " .. method .. " request #" .. request_id .. " to: " .. url)
    print("[DEBUG_STALE_STATE] HttpsTransport:make_request - " .. method .. " to " .. url)
    
    local start_time = os.clock()
    
    -- Prepare SMODS.https request options
    local options = {
        method = method,
        headers = headers
    }
    
    -- Add body for POST requests
    if method == "POST" and body then
        options.data = body
    end
    
    -- Make the HTTP request using SMODS.https (url, options)
    print("[DEBUG_STALE_STATE] Calling SMODS.https.request with URL: " .. url)
    print("[DEBUG_STALE_STATE] HTTP client available: " .. tostring(self.http_client ~= nil))
    
    local success, status_code, response_body, response_headers = pcall(self.http_client.request, url, options)
    
    local end_time = os.clock()
    local duration = end_time - start_time
    
    print("[DEBUG_STALE_STATE] SMODS.https.request result - success: " .. tostring(success) .. ", status: " .. tostring(status_code))
    
    if not success then
        self:log("ERROR: HTTP request failed: " .. tostring(status_code))
        print("[DEBUG_STALE_STATE] *** SMODS.https.request FAILED ***")
        return nil, "request_failed"
    end
    
    -- SMODS.https returns: code, body, headers
    if not status_code then
        self:log("ERROR: No status code received")
        return nil, "no_response"
    end
    
    self:log("Request #" .. request_id .. " completed in " .. string.format("%.3f", duration) .. "s, status: " .. tostring(status_code))
    
    -- Check for successful HTTP status codes
    if status_code < 200 or status_code >= 300 then
        self:log("ERROR: HTTP request returned error status: " .. status_code)
        if response_body then
            self:log("Response body: " .. string.sub(tostring(response_body), 1, 200))
        end
        return nil, status_code
    end
    
    return response_body or "", status_code, response_headers
end

-- IMessageTransport interface implementation
function HttpsTransport:is_available()
    -- Check cached availability to prevent frequent blocking calls
    local current_time = os.time()
    if self.cached_availability ~= nil and (current_time - self.cached_availability_time) < self.availability_cache_duration then
        return self.cached_availability
    end
    
    -- Test connectivity with a lightweight request
    local test_url = self:get_endpoint_url("/health")
    local headers = self:prepare_headers()
    
    local start_time = os.clock()
    local response, status_code = self:make_request("GET", test_url, nil, headers)
    local end_time = os.clock()
    
    -- 404 is acceptable (no health endpoint), so check status directly
    local available = (response ~= nil and status_code == 200) or status_code == 404
    
    -- Cache the result
    self.cached_availability = available
    self.cached_availability_time = current_time
    
    self:log("Availability check completed in " .. string.format("%.3f", end_time - start_time) .. "s: " .. tostring(available))
    
    return available
end

function HttpsTransport:write_message(message_data, message_type)
    -- ADD COMPREHENSIVE DIAGNOSTIC LOGGING FOR STALE STATE DEBUG
    print("[DEBUG_STALE_STATE] HttpsTransport:write_message called")
    print("[DEBUG_STALE_STATE] message_type: " .. tostring(message_type))
    print("[DEBUG_STALE_STATE] message_data type: " .. type(message_data))
    
    if not message_data then
        self:log("ERROR: No message data provided")
        print("[DEBUG_STALE_STATE] *** WRITE_MESSAGE FAILED - NO DATA ***")
        return false
    end
    
    if not message_type then
        self:log("ERROR: No message type provided")
        print("[DEBUG_STALE_STATE] *** WRITE_MESSAGE FAILED - NO MESSAGE TYPE ***")
        return false
    end
    
    -- Parse message data to extract components
    local parsed_data
    if type(message_data) == "string" then
        local parse_success, data = pcall(self.json.decode, message_data)
        if not parse_success then
            self:log("ERROR: Failed to parse message data JSON: " .. tostring(data))
            return false
        end
        parsed_data = data
    else
        parsed_data = message_data
    end
    
    -- Prepare payload for POST to game_data_endpoint
    local payload = {
        message_type = message_type,
        timestamp = parsed_data.timestamp or os.time(),
        sequence_id = parsed_data.sequence_id or 0,
        data = parsed_data.data or parsed_data
    }
    
    -- Include result and sequence_id from last command if available
    if parsed_data.result then
        payload.result = parsed_data.result
    end
    if parsed_data.last_sequence_id then
        payload.last_sequence_id = parsed_data.last_sequence_id
    end
    
    local json_payload = self.json.encode(payload)
    if not json_payload then
        self:log("ERROR: Failed to encode payload to JSON")
        return false
    end
    
    local url = self:get_endpoint_url(self.game_data_endpoint)
    local headers = self:prepare_headers()
    
    print("[DEBUG_STALE_STATE] About to make HTTP POST request to: " .. url)
    print("[DEBUG_STALE_STATE] Payload size: " .. #json_payload .. " bytes")
    
    local response, status_code = self:make_request("POST", url, json_payload, headers)
    
    print("[DEBUG_STALE_STATE] HTTP POST result - response: " .. tostring(response ~= nil) .. ", status: " .. tostring(status_code))
    
    if not response then
        self:log("ERROR: Failed to write message via HTTPS")
        print("[DEBUG_STALE_STATE] *** HTTP POST FAILED - NO RESPONSE ***")
        return false
    end
    
    self:log("Message written successfully to: " .. url)
    print("[DEBUG_STALE_STATE] *** HTTP POST SUCCESS ***")
    return true
end

function HttpsTransport:read_message(message_type)
    -- Only poll actions_endpoint for "actions" message type
    if message_type ~= "actions" then
        self:log("ACTION_POLLING - Ignoring non-actions message type: " .. tostring(message_type))
        return nil -- Other message types are write-only to server
    end
    
    self:log("ACTION_POLLING - Polling actions endpoint")
    local url = self:get_endpoint_url(self.actions_endpoint)
    local headers = self:prepare_headers()
    
    self:log("ACTION_POLLING - Making GET request to: " .. url)
    local response, status_code = self:make_request("GET", url, nil, headers)
    
    if not response then
        self:log("ACTION_POLLING - No actions available or connection failed")
        return nil
    end
    
    self:log("ACTION_POLLING - Actions response received, size: " .. #response .. " bytes")
    
    -- Parse response
    local parse_success, data = pcall(self.json.decode, response)
    if not parse_success then
        self:log("ERROR: Failed to parse actions response JSON: " .. tostring(data))
        return nil
    end
    
    -- Check sequence tracking to prevent duplicate processing
    local sequence_id = data.sequence_id or 0
    local last_read = self.last_read_sequences[message_type] or 0
    
    self:log("Actions sequence_id: " .. sequence_id .. ", last_read: " .. last_read)
    
    if sequence_id < last_read then
        self:log("Actions already processed, ignoring")
        return nil -- Already processed
    end
    
    self.last_read_sequences[message_type] = sequence_id
    self:log("Processing new actions with sequence_id: " .. sequence_id)
    
    return response
end

function HttpsTransport:verify_message(message_data, message_type)
    -- For HTTPS transport, verification means the POST request succeeded
    -- We can optionally make a GET request to verify the data was received
    -- For now, we'll consider the write operation successful if it returned 200
    
    if message_type == "actions" then
        -- Actions are read-only from server, so verification is not applicable
        return true
    end
    
    -- For write operations, we already verified success in write_message
    -- Additional verification could involve checking if the server processed the data
    self:log("Message verification successful for type: " .. message_type)
    return true
end

function HttpsTransport:cleanup_old_messages(max_age_seconds)
    -- Not applicable for HTTPS transport - server handles message retention
    -- This is a no-op that returns success
    self:log("Cleanup not applicable for HTTPS transport - server handles retention")
    return true
end

-- Update method - simplified since no async operations to manage
function HttpsTransport:update(dt)
    -- SMODS.https handles all HTTP operations synchronously
    -- No async management needed
end

-- Cleanup method - simplified since no async resources to manage
function HttpsTransport:cleanup()
    -- Clear caches
    self.cached_availability = nil
    self.cached_availability_time = 0
    
    self:log("HTTPS transport cleanup completed")
end

return HttpsTransport