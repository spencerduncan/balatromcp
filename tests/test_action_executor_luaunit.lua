-- LuaUnit tests for ActionExecutor NYI (Not Yet Implemented) methods
-- Tests parameter validation and NYI error handling for new action methods

local luaunit = require('libs.luaunit')
local luaunit_helpers = require('tests.luaunit_helpers')

-- =============================================================================
-- SHARED SETUP AND TEARDOWN FUNCTIONALITY
-- =============================================================================

local test_state = {}

local function setUp()
    -- Save original globals
    test_state.original_g = G
    
    -- Set up clean environment
    G = nil
end

local function tearDown()
    -- Restore original globals
    G = test_state.original_g
end

-- =============================================================================
-- MOVE PLAYING CARD NYI TESTS
-- =============================================================================

function testActionExecutorMovePlayingCardMissingFromIndex()
    setUp()
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    local action_data = {
        to_index = 1
        -- Missing from_index
    }
    
    local success, error_message = executor:execute_move_playing_card(action_data)
    luaunit.assertEquals(false, success, "Should return false for missing from_index")
    luaunit.assertEquals("Invalid from index", error_message, "Should return correct error message")
    tearDown()
end

function testActionExecutorMovePlayingCardInvalidFromIndex()
    setUp()
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    local action_data = {
        from_index = -1,
        to_index = 1
    }
    
    local success, error_message = executor:execute_move_playing_card(action_data)
    luaunit.assertEquals(false, success, "Should return false for negative from_index")
    luaunit.assertEquals("Invalid from index", error_message, "Should return correct error message")
    tearDown()
end

function testActionExecutorMovePlayingCardMissingToIndex()
    setUp()
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    local action_data = {
        from_index = 0
        -- Missing to_index
    }
    
    local success, error_message = executor:execute_move_playing_card(action_data)
    luaunit.assertEquals(false, success, "Should return false for missing to_index")
    luaunit.assertEquals("Invalid to index", error_message, "Should return correct error message")
    tearDown()
end

function testActionExecutorMovePlayingCardInvalidToIndex()
    setUp()
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    local action_data = {
        from_index = 0,
        to_index = -1
    }
    
    local success, error_message = executor:execute_move_playing_card(action_data)
    luaunit.assertEquals(false, success, "Should return false for negative to_index")
    luaunit.assertEquals("Invalid to index", error_message, "Should return correct error message")
    tearDown()
end

function testActionExecutorMovePlayingCardNYIError()
    setUp()
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    local action_data = {
        from_index = 0,
        to_index = 1
    }
    
    local success, error_message = executor:execute_move_playing_card(action_data)
    luaunit.assertEquals(false, success, "Should return false for NYI implementation")
    luaunit.assertEquals("Move playing card action not yet implemented", error_message, "Should return NYI error message")
    tearDown()
end

-- =============================================================================
-- SKIP BLIND NYI TESTS
-- =============================================================================

function testActionExecutorSkipBlindMissingGlobalState()
    setUp()
    G = nil -- No global G object
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    local action_data = {}
    
    local success, error_message = executor:execute_skip_blind(action_data)
    luaunit.assertEquals(false, success, "Should return false when G is missing")
    luaunit.assertEquals("Game state not available", error_message, "Should return correct error message")
    tearDown()
end

function testActionExecutorSkipBlindMissingGState()
    setUp()
    G = {} -- G exists but missing STATE
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    local action_data = {}
    
    local success, error_message = executor:execute_skip_blind(action_data)
    luaunit.assertEquals(false, success, "Should return false when G.STATE is missing")
    luaunit.assertEquals("Game state not available", error_message, "Should return correct error message")
    tearDown()
end

function testActionExecutorSkipBlindMissingGStates()
    setUp()
    G = {
        STATE = 1
        -- Missing STATES
    }
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    local action_data = {}
    
    local success, error_message = executor:execute_skip_blind(action_data)
    luaunit.assertEquals(false, success, "Should return false when G.STATES is missing")
    luaunit.assertEquals("Game state not available", error_message, "Should return correct error message")
    tearDown()
end

function testActionExecutorSkipBlindWrongGameState()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_state = true,
        state_value = 1, -- Not BLIND_SELECT
        states = {BLIND_SELECT = 2, SELECTING_HAND = 1}
    })
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    local action_data = {}
    
    local success, error_message = executor:execute_skip_blind(action_data)
    luaunit.assertEquals(false, success, "Should return false when not in blind selection state")
    luaunit.assertTrue(string.find(error_message, "Cannot skip blind, must be in blind selection state"), "Should return correct error message")
    tearDown()
end

function testActionExecutorSkipBlindCorrectStateButNYI()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_state = true,
        state_value = 2, -- BLIND_SELECT
        states = {BLIND_SELECT = 2, SELECTING_HAND = 1}
    })
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    local action_data = {}
    
    local success, error_message = executor:execute_skip_blind(action_data)
    luaunit.assertEquals(false, success, "Should return false for NYI implementation")
    luaunit.assertEquals("Skip blind action not yet implemented", error_message, "Should return NYI error message")
    tearDown()
end

-- =============================================================================
-- INTEGRATION TESTS WITH EXECUTE_ACTION
-- =============================================================================

function testActionExecutorExecuteActionMovePlayingCard()
    setUp()
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    local action_data = {
        action_type = "move_playing_card",
        from_index = 0,
        to_index = 1
    }
    
    local result = executor:execute_action(action_data)
    luaunit.assertEquals(false, result.success, "Should return false for NYI action")
    luaunit.assertEquals("Move playing card action not yet implemented", result.error_message, "Should return NYI error message")
    luaunit.assertNil(result.new_state, "Should not return new state on failure")
    tearDown()
end

function testActionExecutorExecuteActionSkipBlind()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_state = true,
        state_value = 2, -- BLIND_SELECT
        states = {BLIND_SELECT = 2, SELECTING_HAND = 1}
    })
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    local action_data = {
        action_type = "skip_blind"
    }
    
    local result = executor:execute_action(action_data)
    luaunit.assertEquals(false, result.success, "Should return false for NYI action")
    luaunit.assertEquals("Skip blind action not yet implemented", result.error_message, "Should return NYI error message")
    luaunit.assertNil(result.new_state, "Should not return new state on failure")
    tearDown()
end

-- Return all test functions as a table for LuaUnit runner
return {
    testActionExecutorMovePlayingCardMissingFromIndex = testActionExecutorMovePlayingCardMissingFromIndex,
    testActionExecutorMovePlayingCardInvalidFromIndex = testActionExecutorMovePlayingCardInvalidFromIndex,
    testActionExecutorMovePlayingCardMissingToIndex = testActionExecutorMovePlayingCardMissingToIndex,
    testActionExecutorMovePlayingCardInvalidToIndex = testActionExecutorMovePlayingCardInvalidToIndex,
    testActionExecutorMovePlayingCardNYIError = testActionExecutorMovePlayingCardNYIError,
    testActionExecutorSkipBlindMissingGlobalState = testActionExecutorSkipBlindMissingGlobalState,
    testActionExecutorSkipBlindMissingGState = testActionExecutorSkipBlindMissingGState,
    testActionExecutorSkipBlindMissingGStates = testActionExecutorSkipBlindMissingGStates,
    testActionExecutorSkipBlindWrongGameState = testActionExecutorSkipBlindWrongGameState,
    testActionExecutorSkipBlindCorrectStateButNYI = testActionExecutorSkipBlindCorrectStateButNYI,
    testActionExecutorExecuteActionMovePlayingCard = testActionExecutorExecuteActionMovePlayingCard,
    testActionExecutorExecuteActionSkipBlind = testActionExecutorExecuteActionSkipBlind
}