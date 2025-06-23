-- LuaUnit tests for MessageManager class
-- Tests message creation, metadata management, and transport coordination
-- Follows Single Responsibility Principle testing - focused on message logic

local luaunit_helpers = require('luaunit_helpers')
local luaunit = require('libs.luaunit')
local MessageManager = require('message_manager')

-- Mock transport implementation for testing
local MockTransport = {}
MockTransport.__index = MockTransport

function MockTransport.new()
    local self = setmetatable({}, MockTransport)
    self.written_messages = {}
    self.read_messages = {}
    self.available = true
    self.verify_success = true
    self.cleanup_success = true
    return self
end

function MockTransport:write_message(message_data, message_type)
    if not self.available then return false end
    self.written_messages[message_type] = message_data
    return true
end

function MockTransport:read_message(message_type)
    if not self.available then return nil end
    return self.read_messages[message_type]
end

function MockTransport:verify_message(message_data, message_type)
    if not self.available then return false end
    return self.verify_success
end

function MockTransport:cleanup_old_messages(max_age_seconds)
    if not self.available then return false end
    return self.cleanup_success
end

function MockTransport:is_available()
    return self.available
end

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
-- MESSAGEMANAGER INITIALIZATION TESTS
-- =============================================================================

local function TestMessageManagerInitializationWithValidTransport()
    setUp()
    
    local transport = MockTransport.new()
    local manager = MessageManager.new(transport, "TEST_MANAGER")
    
    luaunit.assertNotNil(manager, "MessageManager should initialize with valid transport")
    luaunit.assertEquals("TEST_MANAGER", manager.component_name, "Should set component name")
    luaunit.assertEquals(0, manager.sequence_id, "Should initialize sequence_id to 0")
    luaunit.assertNotNil(manager.json, "Should load JSON library")
    luaunit.assertEquals(transport, manager.transport, "Should store transport reference")
    
    tearDown()
end

local function TestMessageManagerInitializationWithoutTransport()
    setUp()
    
    local success, error_msg = pcall(function()
        MessageManager.new(nil, "TEST_MANAGER")
    end)
    
    luaunit.assertFalse(success, "Should fail when no transport provided")
    luaunit.assertStrContains(tostring(error_msg), "requires a transport", "Should show transport requirement error")
    
    tearDown()
end

local function TestMessageManagerTransportInterfaceValidation()
    setUp()
    
    -- Create transport missing required methods
    local invalid_transport = {
        write_message = function() end,
        read_message = function() end
        -- Missing verify_message, cleanup_old_messages, is_available
    }
    
    local success, error_msg = pcall(function()
        MessageManager.new(invalid_transport, "TEST_MANAGER")
    end)
    
    luaunit.assertFalse(success, "Should fail when transport missing required methods")
    luaunit.assertStrContains(tostring(error_msg), "missing required method", "Should show missing method error")
    
    tearDown()
end

local function TestMessageManagerSMODSLoadingFailure()
    setUp()
    
    -- Clear SMODS to test failure case
    _G.SMODS = nil
    
    local transport = MockTransport.new()
    local success, error_msg = pcall(function()
        MessageManager.new(transport, "TEST_MANAGER")
    end)
    
    luaunit.assertFalse(success, "Should fail when SMODS not available")
    luaunit.assertStrContains(tostring(error_msg), "SMODS not available", "Should show SMODS dependency error")
    
    tearDown()
end

-- =============================================================================
-- SEQUENCE ID MANAGEMENT TESTS
-- =============================================================================

local function TestMessageManagerSequenceIDIncrement()
    setUp()
    
    local transport = MockTransport.new()
    local manager = MessageManager.new(transport, "TEST_MANAGER")
    
    local id1 = manager:get_next_sequence_id()
    local id2 = manager:get_next_sequence_id()
    local id3 = manager:get_next_sequence_id()
    
    luaunit.assertEquals(1, id1, "First sequence ID should be 1")
    luaunit.assertEquals(2, id2, "Second sequence ID should be 2")
    luaunit.assertEquals(3, id3, "Third sequence ID should be 3")
    
    tearDown()
end

-- =============================================================================
-- MESSAGE CREATION TESTS
-- =============================================================================

local function TestMessageManagerCreateMessageStructure()
    setUp()
    
    local transport = MockTransport.new()
    local manager = MessageManager.new(transport, "TEST_MANAGER")
    
    local test_data = {phase = "test", ante = 1}
    local message = manager:create_message(test_data, "test_type")
    
    luaunit.assertNotNil(message, "Should create message structure")
    luaunit.assertEquals("test_type", message.message_type, "Should set message type")
    luaunit.assertEquals(1, message.sequence_id, "Should set sequence ID")
    luaunit.assertEquals(test_data, message.data, "Should embed data")
    luaunit.assertNotNil(message.timestamp, "Should include timestamp")
    -- Test timestamp format: YYYY-MM-DDTHH:MM:SSZ
    luaunit.assertStrContains(message.timestamp, "T", "Should contain 'T' separator")
    luaunit.assertStrContains(message.timestamp, "Z", "Should end with 'Z'")
    luaunit.assertTrue(string.len(message.timestamp) == 20, "Should be 20 characters long (ISO format)")
    
    tearDown()
end

local function TestMessageManagerCreateMessageErrorHandling()
    setUp()
    
    local transport = MockTransport.new()
    local manager = MessageManager.new(transport, "TEST_MANAGER")
    
    -- Test nil data
    local success1, error1 = pcall(function()
        manager:create_message(nil, "test_type")
    end)
    
    luaunit.assertFalse(success1, "Should fail with nil data")
    luaunit.assertStrContains(tostring(error1), "Message data is required", "Should show data requirement error")
    
    -- Test nil message type
    local success2, error2 = pcall(function()
        manager:create_message({test = "data"}, nil)
    end)
    
    luaunit.assertFalse(success2, "Should fail with nil message type")
    luaunit.assertStrContains(tostring(error2), "Message type is required", "Should show message type requirement error")
    
    tearDown()
end

-- =============================================================================
-- HIGH-LEVEL MESSAGE OPERATION TESTS
-- =============================================================================

local function TestMessageManagerWriteGameState()
    setUp()
    
    local transport = MockTransport.new()
    local manager = MessageManager.new(transport, "TEST_MANAGER")
    
    local game_state = {phase = "hand_selection", ante = 3, money = 150}
    local success = manager:write_game_state(game_state)
    
    luaunit.assertTrue(success, "Should successfully write game state")
    luaunit.assertNotNil(transport.written_messages["game_state"], "Should write message to transport")
    
    -- Verify message structure
    local written_data = transport.written_messages["game_state"]
    local decoded_message = manager.json.decode(written_data)
    luaunit.assertEquals("game_state", decoded_message.message_type, "Should have correct message type")
    luaunit.assertEquals(game_state, decoded_message.data, "Should preserve data")
    luaunit.assertEquals(1, decoded_message.sequence_id, "Should have sequence ID")
    
    tearDown()
end

local function TestMessageManagerWriteDeckState()
    setUp()
    
    local transport = MockTransport.new()
    local manager = MessageManager.new(transport, "TEST_MANAGER")
    
    local deck_state = {
        {id = "card1", rank = "A", suit = "Spades"},
        {id = "card2", rank = "K", suit = "Hearts"}
    }
    local success = manager:write_deck_state(deck_state)
    
    luaunit.assertTrue(success, "Should successfully write deck state")
    luaunit.assertNotNil(transport.written_messages["deck_state"], "Should write message to transport")
    
    -- Verify message structure
    local written_data = transport.written_messages["deck_state"]
    local decoded_message = manager.json.decode(written_data)
    luaunit.assertEquals("deck_state", decoded_message.message_type, "Should have correct message type")
    luaunit.assertEquals(deck_state, decoded_message.data, "Should preserve deck data")
    
    tearDown()
end

local function TestMessageManagerWriteActionResult()
    setUp()
    
    local transport = MockTransport.new()
    local manager = MessageManager.new(transport, "TEST_MANAGER")
    
    local result_data = {success = true, score = 1500, cards_played = 2}
    local success = manager:write_action_result(result_data)
    
    luaunit.assertTrue(success, "Should successfully write action result")
    luaunit.assertNotNil(transport.written_messages["action_result"], "Should write message to transport")
    
    -- Verify message structure
    local written_data = transport.written_messages["action_result"]
    local decoded_message = manager.json.decode(written_data)
    luaunit.assertEquals("action_result", decoded_message.message_type, "Should have correct message type")
    luaunit.assertEquals(result_data, decoded_message.data, "Should preserve result data")
    
    tearDown()
end

local function TestMessageManagerReadActions()
    setUp()
    
    local transport = MockTransport.new()
    local manager = MessageManager.new(transport, "TEST_MANAGER")
    
    -- Setup mock action data
    local action_message = {
        timestamp = "2024-01-01T00:00:00Z",
        sequence_id = 100,
        message_type = "action",
        data = {action_type = "play_hand", cards = {"card1", "card2"}}
    }
    transport.read_messages["actions"] = manager.json.encode(action_message)
    
    local result = manager:read_actions()
    
    luaunit.assertNotNil(result, "Should successfully read actions")
    luaunit.assertEquals(action_message, result, "Should return decoded action message")
    
    tearDown()
end

-- =============================================================================
-- ERROR HANDLING TESTS
-- =============================================================================

local function TestMessageManagerErrorHandlingNilData()
    setUp()
    
    local transport = MockTransport.new()
    local manager = MessageManager.new(transport, "TEST_MANAGER")
    
    local success1 = manager:write_game_state(nil)
    local success2 = manager:write_deck_state(nil)
    local success3 = manager:write_action_result(nil)
    
    luaunit.assertFalse(success1, "Should fail to write nil game state")
    luaunit.assertFalse(success2, "Should fail to write nil deck state")
    luaunit.assertFalse(success3, "Should fail to write nil action result")
    
    tearDown()
end

local function TestMessageManagerErrorHandlingTransportUnavailable()
    setUp()
    
    local transport = MockTransport.new()
    transport.available = false -- Make transport unavailable
    local manager = MessageManager.new(transport, "TEST_MANAGER")
    
    local test_data = {test = "data"}
    local success1 = manager:write_game_state(test_data)
    local success2 = manager:write_deck_state(test_data)
    local success3 = manager:write_action_result(test_data)
    local result = manager:read_actions()
    
    luaunit.assertFalse(success1, "Should fail when transport unavailable")
    luaunit.assertFalse(success2, "Should fail when transport unavailable")
    luaunit.assertFalse(success3, "Should fail when transport unavailable")
    luaunit.assertNil(result, "Should return nil when transport unavailable")
    
    tearDown()
end

local function TestMessageManagerJSONEncodingFailure()
    setUp()
    
    local transport = MockTransport.new()
    local manager = MessageManager.new(transport, "TEST_MANAGER")
    
    -- Mock JSON encoding failure
    local original_encode = manager.json.encode
    manager.json.encode = function() error("JSON encoding failed") end
    
    local test_data = {test = "data"}
    local success1 = manager:write_game_state(test_data)
    local success2 = manager:write_deck_state(test_data)
    local success3 = manager:write_action_result(test_data)
    
    luaunit.assertFalse(success1, "Should fail on JSON encoding error")
    luaunit.assertFalse(success2, "Should fail on JSON encoding error")
    luaunit.assertFalse(success3, "Should fail on JSON encoding error")
    
    -- Restore original function
    manager.json.encode = original_encode
    
    tearDown()
end

local function TestMessageManagerTransportWriteFailure()
    setUp()
    
    local transport = MockTransport.new()
    local manager = MessageManager.new(transport, "TEST_MANAGER")
    
    -- Mock transport write failure
    transport.write_message = function() return false end
    
    local test_data = {test = "data"}
    local success1 = manager:write_game_state(test_data)
    local success2 = manager:write_deck_state(test_data)
    local success3 = manager:write_action_result(test_data)
    
    luaunit.assertFalse(success1, "Should fail when transport write fails")
    luaunit.assertFalse(success2, "Should fail when transport write fails")
    luaunit.assertFalse(success3, "Should fail when transport write fails")
    
    tearDown()
end

local function TestMessageManagerTransportVerificationFailure()
    setUp()
    
    local transport = MockTransport.new()
    transport.verify_success = false -- Make verification fail
    local manager = MessageManager.new(transport, "TEST_MANAGER")
    
    local test_data = {test = "data"}
    local success1 = manager:write_game_state(test_data)
    local success2 = manager:write_deck_state(test_data)
    
    luaunit.assertFalse(success1, "Should fail when verification fails")
    luaunit.assertFalse(success2, "Should fail when verification fails")
    
    tearDown()
end

-- =============================================================================
-- CLEANUP TESTS
-- =============================================================================

local function TestMessageManagerCleanupOldMessages()
    setUp()
    
    local transport = MockTransport.new()
    local manager = MessageManager.new(transport, "TEST_MANAGER")
    
    local success = manager:cleanup_old_messages(300)
    
    luaunit.assertTrue(success, "Should successfully delegate cleanup to transport")
    
    tearDown()
end

local function TestMessageManagerCleanupWithTransportUnavailable()
    setUp()
    
    local transport = MockTransport.new()
    transport.available = false
    local manager = MessageManager.new(transport, "TEST_MANAGER")
    
    local success = manager:cleanup_old_messages(300)
    
    luaunit.assertFalse(success, "Should fail cleanup when transport unavailable")
    
    tearDown()
end

-- Export all test functions for LuaUnit registration
return {
    TestMessageManagerInitializationWithValidTransport = TestMessageManagerInitializationWithValidTransport,
    TestMessageManagerInitializationWithoutTransport = TestMessageManagerInitializationWithoutTransport,
    TestMessageManagerTransportInterfaceValidation = TestMessageManagerTransportInterfaceValidation,
    TestMessageManagerSMODSLoadingFailure = TestMessageManagerSMODSLoadingFailure,
    TestMessageManagerSequenceIDIncrement = TestMessageManagerSequenceIDIncrement,
    TestMessageManagerCreateMessageStructure = TestMessageManagerCreateMessageStructure,
    TestMessageManagerCreateMessageErrorHandling = TestMessageManagerCreateMessageErrorHandling,
    TestMessageManagerWriteGameState = TestMessageManagerWriteGameState,
    TestMessageManagerWriteDeckState = TestMessageManagerWriteDeckState,
    TestMessageManagerWriteActionResult = TestMessageManagerWriteActionResult,
    TestMessageManagerReadActions = TestMessageManagerReadActions,
    TestMessageManagerErrorHandlingNilData = TestMessageManagerErrorHandlingNilData,
    TestMessageManagerErrorHandlingTransportUnavailable = TestMessageManagerErrorHandlingTransportUnavailable,
    TestMessageManagerJSONEncodingFailure = TestMessageManagerJSONEncodingFailure,
    TestMessageManagerTransportWriteFailure = TestMessageManagerTransportWriteFailure,
    TestMessageManagerTransportVerificationFailure = TestMessageManagerTransportVerificationFailure,
    TestMessageManagerCleanupOldMessages = TestMessageManagerCleanupOldMessages,
    TestMessageManagerCleanupWithTransportUnavailable = TestMessageManagerCleanupWithTransportUnavailable
}