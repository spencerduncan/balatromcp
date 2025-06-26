-- LuaUnit tests for PhaseExtractor
-- Tests current game phase detection

local luaunit = require('libs.luaunit')
local luaunit_helpers = require('tests.luaunit_helpers')

-- =============================================================================
-- SETUP AND TEARDOWN
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
-- PHASE EXTRACTOR TESTS
-- =============================================================================

function testPhaseExtractorExtractMissingGState()
    setUp()
    G = {}
    local PhaseExtractor = require("state_extractor.extractors.phase_extractor")
    local extractor = PhaseExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("hand_selection", result.current_phase, "Should return default phase when G.STATE missing")
    tearDown()
end

function testPhaseExtractorExtractMissingGStates()
    setUp()
    G = {
        STATE = 1
        -- Missing STATES
    }
    local PhaseExtractor = require("state_extractor.extractors.phase_extractor")
    local extractor = PhaseExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("hand_selection", result.current_phase, "Should return default phase when G.STATES missing")
    tearDown()
end

function testPhaseExtractorExtractValidHandSelectionState()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_state = true,
        state_value = 1,
        states = {SELECTING_HAND = 1, SHOP = 2, BLIND_SELECT = 3}
    })
    local PhaseExtractor = require("state_extractor.extractors.phase_extractor")
    local extractor = PhaseExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("hand_selection", result.current_phase, "Should return correct phase for valid state")
    tearDown()
end

function testPhaseExtractorExtractValidShopState()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_state = true,
        state_value = 4,
        states = {SELECTING_HAND = 1, SHOP = 4, BLIND_SELECT = 3}
    })
    local PhaseExtractor = require("state_extractor.extractors.phase_extractor")
    local extractor = PhaseExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("shop", result.current_phase, "Should return shop phase for shop state")
    tearDown()
end

function testPhaseExtractorExtractValidBlindSelectState()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_state = true,
        state_value = 5,
        states = {SELECTING_HAND = 1, SHOP = 4, BLIND_SELECT = 5}
    })
    local PhaseExtractor = require("state_extractor.extractors.phase_extractor")
    local extractor = PhaseExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("blind_selection", result.current_phase, "Should return blind_selection phase for blind select state")
    tearDown()
end

function testPhaseExtractorExtractPackOpeningState()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_state = true,
        state_value = 8,
        states = {SELECTING_HAND = 1, STANDARD_PACK = 8, BUFFOON_PACK = 9}
    })
    local PhaseExtractor = require("state_extractor.extractors.phase_extractor")
    local extractor = PhaseExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("pack_opening", result.current_phase, "Should return pack_opening phase for pack opening state")
    tearDown()
end

function testPhaseExtractorExtractGameOverState()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_state = true,
        state_value = 19,
        states = {SELECTING_HAND = 1, GAME_OVER = 19}
    })
    local PhaseExtractor = require("state_extractor.extractors.phase_extractor")
    local extractor = PhaseExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("game_over", result.current_phase, "Should return game_over phase for game over state")
    tearDown()
end

function testPhaseExtractorExtractUnknownState()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_state = true,
        state_value = 999, -- Unknown state
        states = {SELECTING_HAND = 1, SHOP = 4}
    })
    local PhaseExtractor = require("state_extractor.extractors.phase_extractor")
    local extractor = PhaseExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("hand_selection", result.current_phase, "Should return default phase for unknown state")
    tearDown()
end

function testPhaseExtractorGetName()
    setUp()
    local PhaseExtractor = require("state_extractor.extractors.phase_extractor")
    local extractor = PhaseExtractor.new()
    
    luaunit.assertEquals("phase_extractor", extractor:get_name(), "Should return correct extractor name")
    tearDown()
end

function testPhaseExtractorValidateGObjectMissingG()
    setUp()
    G = nil
    local PhaseExtractor = require("state_extractor.extractors.phase_extractor")
    local extractor = PhaseExtractor.new()
    
    local result = extractor:validate_g_object()
    luaunit.assertEquals(false, result, "Should return false when G is nil")
    tearDown()
end

function testPhaseExtractorValidateGObjectCompleteG()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_state = true,
        has_game = true,
        has_hand = true,
        has_jokers = true,
        has_consumables = true,
        has_shop = true,
        has_funcs = true
    })
    local PhaseExtractor = require("state_extractor.extractors.phase_extractor")
    local extractor = PhaseExtractor.new()
    
    local result = extractor:validate_g_object()
    luaunit.assertEquals(true, result, "Should return true when G has all critical properties")
    tearDown()
end

function testPhaseExtractorGetCurrentPhaseDirectCall()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_state = true,
        state_value = 1,
        states = {SELECTING_HAND = 1, SHOP = 2}
    })
    local PhaseExtractor = require("state_extractor.extractors.phase_extractor")
    local extractor = PhaseExtractor.new()
    
    local result = extractor:get_current_phase()
    luaunit.assertEquals("hand_selection", result, "Direct call should return correct phase")
    tearDown()
end

-- Return all test functions as a table for LuaUnit runner
return {
    testPhaseExtractorExtractMissingGState = testPhaseExtractorExtractMissingGState,
    testPhaseExtractorExtractMissingGStates = testPhaseExtractorExtractMissingGStates,
    testPhaseExtractorExtractValidHandSelectionState = testPhaseExtractorExtractValidHandSelectionState,
    testPhaseExtractorExtractValidShopState = testPhaseExtractorExtractValidShopState,
    testPhaseExtractorExtractValidBlindSelectState = testPhaseExtractorExtractValidBlindSelectState,
    testPhaseExtractorExtractPackOpeningState = testPhaseExtractorExtractPackOpeningState,
    testPhaseExtractorExtractGameOverState = testPhaseExtractorExtractGameOverState,
    testPhaseExtractorExtractUnknownState = testPhaseExtractorExtractUnknownState,
    testPhaseExtractorGetName = testPhaseExtractorGetName,
    testPhaseExtractorValidateGObjectMissingG = testPhaseExtractorValidateGObjectMissingG,
    testPhaseExtractorValidateGObjectCompleteG = testPhaseExtractorValidateGObjectCompleteG,
    testPhaseExtractorGetCurrentPhaseDirectCall = testPhaseExtractorGetCurrentPhaseDirectCall
}