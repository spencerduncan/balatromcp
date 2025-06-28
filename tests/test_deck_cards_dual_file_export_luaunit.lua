-- LuaUnit tests for dual-file deck cards export functionality (Issue #88)
-- Tests separation of deck_cards from main game_state.json to separate deck_state.json

local luaunit_helpers = require('tests.luaunit_helpers')
local luaunit = require('libs.luaunit')

-- Mock dependencies for testing
local function setup_test_environment()
    luaunit_helpers.setup_mock_love_filesystem()
    luaunit_helpers.setup_mock_g_object()
    luaunit_helpers.setup_mock_smods()
end

-- Mock transport for tracking dual file writes
local MockDualFileTransport = {}
MockDualFileTransport.__index = MockDualFileTransport

function MockDualFileTransport.new()
    local self = setmetatable({}, MockDualFileTransport)
    self.written_files = {}
    self.available = true
    return self
end

function MockDualFileTransport:write_message(message_data, message_type)
    if not self.available then return false end
    self.written_files[message_type] = message_data
    return true
end

function MockDualFileTransport:read_message(message_type)
    return self.written_files[message_type]
end

function MockDualFileTransport:verify_message(message_data, message_type)
    return true
end

function MockDualFileTransport:cleanup_old_messages(max_age_seconds)
    return true
end

function MockDualFileTransport:is_available()
    return self.available
end

-- Test that deck_cards are removed from main game_state.json
function testDeckCardsRemovedFromMainGameState()
    setup_test_environment()
    
    -- Mock deck cards data
    G.playing_cards = {
        {unique_val = 1, base = {value = "A", suit = "Spades"}},
        {unique_val = 2, base = {value = "2", suit = "Hearts"}}
    }
    G.deck = {cards = {}}
    
    local MessageManager = require('message_manager')
    local StateExtractor = require('state_extractor.state_extractor')
    
    local transport = MockDualFileTransport.new()
    local message_manager = MessageManager.new(transport, "TEST")
    local state_extractor = StateExtractor.new()
    
    -- Extract state and write via message manager
    local state = state_extractor:extract_current_state()
    local state_message = {
        timestamp = os.time(),
        sequence_id = 1,
        message_type = "game_state",
        data = state
    }
    
    message_manager:write_game_state(state_message)
    
    -- Verify main game state does NOT contain deck_cards
    local written_game_state = transport.written_files["game_state"]
    luaunit.assertNotNil(written_game_state)
    
    local json = require('libs.json')
    local decoded_state = json.decode(written_game_state)
    
    -- The main game state should NOT have deck_cards field
    luaunit.assertNil(decoded_state.data.deck_cards, "deck_cards should be removed from main game state")
    
    -- But it should still have other card data
    luaunit.assertNotNil(decoded_state.data.hand_cards, "hand_cards should remain in main game state")
end

-- Test that deck_state.json is created with proper structure
function testDeckStateExportCreation()
    setup_test_environment()
    
    -- Mock deck cards data
    G.playing_cards = {
        {unique_val = 1, base = {value = "A", suit = "Spades"}},
        {unique_val = 2, base = {value = "2", suit = "Hearts"}}
    }
    
    local MessageManager = require('message_manager')
    local transport = MockDualFileTransport.new()
    local message_manager = MessageManager.new(transport, "TEST")
    
    -- Test direct deck_state writing
    local deck_data = {
        session_id = "test_session",
        timestamp = os.time(),
        card_count = 2,
        deck_cards = {
            {id = 1, rank = "A", suit = "Spades"},
            {id = 2, rank = "2", suit = "Hearts"}
        }
    }
    
    local success = message_manager:write_deck_state(deck_data)
    luaunit.assertTrue(success)
    
    -- Verify deck_state.json was created
    local written_deck_state = transport.written_files["deck_state"]
    luaunit.assertNotNil(written_deck_state)
    
    local json = require('libs.json')
    local decoded_deck_state = json.decode(written_deck_state)
    
    -- Verify deck state structure
    luaunit.assertEquals(decoded_deck_state.message_type, "deck_state")
    luaunit.assertNotNil(decoded_deck_state.data.deck_cards)
    luaunit.assertEquals(#decoded_deck_state.data.deck_cards, 2)
    luaunit.assertEquals(decoded_deck_state.data.card_count, 2)
end

-- Test atomic updates: both files should be written or neither
function testAtomicDualFileUpdate()
    setup_test_environment()
    
    -- This test would verify that both game_state.json and deck_state.json
    -- are updated together in the actual BalatroMCP implementation
    -- For now, we verify that the methods exist and work independently
    
    local MessageManager = require('message_manager')
    local transport = MockDualFileTransport.new()
    local message_manager = MessageManager.new(transport, "TEST")
    
    -- Test that both write methods exist and function
    luaunit.assertNotNil(message_manager.write_game_state)
    luaunit.assertNotNil(message_manager.write_deck_state)
    
    -- Test successful dual write
    local game_state_success = message_manager:write_game_state({
        timestamp = os.time(),
        message_type = "game_state", 
        data = {hand_cards = {}}
    })
    
    local deck_state_success = message_manager:write_deck_state({
        session_id = "test",
        deck_cards = {}
    })
    
    luaunit.assertTrue(game_state_success)
    luaunit.assertTrue(deck_state_success)
    
    -- Verify both files were written
    luaunit.assertNotNil(transport.written_files["game_state"])
    luaunit.assertNotNil(transport.written_files["deck_state"])
end

-- Test error handling in dual file operations
function testDualFileErrorHandling()
    setup_test_environment()
    
    local MessageManager = require('message_manager')
    local transport = MockDualFileTransport.new()
    local message_manager = MessageManager.new(transport, "TEST")
    
    -- Test with nil data
    local deck_state_result = message_manager:write_deck_state(nil)
    luaunit.assertFalse(deck_state_result)
    
    -- Test with transport unavailable
    transport.available = false
    local game_state_result = message_manager:write_game_state({
        timestamp = os.time(),
        message_type = "game_state",
        data = {}
    })
    luaunit.assertFalse(game_state_result)
    
    deck_state_result = message_manager:write_deck_state({
        session_id = "test",
        deck_cards = {}
    })
    luaunit.assertFalse(deck_state_result)
end

return {
    testDeckCardsRemovedFromMainGameState = testDeckCardsRemovedFromMainGameState,
    testDeckStateExportCreation = testDeckStateExportCreation,
    testAtomicDualFileUpdate = testAtomicDualFileUpdate,
    testDualFileErrorHandling = testDualFileErrorHandling
}