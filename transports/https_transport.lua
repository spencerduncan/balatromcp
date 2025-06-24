-- HTTPS Transport - Concrete implementation of IMessageTransport for HTTPS-based I/O
-- Handles all HTTP operations, endpoint management, and network communication
-- Follows Single Responsibility Principle - focused solely on HTTPS I/O operations

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
    
    -- Load HTTP library (luasocket)
    local http_success, http = pcall(require, "socket.http")
    if not http_success then
        self:log("WARNING: socket.http not available, trying alternative HTTP implementation")
        -- Try alternative HTTP implementation using love.thread if available
        self.http = self:create_fallback_http()
    else
        self.http = http
        -- Also load ltn12 for body handling
        local ltn12_success, ltn12 = pcall(require, "ltn12")
        if ltn12_success then
            self.ltn12 = ltn12
        end
    end
    
    if not self.http then
        error("No HTTP implementation available - HTTPS transport cannot function")
    end
    
    self:log("HTTPS transport initialized with base URL: " .. self.base_url)
end

function HttpsTransport:create_fallback_http()
    -- Fallback HTTP implementation using love.filesystem and love.thread if available
    -- This is a simplified implementation for environments without luasocket
    self:log("Creating fallback HTTP implementation")
    
    local fallback_http = {}
    
    function fallback_http.request(url, body)
        -- This would need to be implemented using love.thread and external tools
        -- For now, return an error to indicate unavailability
        return nil, "Fallback HTTP not implemented - requires luasocket"
    end
    
    return fallback_http
end

function HttpsTransport:log(message)
    local log_msg = "BalatroMCP [" .. self.component_name .. "]: " .. message
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
            print("BalatroMCP [HTTPS_TRANSPORT]: Failed to write debug log: " .. tostring(err))
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

-- Private method - make HTTP request with timeout and error handling
function HttpsTransport:make_request(method, url, body, headers)
    self.request_count = self.request_count + 1
    local request_id = self.request_count
    
    self:log("Making " .. method .. " request #" .. request_id .. " to: " .. url)
    
    local start_time = os.clock()
    local response_body = {}
    local result, status_code, response_headers
    
    if self.ltn12 then
        -- Use luasocket with proper body handling
        result, status_code, response_headers = self.http.request({
            url = url,
            method = method,
            headers = headers,
            source = body and self.ltn12.source.string(body) or nil,
            sink = self.ltn12.sink.table(response_body)
        })
    else
        -- Fallback to simple request
        if method == "POST" and body then
            result, status_code = self.http.request(url, body)
        else
            result, status_code = self.http.request(url)
        end
        
        if result then
            response_body = {result}
        end
    end
    
    local end_time = os.clock()
    local duration = end_time - start_time
    
    self:log("Request #" .. request_id .. " completed in " .. string.format("%.3f", duration) .. "s, status: " .. tostring(status_code))
    
    if not result then
        self:log("ERROR: HTTP request failed: " .. tostring(status_code))
        return nil, status_code or "network_error"
    end
    
    local response_text = table.concat(response_body)
    
    -- Check for successful HTTP status codes
    if status_code and (status_code < 200 or status_code >= 300) then
        self:log("ERROR: HTTP request returned error status: " .. status_code)
        self:log("Response body: " .. string.sub(response_text, 1, 200))
        return nil, status_code
    end
    
    return response_text, status_code, response_headers
end

-- IMessageTransport interface implementation
function HttpsTransport:is_available()
    -- Test connectivity with a lightweight request
    local test_url = self:get_endpoint_url("/health")
    local headers = self:prepare_headers()
    
    local start_time = os.clock()
    local response, status_code = self:make_request("GET", test_url, nil, headers)
    local end_time = os.clock()
    
    -- 404 is acceptable (no health endpoint), so check status directly
    local available = (response ~= nil and status_code == 200) or status_code == 404
    
    self:log("Availability check completed in " .. string.format("%.3f", end_time - start_time) .. "s: " .. tostring(available))
    
    return available
end

function HttpsTransport:write_message(message_data, message_type)
    if not message_data then
        self:log("ERROR: No message data provided")
        return false
    end
    
    if not message_type then
        self:log("ERROR: No message type provided")
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
    
    local response, status_code = self:make_request("POST", url, json_payload, headers)
    
    if not response then
        self:log("ERROR: Failed to write message via HTTPS")
        return false
    end
    
    self:log("Message written successfully to: " .. url)
    return true
end

function HttpsTransport:read_message(message_type)
    -- Only poll actions_endpoint for "actions" message type
    if message_type ~= "actions" then
        return nil -- Other message types are write-only to server
    end
    
    local url = self:get_endpoint_url(self.actions_endpoint)
    local headers = self:prepare_headers()
    
    local response, status_code = self:make_request("GET", url, nil, headers)
    
    if not response then
        self:log("No actions available or connection failed")
        return nil
    end
    
    self:log("Actions response received, size: " .. #response .. " bytes")
    
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

return HttpsTransport