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
    luaunit.assertNotNil(string.find(error_message, "Cannot skip blind, must be in blind selection state"), "Should return correct error message")
    tearDown()
end

function testActionExecutorSkipBlindCorrectStateButNYI()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_state = true,
        state_value = 2, -- BLIND_SELECT
        states = {BLIND_SELECT = 2, SELECTING_HAND = 1}
        -- Missing FUNCS - this will trigger the "function not available" error
    })
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    local action_data = {}
    
    local success, error_message = executor:execute_skip_blind(action_data)
    luaunit.assertEquals(false, success, "Should return false when skip function not available")
    luaunit.assertEquals("Skip blind function not available", error_message, "Should return skip function not available error message")
    tearDown()
end

function testActionExecutorSkipBlindMissingFuncs()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_state = true,
        state_value = 2, -- BLIND_SELECT
        states = {BLIND_SELECT = 2, SELECTING_HAND = 1}
        -- Missing FUNCS
    })
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    local action_data = {}
    
    local success, error_message = executor:execute_skip_blind(action_data)
    luaunit.assertEquals(false, success, "Should return false when G.FUNCS is missing")
    luaunit.assertEquals("Skip blind function not available", error_message, "Should return correct error message")
    tearDown()
end

function testActionExecutorSkipBlindMissingSkipFunction()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_state = true,
        state_value = 2, -- BLIND_SELECT
        states = {BLIND_SELECT = 2, SELECTING_HAND = 1},
        funcs = {} -- Empty FUNCS, missing skip_blind
    })
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    local action_data = {}
    
    local success, error_message = executor:execute_skip_blind(action_data)
    luaunit.assertEquals(false, success, "Should return false when skip_blind function is missing")
    luaunit.assertEquals("Skip blind function not available", error_message, "Should return correct error message")
    tearDown()
end

function testActionExecutorSkipBlindFunctionError()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_state = true,
        state_value = 2, -- BLIND_SELECT
        states = {BLIND_SELECT = 2, SELECTING_HAND = 1},
        funcs = {
            skip_blind = function(button)
                error("Test skip function error")
            end
        },
        blind_select_opts = {
            skip = {
                get_UIE_by_ID = function(self, id)
                    if id == "skip_blind_button" then
                        return {config = {button = "skip_blind"}}
                    end
                    return nil
                end
            }
        }
    })
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    local action_data = {}
    
    local success, error_message = executor:execute_skip_blind(action_data)
    luaunit.assertEquals(false, success, "Should return false when function throws error")
    luaunit.assertNotNil(error_message and string.find(error_message, "Skip blind failed"), "Should contain 'Skip blind failed' in error message")
    tearDown()
end

function testActionExecutorSkipBlindSuccessful()
    setUp()
    local skip_called = false
    G = luaunit_helpers.create_mock_g({
        has_state = true,
        state_value = 2, -- BLIND_SELECT
        states = {BLIND_SELECT = 2, SELECTING_HAND = 1},
        funcs = {
            skip_blind = function(button)
                skip_called = true
                return true
            end
        },
        blind_select_opts = {
            skip = {
                get_UIE_by_ID = function(self, id)
                    if id == "skip_blind_button" then
                        return {config = {button = "skip_blind"}}
                    end
                    return nil
                end
            }
        }
    })
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    local action_data = {}
    
    local success, error_message = executor:execute_skip_blind(action_data)
    luaunit.assertEquals(true, success, "Should return true for successful skip")
    luaunit.assertNil(error_message, "Should not return error message on success")
    luaunit.assertEquals(true, skip_called, "Should call skip_blind function")
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
        -- Missing FUNCS - this will trigger the "function not available" error
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
    luaunit.assertEquals(false, result.success, "Should return false when function not available")
    luaunit.assertEquals("Skip blind function not available", result.error_message, "Should return function not available error message")
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
    testActionExecutorSkipBlindMissingFuncs = testActionExecutorSkipBlindMissingFuncs,
    testActionExecutorSkipBlindMissingSkipFunction = testActionExecutorSkipBlindMissingSkipFunction,
    testActionExecutorSkipBlindFunctionError = testActionExecutorSkipBlindFunctionError,
    testActionExecutorSkipBlindSuccessful = testActionExecutorSkipBlindSuccessful,
    testActionExecutorExecuteActionMovePlayingCard = testActionExecutorExecuteActionMovePlayingCard,
    testActionExecutorExecuteActionSkipBlind = testActionExecutorExecuteActionSkipBlind
}