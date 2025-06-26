-- Test file for StateExtractor orchestrator
-- Tests main orchestration and coordination of all extractors

local luaunit = require('luaunit')
local StateExtractor = require("state_extractor.state_extractor")
local IExtractor = require("state_extractor.extractors.i_extractor")

-- Test helper functions
local function create_mock_extractor(name, extract_result)
    local extractor = {}
    
    function extractor:get_name()
        return name
    end
    
    function extractor:extract()
        return extract_result
    end
    
    return extractor
end

local function create_failing_extractor(name, error_message)
    local extractor = {}
    
    function extractor:get_name()
        return name
    end
    
    function extractor:extract()
        error(error_message or "Test error")
    end
    
    return extractor
end

local function create_mock_g_complete()
    return {
        STATE = "selecting_hand",
        STATES = {
            SELECTING_HAND = "selecting_hand",
            SHOP = "shop",
            BLIND_SELECT = "blind_select"
        },
        GAME = {
            current_round = {
                hands_left = 3,
                discards_left = 2
            },
            dollars = 10,
            round_resets = {
                ante = 1
            }
        },
        hand = {
            cards = {}
        },
        jokers = {
            cards = {}
        },
        consumeables = {
            cards = {}
        },
        shop_jokers = {
            cards = {}
        },
        FUNCS = {}
    }
end

-- Test StateExtractor orchestrator
TestStateExtractorOrchestrator = {}

function TestStateExtractorOrchestrator:setUp()
    self.extractor = StateExtractor.new()
    -- Store original G
    self.original_G = G
end

function TestStateExtractorOrchestrator:tearDown()
    -- Restore original G
    G = self.original_G
end

-- Test extractor creation and initialization
function TestStateExtractorOrchestrator:test_extractor_creation()
    luaunit.assertNotNil(self.extractor)
    luaunit.assertEquals(self.extractor.component_name, "STATE_EXTRACTOR")
    luaunit.assertNotNil(self.extractor.extractors)
    luaunit.assertTrue(type(self.extractor.extractors) == "table")
end

-- Test that all expected extractors are registered
function TestStateExtractorOrchestrator:test_all_extractors_registered()
    local expected_extractors = {
        "session_extractor",
        "phase_extractor", 
        "game_state_extractor",
        "round_state_extractor",
        "hand_card_extractor",
        "joker_extractor",
        "consumable_extractor",
        "deck_card_extractor",
        "blind_extractor",
        "shop_extractor",
        "action_extractor",
        "joker_reorder_extractor"
    }
    
    luaunit.assertEquals(#self.extractor.extractors, #expected_extractors)
    
    -- Check that all expected extractors are present
    local found_extractors = {}
    for _, extractor in ipairs(self.extractor.extractors) do
        found_extractors[extractor:get_name()] = true
    end
    
    for _, expected_name in ipairs(expected_extractors) do
        luaunit.assertTrue(found_extractors[expected_name], "Missing extractor: " .. expected_name)
    end
end

-- Test register_extractor with valid extractor
function TestStateExtractorOrchestrator:test_register_extractor_valid()
    local test_extractor = create_mock_extractor("test_extractor", {test_data = "value"})
    local initial_count = #self.extractor.extractors
    
    self.extractor:register_extractor(test_extractor)
    
    luaunit.assertEquals(#self.extractor.extractors, initial_count + 1)
    luaunit.assertEquals(self.extractor.extractors[#self.extractor.extractors]:get_name(), "test_extractor")
end

-- Test register_extractor with invalid extractor (missing methods)
function TestStateExtractorOrchestrator:test_register_extractor_invalid()
    local invalid_extractor = {}  -- Missing required methods
    
    luaunit.assertErrorMsgContains("Extractor must implement IExtractor interface", function()
        self.extractor:register_extractor(invalid_extractor)
    end)
end

-- Test extract_current_state with valid game state
function TestStateExtractorOrchestrator:test_extract_current_state_valid()
    G = create_mock_g_complete()
    
    local result = self.extractor:extract_current_state()
    
    luaunit.assertNotNil(result)
    luaunit.assertEquals(type(result), "table")
    
    -- Should contain data from various extractors
    luaunit.assertNotNil(result.session_id)  -- From SessionExtractor
    luaunit.assertNotNil(result.phase)       -- From PhaseExtractor
    luaunit.assertNotNil(result.ante)        -- From GameStateExtractor
    luaunit.assertNotNil(result.hands_remaining)  -- From RoundStateExtractor
end

-- Test extract_current_state with invalid game state
function TestStateExtractorOrchestrator:test_extract_current_state_invalid()
    G = nil
    
    local result = self.extractor:extract_current_state()
    
    luaunit.assertNotNil(result)
    luaunit.assertEquals(type(result), "table")
    -- Should still return a table even with invalid G
end

-- Test extract_current_state with extractor errors
function TestStateExtractorOrchestrator:test_extract_current_state_with_errors()
    G = create_mock_g_complete()
    
    -- Add a failing extractor
    local failing_extractor = create_failing_extractor("failing_extractor", "Test failure")
    self.extractor:register_extractor(failing_extractor)
    
    local result = self.extractor:extract_current_state()
    
    luaunit.assertNotNil(result)
    luaunit.assertNotNil(result.extraction_errors)
    luaunit.assertTrue(#result.extraction_errors > 0)
    
    -- Check that error message contains the failing extractor name
    local found_error = false
    for _, error_msg in ipairs(result.extraction_errors) do
        if string.find(error_msg, "failing_extractor") then
            found_error = true
            break
        end
    end
    luaunit.assertTrue(found_error)
end

-- Test merge_extraction_results
function TestStateExtractorOrchestrator:test_merge_extraction_results()
    local state = {existing_key = "existing_value"}
    local extractor_result = {
        new_key = "new_value",
        another_key = 42
    }
    
    self.extractor:merge_extraction_results(state, extractor_result)
    
    luaunit.assertEquals(state.existing_key, "existing_value")
    luaunit.assertEquals(state.new_key, "new_value")
    luaunit.assertEquals(state.another_key, 42)
end

-- Test merge_extraction_results with non-table result
function TestStateExtractorOrchestrator:test_merge_extraction_results_non_table()
    local state = {existing_key = "existing_value"}
    
    -- Should not crash with non-table results
    self.extractor:merge_extraction_results(state, "not_a_table")
    self.extractor:merge_extraction_results(state, 123)
    self.extractor:merge_extraction_results(state, nil)
    
    luaunit.assertEquals(state.existing_key, "existing_value")
end

-- Test merge_extraction_results with overlapping keys
function TestStateExtractorOrchestrator:test_merge_extraction_results_overlapping()
    local state = {common_key = "original_value"}
    local extractor_result = {common_key = "new_value"}
    
    self.extractor:merge_extraction_results(state, extractor_result)
    
    luaunit.assertEquals(state.common_key, "new_value")  -- Should overwrite
end

-- Test get_session_id for backward compatibility
function TestStateExtractorOrchestrator:test_get_session_id()
    local session_id = self.extractor:get_session_id()
    
    luaunit.assertNotNil(session_id)
    luaunit.assertEquals(type(session_id), "string")
    luaunit.assertTrue(string.find(session_id, "session_") == 1)
    
    -- Should return same ID on subsequent calls
    local session_id2 = self.extractor:get_session_id()
    luaunit.assertEquals(session_id, session_id2)
end

-- Test validate_g_object with valid G
function TestStateExtractorOrchestrator:test_validate_g_object_valid()
    G = create_mock_g_complete()
    
    local result = self.extractor:validate_g_object()
    
    luaunit.assertTrue(result)
end

-- Test validate_g_object with nil G
function TestStateExtractorOrchestrator:test_validate_g_object_nil()
    G = nil
    
    local result = self.extractor:validate_g_object()
    
    luaunit.assertFalse(result)
end

-- Test validate_g_object with missing properties
function TestStateExtractorOrchestrator:test_validate_g_object_missing_properties()
    G = {
        STATE = "test"
        -- Missing other critical properties
    }
    
    local result = self.extractor:validate_g_object()
    
    luaunit.assertFalse(result)
end

-- Test validate_card_areas
function TestStateExtractorOrchestrator:test_validate_card_areas()
    G = create_mock_g_complete()
    G.hand.cards = {{ability = {name = "test"}}}
    
    -- Should not crash
    self.extractor:validate_card_areas()
end

-- Test validate_card_structure
function TestStateExtractorOrchestrator:test_validate_card_structure()
    local card = {ability = {name = "test_card"}}
    
    -- Should not crash
    self.extractor:validate_card_structure(card, "test_card")
    self.extractor:validate_card_structure(nil, "nil_card")
end

-- Test validate_states
function TestStateExtractorOrchestrator:test_validate_states()
    G = create_mock_g_complete()
    
    -- Should not crash
    self.extractor:validate_states()
end

-- Test error handling with all extractors failing
function TestStateExtractorOrchestrator:test_all_extractors_failing()
    -- Create a fresh extractor with only failing extractors
    local test_extractor = StateExtractor.new()
    test_extractor.extractors = {}  -- Clear existing extractors
    
    -- Add only failing extractors
    test_extractor:register_extractor(create_failing_extractor("fail1", "Error 1"))
    test_extractor:register_extractor(create_failing_extractor("fail2", "Error 2"))
    
    G = create_mock_g_complete()
    
    local result = test_extractor:extract_current_state()
    
    luaunit.assertNotNil(result)
    luaunit.assertNotNil(result.extraction_errors)
    luaunit.assertEquals(#result.extraction_errors, 2)
end

-- Test mixed success and failure scenarios
function TestStateExtractorOrchestrator:test_mixed_success_failure()
    local test_extractor = StateExtractor.new()
    test_extractor.extractors = {}  -- Clear existing extractors
    
    -- Add mix of successful and failing extractors
    test_extractor:register_extractor(create_mock_extractor("success1", {data1 = "value1"}))
    test_extractor:register_extractor(create_failing_extractor("fail1", "Error 1"))
    test_extractor:register_extractor(create_mock_extractor("success2", {data2 = "value2"}))
    
    G = create_mock_g_complete()
    
    local result = test_extractor:extract_current_state()
    
    luaunit.assertNotNil(result)
    luaunit.assertEquals(result.data1, "value1")
    luaunit.assertEquals(result.data2, "value2")
    luaunit.assertNotNil(result.extraction_errors)
    luaunit.assertEquals(#result.extraction_errors, 1)
end

-- Test extraction order preservation
function TestStateExtractorOrchestrator:test_extraction_order()
    local test_extractor = StateExtractor.new()
    test_extractor.extractors = {}  -- Clear existing extractors
    
    -- Add extractors that set the same key to verify order
    test_extractor:register_extractor(create_mock_extractor("first", {order_test = "first"}))
    test_extractor:register_extractor(create_mock_extractor("second", {order_test = "second"}))
    test_extractor:register_extractor(create_mock_extractor("third", {order_test = "third"}))
    
    G = create_mock_g_complete()
    
    local result = test_extractor:extract_current_state()
    
    -- Last extractor should win
    luaunit.assertEquals(result.order_test, "third")
end

-- Test session_id initialization
function TestStateExtractorOrchestrator:test_session_id_initialization()
    luaunit.assertNil(self.extractor.session_id)  -- Should be nil initially
    
    local session_id = self.extractor:get_session_id()
    luaunit.assertNotNil(self.extractor.session_id)  -- Should be set after first call
    luaunit.assertEquals(session_id, self.extractor.session_id)
end

-- Test backward compatibility methods don't interfere with new architecture
function TestStateExtractorOrchestrator:test_backward_compatibility_isolation()
    G = create_mock_g_complete()
    
    -- Get session ID through backward compatibility method
    local session_id = self.extractor:get_session_id()
    
    -- Extract current state through new architecture
    local result = self.extractor:extract_current_state()
    
    -- Both should work independently
    luaunit.assertNotNil(session_id)
    luaunit.assertNotNil(result)
    luaunit.assertNotNil(result.session_id)  -- Should have session from SessionExtractor
end

-- Test performance with many extractors
function TestStateExtractorOrchestrator:test_performance_many_extractors()
    local test_extractor = StateExtractor.new()
    test_extractor.extractors = {}  -- Clear existing extractors
    
    -- Add many extractors
    for i = 1, 50 do
        test_extractor:register_extractor(create_mock_extractor("extractor_" .. i, {["data_" .. i] = i}))
    end
    
    G = create_mock_g_complete()
    
    local start_time = os.clock()
    local result = test_extractor:extract_current_state()
    local end_time = os.clock()
    
    luaunit.assertNotNil(result)
    
    -- Should complete reasonably quickly
    local duration = end_time - start_time
    luaunit.assertTrue(duration < 5.0)  -- Should complete in less than 5 seconds
end

-- Test that validation methods are called during initialization
function TestStateExtractorOrchestrator:test_validation_called_during_init()
    G = create_mock_g_complete()
    
    -- Creating a new extractor should trigger validation
    local new_extractor = StateExtractor.new()
    
    luaunit.assertNotNil(new_extractor)
    -- Validation should not cause errors with valid G
end

-- Test extractor interface validation
function TestStateExtractorOrchestrator:test_extractor_interface_validation()
    local valid_extractor = create_mock_extractor("valid", {test = "data"})
    
    -- Should validate successfully
    luaunit.assertTrue(IExtractor.validate_implementation(valid_extractor))
    
    local invalid_extractor = {
        get_name = function() return "invalid" end
        -- Missing extract method
    }
    
    luaunit.assertFalse(IExtractor.validate_implementation(invalid_extractor))
end

-- Test large state extraction with all extractors
function TestStateExtractorOrchestrator:test_large_state_extraction()
    G = {
        STATE = "selecting_hand",
        STATES = {
            SELECTING_HAND = "selecting_hand",
            SHOP = "shop",
            BLIND_SELECT = "blind_select"
        },
        GAME = {
            current_round = {
                hands_left = 4,
                discards_left = 3,
                blind = {
                    name = "Small Blind",
                    ante = 2
                }
            },
            dollars = 25,
            round_resets = {
                ante = 2
            }
        },
        hand = {
            cards = {
                {ability = {name = "test1"}},
                {ability = {name = "test2"}}
            }
        },
        jokers = {
            cards = {
                {ability = {name = "Joker1", set = "Joker"}},
                {ability = {name = "Joker2", set = "Joker"}}
            }
        },
        consumeables = {
            cards = {
                {ability = {name = "Tarot1", set = "Tarot"}}
            }
        },
        deck = {
            cards = {
                {ability = {name = "Deck1"}},
                {ability = {name = "Deck2"}}
            }
        },
        shop_jokers = {
            cards = {
                {ability = {name = "Shop1", set = "Joker"}, cost = 5}
            }
        },
        FUNCS = {}
    }
    
    local result = self.extractor:extract_current_state()
    
    luaunit.assertNotNil(result)
    luaunit.assertEquals(type(result), "table")
    
    -- Should contain comprehensive state data
    luaunit.assertNotNil(result.session_id)
    luaunit.assertNotNil(result.phase)
    luaunit.assertNotNil(result.ante)
    luaunit.assertNotNil(result.money)
    luaunit.assertNotNil(result.hands_remaining)
    luaunit.assertNotNil(result.discards_remaining)
    luaunit.assertNotNil(result.hand_cards)
    luaunit.assertNotNil(result.jokers)
    luaunit.assertNotNil(result.consumables)
    luaunit.assertNotNil(result.deck_cards)
    luaunit.assertNotNil(result.current_blind)
    luaunit.assertNotNil(result.shop_contents)
    luaunit.assertNotNil(result.available_actions)
    luaunit.assertNotNil(result.post_hand_joker_reorder_available)
end

return TestStateExtractorOrchestrator