-- LuaUnit tests for FileTransport class
-- Tests file I/O operations, path management, and IMessageTransport interface implementation
-- Follows Single Responsibility Principle testing - focused on file operations

local luaunit_helpers = require('tests.luaunit_helpers')
local luaunit = require('libs.luaunit')
local FileTransport = require('transports.file_transport')

-- Helper function to set up before each test
local function setUp()
    luaunit_helpers.setup_mock_love_filesystem()
    luaunit_helpers.setup_mock_smods()
end

-- Helper function to tear down after each test
local function tearDown()
    luaunit_helpers.cleanup_mock_love_filesystem()
    luaunit_helpers.cleanup_mock_smods()
end

-- =============================================================================
-- FILETRANSPORT INITIALIZATION TESTS
-- =============================================================================

local function TestFileTransportInitializationWithDefaultPath()
    setUp()
    
    local transport = FileTransport.new()
    
    luaunit.assertNotNil(transport, "FileTransport should initialize with default path")
    luaunit.assertEquals("shared", transport.base_path, "Default base path should be 'shared'")
    luaunit.assertEquals("FILE_TRANSPORT", transport.component_name, "Should set component name")
    luaunit.assertEquals(0, transport.write_success_count, "Should initialize write count to 0")
    luaunit.assertNotNil(transport.json, "Should load JSON library")
    luaunit.assertEquals("table", type(transport.last_read_sequences), "Should initialize sequence tracking")
    
    tearDown()
end

local function TestFileTransportInitializationWithCustomPath()
    setUp()
    
    local transport = FileTransport.new("custom_path")
    
    luaunit.assertNotNil(transport, "FileTransport should initialize with custom path")
    luaunit.assertEquals("custom_path", transport.base_path, "Should set custom base path")
    luaunit.assertTrue(love.filesystem.directories["custom_path"], "Should create custom directory")
    
    tearDown()
end

local function TestFileTransportInitializationWithCurrentDirectory()
    setUp()
    
    local transport = FileTransport.new(".")
    
    luaunit.assertNotNil(transport, "FileTransport should initialize with current directory")
    luaunit.assertEquals(".", transport.base_path, "Should set current directory path")
    luaunit.assertTrue(love.filesystem.directories["."], "Should create current directory")
    
    tearDown()
end

local function TestFileTransportSMODSLoadingFailure()
    setUp()
    
    -- Clear SMODS to test failure case
    _G.SMODS = nil
    
    local success, error_msg = pcall(function()
        FileTransport.new("test_path")
    end)
    
    luaunit.assertFalse(success, "Should fail when SMODS not available")
    luaunit.assertStrContains(tostring(error_msg), "SMODS not available", "Should show SMODS dependency error")
    
    tearDown()
end

-- =============================================================================
-- INTERFACE IMPLEMENTATION TESTS
-- =============================================================================

local function TestFileTransportIsAvailable()
    setUp()
    
    local transport = FileTransport.new("test_path")
    
    luaunit.assertTrue(transport:is_available(), "Should report available when love.filesystem exists")
    
    -- Test with love.filesystem unavailable
    local original_love = love
    love = nil
    
    luaunit.assertFalse(transport:is_available(), "Should report unavailable when love.filesystem missing")
    
    -- Restore love
    love = original_love
    
    tearDown()
end

-- =============================================================================
-- PATH CONSTRUCTION TESTS
-- =============================================================================

local function TestFileTransportGetFilepathWithSubdirectory()
    setUp()
    
    local transport = FileTransport.new("test_shared")
    
    luaunit.assertEquals("test_shared/game_state.json", transport:get_filepath("game_state"), "Should construct subdirectory path for game_state")
    luaunit.assertEquals("test_shared/deck_state.json", transport:get_filepath("deck_state"), "Should construct subdirectory path for deck_state")
    luaunit.assertEquals("test_shared/actions.json", transport:get_filepath("actions"), "Should construct subdirectory path for actions")
    luaunit.assertEquals("test_shared/action_results.json", transport:get_filepath("action_result"), "Should construct subdirectory path for action_result")
    luaunit.assertEquals("test_shared/file_transport_debug.log", transport:get_filepath("debug.log"), "Should construct subdirectory path for debug log")
    
    tearDown()
end

local function TestFileTransportGetFilepathWithCurrentDirectory()
    setUp()
    
    local transport = FileTransport.new(".")
    
    luaunit.assertEquals("game_state.json", transport:get_filepath("game_state"), "Should construct current directory path for game_state")
    luaunit.assertEquals("deck_state.json", transport:get_filepath("deck_state"), "Should construct current directory path for deck_state")
    luaunit.assertEquals("actions.json", transport:get_filepath("actions"), "Should construct current directory path for actions")
    luaunit.assertEquals("action_results.json", transport:get_filepath("action_result"), "Should construct current directory path for action_result")
    luaunit.assertEquals("file_transport_debug.log", transport:get_filepath("debug.log"), "Should construct current directory path for debug log")
    
    tearDown()
end

local function TestFileTransportGetFilepathWithUnknownMessageType()
    setUp()
    
    local transport = FileTransport.new("test_path")
    
    luaunit.assertEquals("test_path/custom_type.json", transport:get_filepath("custom_type"), "Should create JSON filename for unknown message type")
    
    tearDown()
end

-- =============================================================================
-- WRITE MESSAGE TESTS
-- =============================================================================

local function TestFileTransportWriteMessage()
    setUp()
    
    local transport = FileTransport.new("test_shared")
    local test_data = '{"test": "message", "sequence_id": 1}'
    
    local success = transport:write_message(test_data, "game_state")
    
    luaunit.assertTrue(success, "Should successfully write message")
    luaunit.assertEquals(test_data, love.filesystem.files["test_shared/game_state.json"], "Should write data to correct file")
    luaunit.assertEquals(1, transport.write_success_count, "Should increment write success count")
    
    tearDown()
end

local function TestFileTransportWriteMessageWithCurrentDirectory()
    setUp()
    
    local transport = FileTransport.new(".")
    local test_data = '{"test": "message", "sequence_id": 1}'
    
    local success = transport:write_message(test_data, "game_state")
    
    luaunit.assertTrue(success, "Should successfully write message to current directory")
    luaunit.assertEquals(test_data, love.filesystem.files["game_state.json"], "Should write data to current directory file")
    
    tearDown()
end

local function TestFileTransportWriteMessageErrorHandling()
    setUp()
    
    local transport = FileTransport.new("test_shared")
    
    -- Test nil message data
    local success1 = transport:write_message(nil, "game_state")
    luaunit.assertFalse(success1, "Should fail with nil message data")
    
    -- Test nil message type
    local success2 = transport:write_message("test data", nil)
    luaunit.assertFalse(success2, "Should fail with nil message type")
    
    -- Test filesystem unavailable
    local original_love = love
    love = nil
    local success3 = transport:write_message("test data", "game_state")
    luaunit.assertFalse(success3, "Should fail when filesystem unavailable")
    love = original_love
    
    tearDown()
end

-- =============================================================================
-- READ MESSAGE TESTS
-- =============================================================================

local function TestFileTransportReadMessage()
    setUp()
    
    local transport = FileTransport.new("test_shared")
    local test_data = '{"test": "message", "sequence_id": 1}'
    
    -- Setup file to read
    love.filesystem.files["test_shared/game_state.json"] = test_data
    
    local result = transport:read_message("game_state")
    
    luaunit.assertEquals(test_data, result, "Should read message data from file")
    
    tearDown()
end

local function TestFileTransportReadMessageFileNotFound()
    setUp()
    
    local transport = FileTransport.new("test_shared")
    
    local result = transport:read_message("nonexistent")
    
    luaunit.assertNil(result, "Should return nil when file not found")
    
    tearDown()
end

local function TestFileTransportReadActionsWithSequenceTracking()
    setUp()
    
    local transport = FileTransport.new("test_shared")
    local action_data = {
        timestamp = "2024-01-01T00:00:00Z",
        sequence_id = 100,
        message_type = "action",
        data = {action_type = "play_hand"}
    }
    
    -- Setup actions file
    love.filesystem.files["test_shared/actions.json"] = transport.json.encode(action_data)
    
    local result = transport:read_message("actions")
    
    luaunit.assertEquals(transport.json.encode(action_data), result, "Should read actions data")
    luaunit.assertEquals(100, transport.last_read_sequences["actions"], "Should track sequence ID")
    luaunit.assertNil(love.filesystem.files["test_shared/actions.json"], "Should remove actions file after reading")
    
    tearDown()
end

local function TestFileTransportReadActionsSequenceDeduplication()
    setUp()
    
    local transport = FileTransport.new("test_shared")
    local action_data = {
        timestamp = "2024-01-01T00:00:00Z",
        sequence_id = 50,
        message_type = "action",
        data = {action_type = "play_hand"}
    }
    
    -- Set last read sequence higher than current message
    transport.last_read_sequences["actions"] = 100
    
    -- Setup actions file with lower sequence ID
    love.filesystem.files["test_shared/actions.json"] = transport.json.encode(action_data)
    
    local result = transport:read_message("actions")
    
    luaunit.assertNil(result, "Should return nil for already processed sequence")
    luaunit.assertNotNil(love.filesystem.files["test_shared/actions.json"], "Should not remove file for already processed sequence")
    
    tearDown()
end

local function TestFileTransportReadMessageErrorHandling()
    setUp()
    
    local transport = FileTransport.new("test_shared")
    
    -- Test filesystem unavailable
    local original_love = love
    love = nil
    local result = transport:read_message("game_state")
    luaunit.assertNil(result, "Should return nil when filesystem unavailable")
    love = original_love
    
    tearDown()
end

-- =============================================================================
-- VERIFY MESSAGE TESTS
-- =============================================================================

local function TestFileTransportVerifyMessage()
    setUp()
    
    local transport = FileTransport.new("test_shared")
    local test_message = {
        timestamp = "2024-01-01T00:00:00Z",
        sequence_id = 1,
        message_type = "game_state",
        data = {test = "data"}
    }
    local encoded_data = transport.json.encode(test_message)
    
    -- Write file to verify
    love.filesystem.files["test_shared/game_state.json"] = encoded_data
    
    local success = transport:verify_message(encoded_data, "game_state")
    
    luaunit.assertTrue(success, "Should successfully verify message")
    
    tearDown()
end

local function TestFileTransportVerifyMessageCorruption()
    setUp()
    
    local transport = FileTransport.new("test_shared")
    local original_data = '{"test": "original", "sequence_id": 1}'
    
    -- Write corrupted data to file
    love.filesystem.files["test_shared/game_state.json"] = '{"invalid": json}'
    
    local success = transport:verify_message(original_data, "game_state")
    
    luaunit.assertFalse(success, "Should fail verification for corrupted JSON")
    
    tearDown()
end

local function TestFileTransportVerifyMessageFileMissing()
    setUp()
    
    local transport = FileTransport.new("test_shared")
    local test_data = '{"test": "data", "sequence_id": 1}'
    
    local success = transport:verify_message(test_data, "game_state")
    
    luaunit.assertFalse(success, "Should fail verification when file missing")
    
    tearDown()
end

local function TestFileTransportVerifyMessageSequenceIDMismatch()
    setUp()
    
    local transport = FileTransport.new("test_shared")
    local original_message = {sequence_id = 1, data = {test = "original"}}
    local file_message = {sequence_id = 2, data = {test = "different"}}
    
    love.filesystem.files["test_shared/game_state.json"] = transport.json.encode(file_message)
    
    local success = transport:verify_message(transport.json.encode(original_message), "game_state")
    
    -- Should still return true but log warning (verification passes, but logs mismatch)
    luaunit.assertTrue(success, "Should pass verification despite sequence mismatch")
    
    tearDown()
end

-- =============================================================================
-- CLEANUP TESTS
-- =============================================================================

local function TestFileTransportCleanupOldMessages()
    setUp()
    
    local transport = FileTransport.new("test_shared")
    
    -- Create test files with old timestamps
    love.filesystem.files["test_shared/game_state.json"] = '{"test": "data"}'
    love.filesystem.files["test_shared/deck_state.json"] = '{"test": "deck"}'
    love.filesystem.files["test_shared/actions.json"] = '{"test": "action"}'
    love.filesystem.files["test_shared/action_results.json"] = '{"test": "result"}'
    
    -- Mock file info with old modification times
    local original_getInfo = love.filesystem.getInfo
    love.filesystem.getInfo = function(path)
        if love.filesystem.files[path] then
            return {
                type = "file",
                size = #love.filesystem.files[path],
                modtime = os.time() - 600  -- 10 minutes ago
            }
        end
        return nil
    end
    
    -- Run cleanup (max_age = 300 seconds = 5 minutes)
    local success = transport:cleanup_old_messages(300)
    
    luaunit.assertTrue(success, "Should successfully cleanup old messages")
    luaunit.assertNil(love.filesystem.files["test_shared/game_state.json"], "Should remove old game_state.json")
    luaunit.assertNil(love.filesystem.files["test_shared/deck_state.json"], "Should remove old deck_state.json")
    luaunit.assertNil(love.filesystem.files["test_shared/actions.json"], "Should remove old actions.json")
    luaunit.assertNil(love.filesystem.files["test_shared/action_results.json"], "Should remove old action_results.json")
    
    -- Restore original function
    love.filesystem.getInfo = original_getInfo
    
    tearDown()
end

local function TestFileTransportCleanupWithCurrentDirectory()
    setUp()
    
    local transport = FileTransport.new(".")
    
    -- Create test files in current directory
    love.filesystem.files["game_state.json"] = '{"test": "data"}'
    love.filesystem.files["actions.json"] = '{"test": "action"}'
    
    -- Mock file info with old modification times
    local original_getInfo = love.filesystem.getInfo
    love.filesystem.getInfo = function(path)
        if love.filesystem.files[path] then
            return {
                type = "file",
                size = #love.filesystem.files[path],
                modtime = os.time() - 600  -- 10 minutes ago
            }
        end
        return nil
    end
    
    local success = transport:cleanup_old_messages(300)
    
    luaunit.assertTrue(success, "Should successfully cleanup from current directory")
    luaunit.assertNil(love.filesystem.files["game_state.json"], "Should remove old file from current directory")
    luaunit.assertNil(love.filesystem.files["actions.json"], "Should remove old action file from current directory")
    
    -- Restore original function
    love.filesystem.getInfo = original_getInfo
    
    tearDown()
end

local function TestFileTransportCleanupErrorHandling()
    setUp()
    
    local transport = FileTransport.new("test_shared")
    
    -- Test filesystem unavailable
    local original_love = love
    love = nil
    local success = transport:cleanup_old_messages(300)
    luaunit.assertFalse(success, "Should fail cleanup when filesystem unavailable")
    love = original_love
    
    tearDown()
end

-- =============================================================================
-- DIAGNOSTICS AND LOGGING TESTS
-- =============================================================================

local function TestFileTransportDiagnoseWriteFailure()
    setUp()
    
    local transport = FileTransport.new("test_shared")
    
    -- This test verifies the diagnostic method doesn't crash
    -- The actual diagnosis logic is tested indirectly through write failure scenarios
    transport:diagnose_write_failure()
    
    -- Should complete without error
    luaunit.assertTrue(true, "Diagnostic method should complete without error")
    
    tearDown()
end

local function TestFileTransportLogging()
    setUp()
    
    local transport = FileTransport.new("test_shared")
    
    -- Test basic logging
    transport:log("Test log message")
    
    -- Verify log file was created
    local log_content = love.filesystem.files["test_shared/file_transport_debug.log"]
    luaunit.assertNotNil(log_content, "Should create debug log file")
    luaunit.assertStrContains(log_content, "Test log message", "Should contain logged message")
    
    tearDown()
end

local function TestFileTransportLoggingWithCurrentDirectory()
    setUp()
    
    local transport = FileTransport.new(".")
    
    transport:log("Test log message")
    
    -- Verify log file was created in current directory
    local log_content = love.filesystem.files["file_transport_debug.log"]
    luaunit.assertNotNil(log_content, "Should create debug log in current directory")
    luaunit.assertStrContains(log_content, "Test log message", "Should contain logged message")
    
    tearDown()
end

-- =============================================================================
-- ASYNC OPERATION TESTS
-- =============================================================================

local function TestFileTransportAsyncInitialization()
    setUp()
    
    -- Mock love.thread BEFORE creating transport
    local mock_thread = {
        start = function() end,
        isRunning = function() return true end
    }
    
    love.thread = {
        newThread = function(code) return mock_thread end,
        getChannel = function(name) 
            return {
                push = function(data) end,
                pop = function() return nil end,
                demand = function() return nil end
            }
        end
    }
    
    local transport = FileTransport.new("test_shared")
    
    luaunit.assertTrue(transport.async_enabled, "Should enable async operations when threading available")
    luaunit.assertNotNil(transport.worker_thread, "Should create worker thread")
    luaunit.assertNotNil(transport.request_channel, "Should create request channel")
    luaunit.assertNotNil(transport.response_channel, "Should create response channel")
    luaunit.assertEquals(0, transport.request_id_counter, "Should initialize request counter")
    luaunit.assertEquals("table", type(transport.pending_requests), "Should initialize pending requests table")
    
    tearDown()
end

local function TestFileTransportAsyncFallback()
    setUp()
    
    -- Don't mock love.thread - should fallback to sync
    love.thread = nil
    
    local transport = FileTransport.new("test_shared")
    
    luaunit.assertFalse(transport.async_enabled, "Should not enable async when threading unavailable")
    luaunit.assertNil(transport.worker_thread, "Should not create worker thread")
    
    tearDown()
end

local function TestFileTransportAsyncWriteMessage()
    setUp()
    
    -- Mock async environment BEFORE creating transport
    local requests = {}
    local mock_thread = {
        start = function() end,
        isRunning = function() return true end
    }
    
    -- Mock channels by name to ensure same instance is returned
    local mock_channels = {}
    
    love.thread = {
        newThread = function(code) return mock_thread end,
        getChannel = function(name) 
            if not mock_channels[name] then
                mock_channels[name] = {
                    push = function(data) 
                        if name == 'file_requests' then
                            table.insert(requests, data) 
                        end
                    end,
                    pop = function() return nil end,
                    demand = function() return nil end
                }
            end
            return mock_channels[name]
        end
    }
    
    local transport = FileTransport.new("test_shared")
    local callback_called = false
    local callback_success = false
    
    -- Test async write
    local result = transport:write_message('{"test": "data"}', "game_state", function(success)
        callback_called = true
        callback_success = success
    end)
    
    luaunit.assertTrue(result, "Should return true for async operation submission")
    luaunit.assertEquals(1, #requests, "Should submit request to worker thread")
    luaunit.assertNotNil(requests[1], "Should have a request object")
    
    tearDown()
end

local function TestFileTransportAsyncReadMessage()
    setUp()
    
    -- Mock async environment BEFORE creating transport
    local requests = {}
    local mock_thread = {
        start = function() end,
        isRunning = function() return true end
    }
    
    love.thread = {
        newThread = function(code) return mock_thread end,
        getChannel = function(name) 
            return {
                push = function(data) table.insert(requests, data) end,
                pop = function() return nil end,
                demand = function() return nil end
            }
        end
    }
    
    local transport = FileTransport.new("test_shared")
    local callback_called = false
    local callback_success = false
    local callback_data = nil
    
    -- Test async read
    local result = transport:read_message("game_state", function(success, data)
        callback_called = true
        callback_success = success
        callback_data = data
    end)
    
    luaunit.assertNil(result, "Should return nil for async operation")
    luaunit.assertEquals(1, #requests, "Should submit getInfo request first")
    luaunit.assertNotNil(requests[1], "Should have a request object")
    
    tearDown()
end

local function TestFileTransportAsyncUpdate()
    setUp()
    
    -- Mock async environment with responses BEFORE creating transport
    local responses = {
        {id = 1, operation = "write", success = true, data = true},
        {id = 2, operation = "read", success = true, data = '{"test": "content"}'}
    }
    local response_index = 1
    
    local mock_thread = {
        start = function() end,
        isRunning = function() return true end
    }
    
    love.thread = {
        newThread = function(code) return mock_thread end,
        getChannel = function(name) 
            return {
                push = function(data) end,
                pop = function() 
                    if response_index <= #responses then
                        local response = responses[response_index]
                        response_index = response_index + 1
                        return response
                    end
                    return nil
                end,
                demand = function() return nil end
            }
        end
    }
    
    local transport = FileTransport.new("test_shared")
    
    -- Add some pending requests
    transport.pending_requests[1] = {
        callback = function(success, data) 
            luaunit.assertTrue(success, "First callback should succeed")
        end,
        submitted_time = os.clock()
    }
    transport.pending_requests[2] = {
        callback = function(success, data) 
            luaunit.assertTrue(success, "Second callback should succeed")
            luaunit.assertEquals('{"test": "content"}', data, "Should receive correct data")
        end,
        submitted_time = os.clock()
    }
    
    -- Process responses
    transport:update()
    
    luaunit.assertEquals(0, transport:count_pending_requests(), "Should clear pending requests after processing")
    
    tearDown()
end

local function TestFileTransportAsyncCleanup()
    setUp()
    
    -- Mock async environment BEFORE creating transport
    local exit_sent = false
    local mock_thread = {
        start = function() end,
        isRunning = function() return not exit_sent end
    }
    
    love.thread = {
        newThread = function(code) return mock_thread end,
        getChannel = function(name) 
            return {
                push = function(data) 
                    if data.operation == 'exit' then
                        exit_sent = true
                    end
                end,
                pop = function() return nil end,
                demand = function() return nil end
            }
        end
    }
    
    love.timer = {
        sleep = function(duration) end
    }
    
    local transport = FileTransport.new("test_shared")
    luaunit.assertTrue(transport.async_enabled, "Should be async enabled initially")
    
    transport:cleanup()
    
    luaunit.assertFalse(transport.async_enabled, "Should disable async after cleanup")
    luaunit.assertNil(transport.worker_thread, "Should clear worker thread reference")
    
    tearDown()
end

-- Helper function to count pending requests
function FileTransport:count_pending_requests()
    local count = 0
    for _ in pairs(self.pending_requests) do
        count = count + 1
    end
    return count
end

-- Export all test functions for LuaUnit registration
return {
    TestFileTransportInitializationWithDefaultPath = TestFileTransportInitializationWithDefaultPath,
    TestFileTransportInitializationWithCustomPath = TestFileTransportInitializationWithCustomPath,
    TestFileTransportInitializationWithCurrentDirectory = TestFileTransportInitializationWithCurrentDirectory,
    TestFileTransportSMODSLoadingFailure = TestFileTransportSMODSLoadingFailure,
    TestFileTransportIsAvailable = TestFileTransportIsAvailable,
    TestFileTransportGetFilepathWithSubdirectory = TestFileTransportGetFilepathWithSubdirectory,
    TestFileTransportGetFilepathWithCurrentDirectory = TestFileTransportGetFilepathWithCurrentDirectory,
    TestFileTransportGetFilepathWithUnknownMessageType = TestFileTransportGetFilepathWithUnknownMessageType,
    TestFileTransportWriteMessage = TestFileTransportWriteMessage,
    TestFileTransportWriteMessageWithCurrentDirectory = TestFileTransportWriteMessageWithCurrentDirectory,
    TestFileTransportWriteMessageErrorHandling = TestFileTransportWriteMessageErrorHandling,
    TestFileTransportReadMessage = TestFileTransportReadMessage,
    TestFileTransportReadMessageFileNotFound = TestFileTransportReadMessageFileNotFound,
    TestFileTransportReadActionsWithSequenceTracking = TestFileTransportReadActionsWithSequenceTracking,
    TestFileTransportReadActionsSequenceDeduplication = TestFileTransportReadActionsSequenceDeduplication,
    TestFileTransportReadMessageErrorHandling = TestFileTransportReadMessageErrorHandling,
    TestFileTransportVerifyMessage = TestFileTransportVerifyMessage,
    TestFileTransportVerifyMessageCorruption = TestFileTransportVerifyMessageCorruption,
    TestFileTransportVerifyMessageFileMissing = TestFileTransportVerifyMessageFileMissing,
    TestFileTransportVerifyMessageSequenceIDMismatch = TestFileTransportVerifyMessageSequenceIDMismatch,
    TestFileTransportCleanupOldMessages = TestFileTransportCleanupOldMessages,
    TestFileTransportCleanupWithCurrentDirectory = TestFileTransportCleanupWithCurrentDirectory,
    TestFileTransportCleanupErrorHandling = TestFileTransportCleanupErrorHandling,
    TestFileTransportDiagnoseWriteFailure = TestFileTransportDiagnoseWriteFailure,
    TestFileTransportLogging = TestFileTransportLogging,
    TestFileTransportLoggingWithCurrentDirectory = TestFileTransportLoggingWithCurrentDirectory,
    TestFileTransportAsyncInitialization = TestFileTransportAsyncInitialization,
    TestFileTransportAsyncFallback = TestFileTransportAsyncFallback,
    TestFileTransportAsyncWriteMessage = TestFileTransportAsyncWriteMessage,
    TestFileTransportAsyncReadMessage = TestFileTransportAsyncReadMessage,
    TestFileTransportAsyncUpdate = TestFileTransportAsyncUpdate,
    TestFileTransportAsyncCleanup = TestFileTransportAsyncCleanup
}