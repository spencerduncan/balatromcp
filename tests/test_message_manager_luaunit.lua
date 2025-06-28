-- LuaUnit tests for MessageManager class
-- Tests message creation, metadata management, and transport coordination
-- Follows Single Responsibility Principle testing - focused on message logic

local luaunit_helpers = require('tests.luaunit_helpers')
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

local function TestMessageManagerWriteFullDeck()
    setUp()
    
    local transport = MockTransport.new()
    local manager = MessageManager.new(transport, "TEST_MANAGER")
    
    local full_deck_data = {
        session_id = "session_1234567890_abcd",
        timestamp = 1234567890,
        card_count = 52,
        cards = {
            {id = 0.99878375925668, rank = "A", suit = "Spades", enhancement = "none", edition = "none", seal = "none"},
            {id = 0.42391847392847, rank = "2", suit = "Hearts", enhancement = "mult", edition = "foil", seal = "red"}
        }
    }
    local success = manager:write_full_deck(full_deck_data)
    
    luaunit.assertTrue(success, "Should successfully write full deck data")
    luaunit.assertNotNil(transport.written_messages["full_deck"], "Should write message to transport")
    
    -- Verify message structure
    local written_data = transport.written_messages["full_deck"]
    local decoded_message = manager.json.decode(written_data)
    luaunit.assertEquals("full_deck", decoded_message.message_type, "Should have correct message type")
    luaunit.assertEquals(full_deck_data, decoded_message.data, "Should preserve full deck data")
    luaunit.assertEquals(2, #decoded_message.data.cards, "Should preserve all cards in deck")
    luaunit.assertEquals("session_1234567890_abcd", decoded_message.data.session_id, "Should preserve session ID")
    luaunit.assertEquals(52, decoded_message.data.card_count, "Should preserve card count")
    
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

local function TestMessageManagerWriteHandLevels()
    setUp()
    
    local transport = MockTransport.new()
    local manager = MessageManager.new(transport, "TEST_MANAGER")
    
    local hand_levels_data = {
        session_id = "test_session_123",
        hand_levels = {
            ["High Card"] = {level = 1, times_played = 5, chips = 5, mult = 1},
            ["Pair"] = {level = 2, times_played = 8, chips = 20, mult = 3},
            ["Two Pair"] = {level = 1, times_played = 3, chips = 20, mult = 2},
            ["Flush"] = {level = 3, times_played = 6, chips = 105, mult = 7}
        }
    }
    
    local success = manager:write_hand_levels(hand_levels_data)
    
    luaunit.assertTrue(success, "Should successfully write hand levels")
    luaunit.assertNotNil(transport.written_messages["hand_levels"], "Should write message to transport")
    
    -- Verify message structure matches JSON specification
    local written_data = transport.written_messages["hand_levels"]
    local decoded_message = manager.json.decode(written_data)
    
    luaunit.assertEquals("test_session_123", decoded_message.session_id, "Should preserve session ID")
    luaunit.assertNotNil(decoded_message.timestamp, "Should include timestamp")
    luaunit.assertEquals(22, decoded_message.total_hands_played, "Should calculate total hands played (5+8+3+6)")
    luaunit.assertNotNil(decoded_message.hands, "Should include hands data")
    
    -- Verify specific hand data preservation
    luaunit.assertEquals(2, decoded_message.hands["Pair"].level, "Should preserve Pair level")
    luaunit.assertEquals(8, decoded_message.hands["Pair"].times_played, "Should preserve Pair times_played")
    luaunit.assertEquals(20, decoded_message.hands["Pair"].chips, "Should preserve Pair chips")
    luaunit.assertEquals(3, decoded_message.hands["Pair"].mult, "Should preserve Pair mult")
    
    luaunit.assertEquals(3, decoded_message.hands["Flush"].level, "Should preserve Flush level")
    luaunit.assertEquals(6, decoded_message.hands["Flush"].times_played, "Should preserve Flush times_played")
    
    tearDown()
end

local function TestMessageManagerWriteHandLevelsWithNilData()
    setUp()
    
    local transport = MockTransport.new()
    local manager = MessageManager.new(transport, "TEST_MANAGER")
    
    local success = manager:write_hand_levels(nil)
    
    luaunit.assertFalse(success, "Should fail when hand levels data is nil")
    luaunit.assertNil(transport.written_messages["hand_levels"], "Should not write message when data is nil")
    
    tearDown()
end

local function TestMessageManagerWriteHandLevelsWithTransportUnavailable()
    setUp()
    
    local transport = MockTransport.new()
    transport.available = false
    local manager = MessageManager.new(transport, "TEST_MANAGER")
    
    local hand_levels_data = {
        session_id = "test_session",
        hand_levels = {["Pair"] = {level = 1, times_played = 0, chips = 10, mult = 2}}
    }
    
    local success = manager:write_hand_levels(hand_levels_data)
    
    luaunit.assertFalse(success, "Should fail when transport unavailable")
    
    tearDown()
end

local function TestMessageManagerCalculateTotalHandsPlayed()
    setUp()
    
    local transport = MockTransport.new()
    local manager = MessageManager.new(transport, "TEST_MANAGER")
    
    -- Test with complete hand data
    local hands_data = {
        ["High Card"] = {times_played = 5},
        ["Pair"] = {times_played = 8},
        ["Flush"] = {times_played = 3}
    }
    local total = manager:calculate_total_hands_played(hands_data)
    luaunit.assertEquals(16, total, "Should sum all times_played values")
    
    -- Test with nil data
    total = manager:calculate_total_hands_played(nil)
    luaunit.assertEquals(0, total, "Should return 0 for nil data")
    
    -- Test with empty data
    total = manager:calculate_total_hands_played({})
    luaunit.assertEquals(0, total, "Should return 0 for empty data")
    
    -- Test with missing times_played fields
    local incomplete_hands = {
        ["Pair"] = {level = 2},  -- Missing times_played
        ["Flush"] = {times_played = 5}
    }
    total = manager:calculate_total_hands_played(incomplete_hands)
    luaunit.assertEquals(5, total, "Should handle missing times_played fields")
    
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
    TestMessageManagerWriteFullDeck = TestMessageManagerWriteFullDeck,
    TestMessageManagerReadActions = TestMessageManagerReadActions,
    TestMessageManagerErrorHandlingNilData = TestMessageManagerErrorHandlingNilData,
    TestMessageManagerErrorHandlingTransportUnavailable = TestMessageManagerErrorHandlingTransportUnavailable,
    TestMessageManagerJSONEncodingFailure = TestMessageManagerJSONEncodingFailure,
    TestMessageManagerTransportWriteFailure = TestMessageManagerTransportWriteFailure,
    TestMessageManagerTransportVerificationFailure = TestMessageManagerTransportVerificationFailure,
    TestMessageManagerCleanupOldMessages = TestMessageManagerCleanupOldMessages,
    TestMessageManagerCleanupWithTransportUnavailable = TestMessageManagerCleanupWithTransportUnavailable,
    TestMessageManagerWriteHandLevels = TestMessageManagerWriteHandLevels,
    TestMessageManagerWriteHandLevelsWithNilData = TestMessageManagerWriteHandLevelsWithNilData,
    TestMessageManagerWriteHandLevelsWithTransportUnavailable = TestMessageManagerWriteHandLevelsWithTransportUnavailable,
    TestMessageManagerCalculateTotalHandsPlayed = TestMessageManagerCalculateTotalHandsPlayed
}