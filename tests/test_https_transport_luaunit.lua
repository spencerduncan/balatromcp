-- LuaUnit tests for HttpsTransport class
-- Tests HTTP communication, endpoint management, and IMessageTransport interface implementation
-- Follows Single Responsibility Principle testing - focused on HTTPS operations

local luaunit_helpers = require('tests.luaunit_helpers')
local luaunit = require('libs.luaunit')
local HttpsTransport = require('transports.https_transport')
local IMessageTransport = require('interfaces.message_transport')

-- Mock HTTP responses and behaviors
local mock_http_responses = {}
local mock_http_request_log = {}
local mock_http_should_fail = false
local mock_http_failure_reason = "network_error"

-- Helper function to set up before each test
local function setUp()
    luaunit_helpers.setup_mock_smods()
    
    -- Reset mock state (use globals for SMODS.https compatibility)
    _G.mock_http_responses = {}
    _G.mock_http_request_log = {}
    _G.mock_http_should_fail = false
    _G.mock_http_failure_reason = "network_error"
    
    -- Also set local variables for backward compatibility
    mock_http_responses = _G.mock_http_responses
    mock_http_request_log = _G.mock_http_request_log
    mock_http_should_fail = _G.mock_http_should_fail
    mock_http_failure_reason = _G.mock_http_failure_reason
    
    -- Set up mock HTTP environment
    setup_mock_http_environment()
end

-- Helper function to tear down after each test
local function tearDown()
    luaunit_helpers.cleanup_mock_smods()
    cleanup_mock_http_environment()
end

-- Set up mock HTTP and networking environment
function setup_mock_http_environment()
    -- Mock socket.http library
    package.loaded["socket.http"] = {
        request = function(url_or_options, body)
            local url, method, headers, request_body
            
            if type(url_or_options) == "string" then
                url = url_or_options
                method = body and "POST" or "GET"
                request_body = body
                headers = {}
            else
                url = url_or_options.url
                method = url_or_options.method or "GET"
                headers = url_or_options.headers or {}
                
                -- Handle ltn12 source
                if url_or_options.source then
                    request_body = ""
                    local chunk
                    repeat
                        chunk = url_or_options.source()
                        if chunk then
                            request_body = request_body .. chunk
                        end
                    until not chunk
                end
                
                -- Handle ltn12 sink
                if url_or_options.sink and mock_http_responses[url] then
                    url_or_options.sink(mock_http_responses[url])
                end
            end
            
            -- Log the request
            table.insert(mock_http_request_log, {
                url = url,
                method = method,
                headers = headers,
                body = request_body
            })
            
            -- Return mock failure if configured
            if mock_http_should_fail then
                return nil, mock_http_failure_reason
            end
            
            -- Return mock response
            local response = mock_http_responses[url] or '{"status": "ok"}'
            local status = mock_http_responses[url .. "_status"] or 200
            
            return response, status
        end
    }
    
    -- Mock ltn12 library
    package.loaded["ltn12"] = {
        source = {
            string = function(str)
                local sent = false
                return function()
                    if not sent then
                        sent = true
                        return str
                    else
                        return nil
                    end
                end
            end
        },
        sink = {
            table = function(t)
                return function(chunk)
                    if chunk then
                        table.insert(t, chunk)
                    end
                    return 1
                end
            end
        }
    }
end

-- Clean up mock HTTP environment
function cleanup_mock_http_environment()
    package.loaded["socket.http"] = nil
    package.loaded["ltn12"] = nil
end

-- Helper to set mock HTTP response for a URL
local function set_mock_response(url, response, status_code)
    _G.mock_http_responses[url] = response
    if status_code then
        _G.mock_http_responses[url .. "_status"] = status_code
    end
end

-- Helper to get last HTTP request made
local function get_last_request()
    return _G.mock_http_request_log[#_G.mock_http_request_log]
end

-- Helper to clear request log
local function clear_request_log()
    _G.mock_http_request_log = {}
end

-- =============================================================================
-- HTTPS TRANSPORT INITIALIZATION TESTS
-- =============================================================================

local function TestHttpsTransportInitializationWithValidConfig()
    setUp()
    
    local config = {
        base_url = "https://api.example.com",
        game_data_endpoint = "/custom-game-data",
        actions_endpoint = "/custom-actions",
        timeout = 10,
        headers = {["Authorization"] = "Bearer test"}
    }
    
    local transport = HttpsTransport.new(config)
    
    luaunit.assertNotNil(transport, "HttpsTransport should initialize with valid config")
    luaunit.assertEquals("https://api.example.com", transport.base_url, "Should set base URL without trailing slash")
    luaunit.assertEquals("/custom-game-data", transport.game_data_endpoint, "Should set custom game data endpoint")
    luaunit.assertEquals("/custom-actions", transport.actions_endpoint, "Should set custom actions endpoint")
    luaunit.assertEquals(10, transport.timeout, "Should set custom timeout")
    luaunit.assertEquals("Bearer test", transport.headers["Authorization"], "Should set custom headers")
    luaunit.assertEquals("HTTPS_TRANSPORT", transport.component_name, "Should set component name")
    luaunit.assertEquals(0, transport.request_count, "Should initialize request count to 0")
    luaunit.assertNotNil(transport.json, "Should load JSON library")
    luaunit.assertEquals("table", type(transport.last_read_sequences), "Should initialize sequence tracking")
    
    tearDown()
end

local function TestHttpsTransportInitializationWithDefaultValues()
    setUp()
    
    local config = {
        base_url = "https://api.example.com/"
    }
    
    local transport = HttpsTransport.new(config)
    
    luaunit.assertEquals("https://api.example.com", transport.base_url, "Should remove trailing slash")
    luaunit.assertEquals("/game-data", transport.game_data_endpoint, "Should set default game data endpoint")
    luaunit.assertEquals("/actions", transport.actions_endpoint, "Should set default actions endpoint")
    luaunit.assertEquals(5, transport.timeout, "Should set default timeout")
    luaunit.assertEquals("table", type(transport.headers), "Should initialize empty headers table")
    
    tearDown()
end

local function TestHttpsTransportInitializationNoConfig()
    setUp()
    
    local success, error_msg = pcall(function()
        HttpsTransport.new()
    end)
    
    luaunit.assertFalse(success, "Should fail when no config provided")
    luaunit.assertStrContains(tostring(error_msg), "configuration table", "Should show configuration error")
    
    tearDown()
end

local function TestHttpsTransportInitializationInvalidConfig()
    setUp()
    
    local success, error_msg = pcall(function()
        HttpsTransport.new("invalid config")
    end)
    
    luaunit.assertFalse(success, "Should fail with invalid config type")
    luaunit.assertStrContains(tostring(error_msg), "configuration table", "Should show configuration error")
    
    tearDown()
end

local function TestHttpsTransportInitializationNoBaseUrl()
    setUp()
    
    local success, error_msg = pcall(function()
        HttpsTransport.new({timeout = 5})
    end)
    
    luaunit.assertFalse(success, "Should fail when no base_url provided")
    luaunit.assertStrContains(tostring(error_msg), "base_url", "Should show base_url error")
    
    tearDown()
end

local function TestHttpsTransportInitializationInvalidBaseUrl()
    setUp()
    
    local success, error_msg = pcall(function()
        HttpsTransport.new({base_url = 123})
    end)
    
    luaunit.assertFalse(success, "Should fail with invalid base_url type")
    luaunit.assertStrContains(tostring(error_msg), "base_url", "Should show base_url error")
    
    tearDown()
end

local function TestHttpsTransportSMODSLoadingFailure()
    setUp()
    
    -- Clear SMODS to test failure case
    _G.SMODS = nil
    
    local success, error_msg = pcall(function()
        HttpsTransport.new({base_url = "https://api.example.com"})
    end)
    
    luaunit.assertFalse(success, "Should fail when SMODS not available")
    luaunit.assertStrContains(tostring(error_msg), "SMODS not available", "Should show SMODS dependency error")
    
    tearDown()
end

local function TestHttpsTransportHttpLibraryUnavailable()
    setUp()
    
    -- Remove HTTP library to test fallback
    package.loaded["socket.http"] = nil
    package.preload["socket.http"] = function() error("not available") end
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    luaunit.assertNotNil(transport.http, "Should create fallback HTTP implementation")
    
    tearDown()
end

-- =============================================================================
-- INTERFACE COMPLIANCE TESTS
-- =============================================================================

local function TestHttpsTransportInterfaceCompliance()
    setUp()
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    local success = IMessageTransport.validate_implementation(transport)
    luaunit.assertTrue(success, "Should pass interface validation")
    
    tearDown()
end

local function TestHttpsTransportRequiredMethods()
    setUp()
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    luaunit.assertEquals("function", type(transport.is_available), "Should have is_available method")
    luaunit.assertEquals("function", type(transport.write_message), "Should have write_message method")
    luaunit.assertEquals("function", type(transport.read_message), "Should have read_message method")
    luaunit.assertEquals("function", type(transport.verify_message), "Should have verify_message method")
    luaunit.assertEquals("function", type(transport.cleanup_old_messages), "Should have cleanup_old_messages method")
    
    tearDown()
end

-- =============================================================================
-- AVAILABILITY TESTS
-- =============================================================================

local function TestHttpsTransportIsAvailableSuccess()
    setUp()
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    set_mock_response("https://api.example.com/health", '{"status": "ok"}', 200)
    
    local available = transport:is_available()
    
    luaunit.assertTrue(available, "Should report available when health check succeeds")
    
    local request = get_last_request()
    luaunit.assertEquals("https://api.example.com/health", request.url, "Should make request to health endpoint")
    luaunit.assertEquals("GET", request.method, "Should use GET method for health check")
    
    tearDown()
end

local function TestHttpsTransportIsAvailableWith404()
    setUp()
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    -- Mock the request to return a proper response with 404 status
    mock_http_responses["https://api.example.com/health"] = "Not found"
    mock_http_responses["https://api.example.com/health_status"] = 404
    
    local available = transport:is_available()
    
    luaunit.assertTrue(available, "Should report available even with 404 (no health endpoint)")
    
    tearDown()
end

local function TestHttpsTransportIsAvailableNetworkFailure()
    setUp()
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    mock_http_should_fail = true
    
    local available = transport:is_available()
    
    luaunit.assertFalse(available, "Should report unavailable when network fails")
    
    tearDown()
end

-- =============================================================================
-- WRITE MESSAGE TESTS
-- =============================================================================

local function TestHttpsTransportWriteMessageSuccess()
    setUp()
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    local message_data = {
        timestamp = "2024-01-01T00:00:00Z",
        sequence_id = 1,
        data = {test = "game state"}
    }
    
    set_mock_response("https://api.example.com/game-data", '{"received": true}', 200)
    
    local success = transport:write_message(message_data, "game_state")
    
    luaunit.assertTrue(success, "Should successfully write message")
    
    local request = get_last_request()
    luaunit.assertEquals("https://api.example.com/game-data", request.url, "Should POST to game data endpoint")
    luaunit.assertEquals("POST", request.method, "Should use POST method")
    luaunit.assertEquals("application/json", request.headers["Content-Type"], "Should set JSON content type")
    luaunit.assertEquals("BalatroMCP/1.0", request.headers["User-Agent"], "Should set user agent")
    
    -- Verify JSON payload structure
    local payload = transport.json.decode(request.body)
    luaunit.assertEquals("game_state", payload.message_type, "Should include message type")
    luaunit.assertEquals(1, payload.sequence_id, "Should include sequence ID")
    luaunit.assertNotNil(payload.timestamp, "Should include timestamp")
    luaunit.assertEquals("game state", payload.data.test, "Should include message data")
    
    tearDown()
end

local function TestHttpsTransportWriteMessageWithStringData()
    setUp()
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    local json_string = '{"timestamp": "2024-01-01T00:00:00Z", "sequence_id": 2, "data": {"test": "string data"}}'
    
    set_mock_response("https://api.example.com/game-data", '{"received": true}', 200)
    
    local success = transport:write_message(json_string, "deck_state")
    
    luaunit.assertTrue(success, "Should successfully write string message")
    
    local request = get_last_request()
    local payload = transport.json.decode(request.body)
    luaunit.assertEquals("deck_state", payload.message_type, "Should parse string data and set message type")
    luaunit.assertEquals(2, payload.sequence_id, "Should extract sequence ID from string")
    
    tearDown()
end

local function TestHttpsTransportWriteMessageWithCustomEndpoint()
    setUp()
    
    local config = {
        base_url = "https://api.example.com",
        game_data_endpoint = "/custom-data"
    }
    local transport = HttpsTransport.new(config)
    
    local message_data = {data = {test = "custom endpoint"}}
    
    set_mock_response("https://api.example.com/custom-data", '{"received": true}', 200)
    
    local success = transport:write_message(message_data, "game_state")
    
    luaunit.assertTrue(success, "Should use custom endpoint")
    
    local request = get_last_request()
    luaunit.assertEquals("https://api.example.com/custom-data", request.url, "Should POST to custom endpoint")
    
    tearDown()
end

local function TestHttpsTransportWriteMessageWithResult()
    setUp()
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    local message_data = {
        data = {test = "data"},
        result = {action = "completed"},
        last_sequence_id = 5
    }
    
    set_mock_response("https://api.example.com/game-data", '{"received": true}', 200)
    
    local success = transport:write_message(message_data, "action_result")
    
    luaunit.assertTrue(success, "Should write message with result")
    
    local request = get_last_request()
    local payload = transport.json.decode(request.body)
    luaunit.assertEquals("completed", payload.result.action, "Should include result in payload")
    luaunit.assertEquals(5, payload.last_sequence_id, "Should include last sequence ID")
    
    tearDown()
end

local function TestHttpsTransportWriteMessageErrorHandling()
    setUp()
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    -- Test nil message data
    local success1 = transport:write_message(nil, "game_state")
    luaunit.assertFalse(success1, "Should fail with nil message data")
    
    -- Test nil message type
    local success2 = transport:write_message({data = "test"}, nil)
    luaunit.assertFalse(success2, "Should fail with nil message type")
    
    -- Test invalid JSON string
    local success3 = transport:write_message("invalid json", "game_state")
    luaunit.assertFalse(success3, "Should fail with invalid JSON string")
    
    tearDown()
end

local function TestHttpsTransportWriteMessageNetworkFailure()
    setUp()
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    mock_http_should_fail = true
    
    local message_data = {data = {test = "data"}}
    local success = transport:write_message(message_data, "game_state")
    
    luaunit.assertFalse(success, "Should fail when network request fails")
    
    tearDown()
end

local function TestHttpsTransportWriteMessageHttpError()
    setUp()
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    -- Mock the request to return an error status code
    mock_http_responses["https://api.example.com/game-data"] = "Server Error"
    mock_http_responses["https://api.example.com/game-data_status"] = 500
    
    local message_data = {data = {test = "data"}}
    local success = transport:write_message(message_data, "game_state")
    
    luaunit.assertFalse(success, "Should fail with HTTP error status")
    
    tearDown()
end

-- =============================================================================
-- READ MESSAGE TESTS
-- =============================================================================

local function TestHttpsTransportReadActionsSuccess()
    setUp()
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    local actions_response = {
        timestamp = "2024-01-01T00:00:00Z",
        sequence_id = 10,
        data = {action_type = "play_hand", cards = {"AS", "KS"}}
    }
    
    set_mock_response("https://api.example.com/actions", transport.json.encode(actions_response), 200)
    
    local result = transport:read_message("actions")
    
    luaunit.assertNotNil(result, "Should return actions data")
    luaunit.assertEquals(transport.json.encode(actions_response), result, "Should return raw JSON response")
    luaunit.assertEquals(10, transport.last_read_sequences["actions"], "Should track sequence ID")
    
    local request = get_last_request()
    luaunit.assertEquals("https://api.example.com/actions", request.url, "Should GET from actions endpoint")
    luaunit.assertEquals("GET", request.method, "Should use GET method")
    
    tearDown()
end

local function TestHttpsTransportReadActionsWithCustomEndpoint()
    setUp()
    
    local config = {
        base_url = "https://api.example.com",
        actions_endpoint = "/custom-actions"
    }
    local transport = HttpsTransport.new(config)
    
    local actions_response = {sequence_id = 15, data = {test = "custom"}}
    set_mock_response("https://api.example.com/custom-actions", transport.json.encode(actions_response), 200)
    
    local result = transport:read_message("actions")
    
    luaunit.assertNotNil(result, "Should read from custom actions endpoint")
    
    local request = get_last_request()
    luaunit.assertEquals("https://api.example.com/custom-actions", request.url, "Should use custom endpoint")
    
    tearDown()
end

local function TestHttpsTransportReadActionsSequenceDeduplication()
    setUp()
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    -- Set last read sequence higher than current message
    transport.last_read_sequences["actions"] = 20
    
    local actions_response = {sequence_id = 15, data = {action_type = "old_action"}}
    set_mock_response("https://api.example.com/actions", transport.json.encode(actions_response), 200)
    
    local result = transport:read_message("actions")
    
    luaunit.assertNil(result, "Should return nil for already processed sequence")
    luaunit.assertEquals(20, transport.last_read_sequences["actions"], "Should not update sequence tracking")
    
    tearDown()
end

local function TestHttpsTransportReadNonActionsMessageType()
    setUp()
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    local result = transport:read_message("game_state")
    
    luaunit.assertNil(result, "Should return nil for non-actions message types")
    luaunit.assertEquals(0, #mock_http_request_log, "Should not make HTTP request for non-actions")
    
    tearDown()
end

local function TestHttpsTransportReadActionsNetworkFailure()
    setUp()
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    mock_http_should_fail = true
    
    local result = transport:read_message("actions")
    
    luaunit.assertNil(result, "Should return nil when network fails")
    
    tearDown()
end

local function TestHttpsTransportReadActionsInvalidJson()
    setUp()
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    set_mock_response("https://api.example.com/actions", "invalid json response", 200)
    
    local result = transport:read_message("actions")
    
    luaunit.assertNil(result, "Should return nil for invalid JSON response")
    
    tearDown()
end

local function TestHttpsTransportReadActionsNoSequenceId()
    setUp()
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    local actions_response = {data = {action_type = "test"}} -- No sequence_id
    mock_http_responses["https://api.example.com/actions"] = transport.json.encode(actions_response)
    mock_http_responses["https://api.example.com/actions_status"] = 200
    
    local result = transport:read_message("actions")
    
    luaunit.assertNotNil(result, "Should process actions without sequence_id")
    luaunit.assertEquals(0, transport.last_read_sequences["actions"], "Should track sequence as 0")
    
    tearDown()
end

-- =============================================================================
-- VERIFY MESSAGE TESTS
-- =============================================================================

local function TestHttpsTransportVerifyMessageSuccess()
    setUp()
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    local message_data = {data = {test = "verify"}}
    local success = transport:verify_message(message_data, "game_state")
    
    luaunit.assertTrue(success, "Should successfully verify non-actions message")
    
    tearDown()
end

local function TestHttpsTransportVerifyActionsMessage()
    setUp()
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    local message_data = {data = {action_type = "test"}}
    local success = transport:verify_message(message_data, "actions")
    
    luaunit.assertTrue(success, "Should successfully verify actions message")
    
    tearDown()
end

-- =============================================================================
-- CLEANUP TESTS
-- =============================================================================

local function TestHttpsTransportCleanupOldMessages()
    setUp()
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    local success = transport:cleanup_old_messages(300)
    
    luaunit.assertTrue(success, "Should successfully complete cleanup (no-op for HTTPS)")
    
    tearDown()
end

-- =============================================================================
-- HTTP REQUEST CONSTRUCTION TESTS
-- =============================================================================

local function TestHttpsTransportHeadersConstruction()
    setUp()
    
    local config = {
        base_url = "https://api.example.com",
        headers = {
            ["Authorization"] = "Bearer token123",
            ["X-Custom"] = "custom-value"
        }
    }
    local transport = HttpsTransport.new(config)
    
    local message_data = {data = {test = "headers"}}
    set_mock_response("https://api.example.com/game-data", '{"received": true}', 200)
    
    transport:write_message(message_data, "game_state")
    
    local request = get_last_request()
    luaunit.assertEquals("application/json", request.headers["Content-Type"], "Should set default content type")
    luaunit.assertEquals("BalatroMCP/1.0", request.headers["User-Agent"], "Should set default user agent")
    luaunit.assertEquals("Bearer token123", request.headers["Authorization"], "Should include custom authorization header")
    luaunit.assertEquals("custom-value", request.headers["X-Custom"], "Should include custom header")
    
    tearDown()
end

local function TestHttpsTransportUrlConstruction()
    setUp()
    
    local config = {base_url = "https://api.example.com:8080/v1"}
    local transport = HttpsTransport.new(config)
    
    -- Test URL construction for different endpoints
    luaunit.assertEquals("https://api.example.com:8080/v1/game-data", transport:get_endpoint_url("/game-data"), "Should construct game data URL")
    luaunit.assertEquals("https://api.example.com:8080/v1/actions", transport:get_endpoint_url("/actions"), "Should construct actions URL")
    luaunit.assertEquals("https://api.example.com:8080/v1/health", transport:get_endpoint_url("/health"), "Should construct health URL")
    
    tearDown()
end

local function TestHttpsTransportRequestCounting()
    setUp()
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    luaunit.assertEquals(0, transport.request_count, "Should start with 0 requests")
    
    set_mock_response("https://api.example.com/health", '{"status": "ok"}', 200)
    transport:is_available()
    
    luaunit.assertEquals(1, transport.request_count, "Should increment request count")
    
    set_mock_response("https://api.example.com/game-data", '{"received": true}', 200)
    transport:write_message({data = {test = "count"}}, "game_state")
    
    luaunit.assertEquals(2, transport.request_count, "Should increment request count again")
    
    tearDown()
end

-- =============================================================================
-- ERROR HANDLING AND EDGE CASES
-- =============================================================================

local function TestHttpsTransportFallbackHttpImplementation()
    setUp()
    
    -- Remove HTTP libraries to force fallback
    package.loaded["socket.http"] = nil
    package.loaded["ltn12"] = nil
    package.preload["socket.http"] = function() error("not available") end
    package.preload["ltn12"] = function() error("not available") end
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    -- Test that fallback HTTP returns error
    local message_data = {data = {test = "fallback"}}
    local success = transport:write_message(message_data, "game_state")
    
    luaunit.assertFalse(success, "Should fail with fallback HTTP implementation")
    
    tearDown()
end

local function TestHttpsTransportTimeoutHandling()
    setUp()
    
    local config = {base_url = "https://api.example.com", timeout = 1}
    local transport = HttpsTransport.new(config)
    
    luaunit.assertEquals(1, transport.timeout, "Should set custom timeout")
    
    tearDown()
end

local function TestHttpsTransportLtn12Integration()
    setUp()
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    -- Verify ltn12 was loaded
    luaunit.assertNotNil(transport.ltn12, "Should load ltn12 library")
    
    local message_data = {data = {test = "ltn12"}}
    set_mock_response("https://api.example.com/game-data", '{"received": true}', 200)
    
    local success = transport:write_message(message_data, "game_state")
    
    luaunit.assertTrue(success, "Should work with ltn12 integration")
    
    tearDown()
end

local function TestHttpsTransportWithoutLtn12()
    setUp()
    
    -- Remove ltn12 to test fallback path
    package.loaded["ltn12"] = nil
    package.preload["ltn12"] = function() error("not available") end
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    luaunit.assertNil(transport.ltn12, "Should not have ltn12 available")
    
    local message_data = {data = {test = "no-ltn12"}}
    set_mock_response("https://api.example.com/game-data", '{"received": true}', 200)
    
    local success = transport:write_message(message_data, "game_state")
    
    luaunit.assertTrue(success, "Should work without ltn12")
    
    tearDown()
end

-- =============================================================================
-- INTEGRATION TESTS
-- =============================================================================

local function TestHttpsTransportMessageStructureConsistency()
    setUp()
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    -- Test that messages have consistent structure with FileTransport expectations
    local message_data = {
        timestamp = "2024-01-01T00:00:00Z",
        sequence_id = 42,
        message_type = "game_state",
        data = {
            phase = "SELECTING_HAND",
            dollars = 100,
            hands_left = 3
        }
    }
    
    set_mock_response("https://api.example.com/game-data", '{"received": true}', 200)
    
    local success = transport:write_message(message_data, "game_state")
    luaunit.assertTrue(success, "Should write structured message")
    
    local request = get_last_request()
    local payload = transport.json.decode(request.body)
    
    -- Verify payload structure matches expected format
    luaunit.assertEquals("game_state", payload.message_type, "Should preserve message type")
    luaunit.assertEquals(42, payload.sequence_id, "Should preserve sequence ID")
    luaunit.assertEquals("2024-01-01T00:00:00Z", payload.timestamp, "Should preserve timestamp")
    luaunit.assertEquals("SELECTING_HAND", payload.data.phase, "Should preserve nested data")
    luaunit.assertEquals(100, payload.data.dollars, "Should preserve numeric data")
    
    tearDown()
end

local function TestHttpsTransportSequenceTrackingConsistency()
    setUp()
    
    local config = {base_url = "https://api.example.com"}
    local transport = HttpsTransport.new(config)
    
    -- Test sequence tracking similar to FileTransport
    local response1 = {sequence_id = 100, data = {action_type = "first"}}
    local response2 = {sequence_id = 101, data = {action_type = "second"}}
    local response3 = {sequence_id = 100, data = {action_type = "duplicate"}}
    
    -- First read
    set_mock_response("https://api.example.com/actions", transport.json.encode(response1), 200)
    local result1 = transport:read_message("actions")
    luaunit.assertNotNil(result1, "Should read first message")
    luaunit.assertEquals(100, transport.last_read_sequences["actions"], "Should track first sequence")
    
    clear_request_log()
    
    -- Second read with higher sequence
    set_mock_response("https://api.example.com/actions", transport.json.encode(response2), 200)
    local result2 = transport:read_message("actions")
    luaunit.assertNotNil(result2, "Should read second message")
    luaunit.assertEquals(101, transport.last_read_sequences["actions"], "Should track higher sequence")
    
    clear_request_log()
    
    -- Third read with duplicate sequence
    set_mock_response("https://api.example.com/actions", transport.json.encode(response3), 200)
    local result3 = transport:read_message("actions")
    luaunit.assertNil(result3, "Should ignore duplicate sequence")
    luaunit.assertEquals(101, transport.last_read_sequences["actions"], "Should maintain higher sequence")
    
    tearDown()
end

-- Export all test functions for LuaUnit registration
return {
    TestHttpsTransportInitializationWithValidConfig = TestHttpsTransportInitializationWithValidConfig,
    TestHttpsTransportInitializationWithDefaultValues = TestHttpsTransportInitializationWithDefaultValues,
    TestHttpsTransportInitializationNoConfig = TestHttpsTransportInitializationNoConfig,
    TestHttpsTransportInitializationInvalidConfig = TestHttpsTransportInitializationInvalidConfig,
    TestHttpsTransportInitializationNoBaseUrl = TestHttpsTransportInitializationNoBaseUrl,
    TestHttpsTransportInitializationInvalidBaseUrl = TestHttpsTransportInitializationInvalidBaseUrl,
    TestHttpsTransportSMODSLoadingFailure = TestHttpsTransportSMODSLoadingFailure,
    TestHttpsTransportHttpLibraryUnavailable = TestHttpsTransportHttpLibraryUnavailable,
    TestHttpsTransportInterfaceCompliance = TestHttpsTransportInterfaceCompliance,
    TestHttpsTransportRequiredMethods = TestHttpsTransportRequiredMethods,
    TestHttpsTransportIsAvailableSuccess = TestHttpsTransportIsAvailableSuccess,
    TestHttpsTransportIsAvailableWith404 = TestHttpsTransportIsAvailableWith404,
    TestHttpsTransportIsAvailableNetworkFailure = TestHttpsTransportIsAvailableNetworkFailure,
    TestHttpsTransportWriteMessageSuccess = TestHttpsTransportWriteMessageSuccess,
    TestHttpsTransportWriteMessageWithStringData = TestHttpsTransportWriteMessageWithStringData,
    TestHttpsTransportWriteMessageWithCustomEndpoint = TestHttpsTransportWriteMessageWithCustomEndpoint,
    TestHttpsTransportWriteMessageWithResult = TestHttpsTransportWriteMessageWithResult,
    TestHttpsTransportWriteMessageErrorHandling = TestHttpsTransportWriteMessageErrorHandling,
    TestHttpsTransportWriteMessageNetworkFailure = TestHttpsTransportWriteMessageNetworkFailure,
    TestHttpsTransportWriteMessageHttpError = TestHttpsTransportWriteMessageHttpError,
    TestHttpsTransportReadActionsSuccess = TestHttpsTransportReadActionsSuccess,
    TestHttpsTransportReadActionsWithCustomEndpoint = TestHttpsTransportReadActionsWithCustomEndpoint,
    TestHttpsTransportReadActionsSequenceDeduplication = TestHttpsTransportReadActionsSequenceDeduplication,
    TestHttpsTransportReadNonActionsMessageType = TestHttpsTransportReadNonActionsMessageType,
    TestHttpsTransportReadActionsNetworkFailure = TestHttpsTransportReadActionsNetworkFailure,
    TestHttpsTransportReadActionsInvalidJson = TestHttpsTransportReadActionsInvalidJson,
    TestHttpsTransportReadActionsNoSequenceId = TestHttpsTransportReadActionsNoSequenceId,
    TestHttpsTransportVerifyMessageSuccess = TestHttpsTransportVerifyMessageSuccess,
    TestHttpsTransportVerifyActionsMessage = TestHttpsTransportVerifyActionsMessage,
    TestHttpsTransportCleanupOldMessages = TestHttpsTransportCleanupOldMessages,
    TestHttpsTransportHeadersConstruction = TestHttpsTransportHeadersConstruction,
    TestHttpsTransportUrlConstruction = TestHttpsTransportUrlConstruction,
    TestHttpsTransportRequestCounting = TestHttpsTransportRequestCounting,
    TestHttpsTransportFallbackHttpImplementation = TestHttpsTransportFallbackHttpImplementation,
    TestHttpsTransportTimeoutHandling = TestHttpsTransportTimeoutHandling,
    TestHttpsTransportLtn12Integration = TestHttpsTransportLtn12Integration,
    TestHttpsTransportWithoutLtn12 = TestHttpsTransportWithoutLtn12,
    TestHttpsTransportMessageStructureConsistency = TestHttpsTransportMessageStructureConsistency,
    TestHttpsTransportSequenceTrackingConsistency = TestHttpsTransportSequenceTrackingConsistency
}