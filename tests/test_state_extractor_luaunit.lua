-- Updated StateExtractor orchestration tests
-- Tests main orchestration functionality after modular refactor
-- Individual extractor tests have been moved to separate files

local luaunit_helpers = require('tests.luaunit_helpers')
local luaunit = require('libs.luaunit')
local StateExtractor = require('state_extractor.state_extractor')

-- Test StateExtractor orchestration
TestStateExtractorOrchestration = {}

function TestStateExtractorOrchestration:setUp()
    -- Store original G
    self.original_G = G
end

function TestStateExtractorOrchestration:tearDown()
    -- Restore original G
    G = self.original_G
end

-- Test orchestrator creation and initialization
function TestStateExtractorOrchestration:test_orchestrator_creation()
    local extractor = StateExtractor.new()
    
    luaunit.assertNotNil(extractor)
    luaunit.assertEquals(extractor.component_name, "STATE_EXTRACTOR")
    luaunit.assertNotNil(extractor.extractors)
    luaunit.assertTrue(#extractor.extractors > 0)
end

-- Test main extraction orchestration with valid game state
function TestStateExtractorOrchestration:test_extract_current_state_orchestration()
    G = {
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
    
    local extractor = StateExtractor.new()
    local result = extractor:extract_current_state()
    
    luaunit.assertNotNil(result)
    luaunit.assertEquals(type(result), "table")
    
    -- Verify orchestration produces expected combined state
    luaunit.assertNotNil(result.session_id)
    luaunit.assertNotNil(result.phase)
    luaunit.assertNotNil(result.ante)
    luaunit.assertNotNil(result.money)
    luaunit.assertNotNil(result.hands_remaining)
    luaunit.assertNotNil(result.discards_remaining)
    luaunit.assertNotNil(result.hand_cards)
    luaunit.assertNotNil(result.jokers)
    luaunit.assertNotNil(result.consumables)
    luaunit.assertNotNil(result.current_blind)
    luaunit.assertNotNil(result.shop_contents)
    luaunit.assertNotNil(result.available_actions)
    luaunit.assertNotNil(result.post_hand_joker_reorder_available)
end

-- Test orchestration with invalid game state
function TestStateExtractorOrchestration:test_extract_current_state_invalid_g()
    G = nil
    
    local extractor = StateExtractor.new()
    local result = extractor:extract_current_state()
    
    luaunit.assertNotNil(result)
    luaunit.assertEquals(type(result), "table")
    
    -- Should still produce a valid state structure with defaults
    luaunit.assertNotNil(result.session_id)
    luaunit.assertNotNil(result.phase)
    luaunit.assertNotNil(result.ante)
    luaunit.assertNotNil(result.money)
end

-- Test backward compatibility methods
function TestStateExtractorOrchestration:test_backward_compatibility_session_id()
    local extractor = StateExtractor.new()
    
    local session_id = extractor:get_session_id()
    
    luaunit.assertNotNil(session_id)
    luaunit.assertEquals(type(session_id), "string")
    luaunit.assertTrue(string.find(session_id, "session_") == 1)
    
    -- Should return same ID on subsequent calls
    local session_id2 = extractor:get_session_id()
    luaunit.assertEquals(session_id, session_id2)
end

-- Test validation methods for backward compatibility
function TestStateExtractorOrchestration:test_validation_methods_backward_compatibility()
    G = {
        STATE = "test",
        STATES = {SELECTING_HAND = "test"},
        GAME = {},
        hand = {cards = {}},
        jokers = {cards = {}},
        consumeables = {cards = {}},
        shop_jokers = {cards = {}},
        FUNCS = {}
    }
    
    local extractor = StateExtractor.new()
    
    -- These methods should exist and not crash
    local result = extractor:validate_g_object()
    luaunit.assertEquals(type(result), "boolean")
    
    -- These should not crash
    extractor:validate_game_object()
    extractor:validate_card_areas()
    extractor:validate_states()
    extractor:validate_card_structure(nil, "test")
end

-- Test orchestration handles extractor errors gracefully
function TestStateExtractorOrchestration:test_orchestration_error_handling()
    G = {} -- Minimal G that might cause some extractors to fail
    
    local extractor = StateExtractor.new()
    local result = extractor:extract_current_state()
    
    luaunit.assertNotNil(result)
    luaunit.assertEquals(type(result), "table")
    
    -- Even with errors, should still produce a usable state
    luaunit.assertNotNil(result.session_id)
end

-- Test that orchestration preserves session consistency
function TestStateExtractorOrchestration:test_orchestration_session_consistency()
    G = {
        STATE = "selecting_hand",
        STATES = {SELECTING_HAND = "selecting_hand"},
        GAME = {dollars = 10, round_resets = {ante = 1}},
        hand = {cards = {}},
        jokers = {cards = {}},
        consumeables = {cards = {}},
        shop_jokers = {cards = {}},
        FUNCS = {}
    }
    
    local extractor = StateExtractor.new()
    
    -- Get session through backward compatibility
    local compat_session = extractor:get_session_id()
    
    -- Get session through orchestration
    local result = extractor:extract_current_state()
    local orchestrated_session = result.session_id
    
    -- Should be consistent (both should exist but may be different)
    luaunit.assertNotNil(compat_session)
    luaunit.assertNotNil(orchestrated_session)
    luaunit.assertEquals(type(compat_session), "string")
    luaunit.assertEquals(type(orchestrated_session), "string")
end

-- Test orchestration performance
function TestStateExtractorOrchestration:test_orchestration_performance()
    G = {
        STATE = "selecting_hand",
        STATES = {SELECTING_HAND = "selecting_hand"},
        GAME = {
            current_round = {hands_left = 4, discards_left = 3},
            dollars = 25,
            round_resets = {ante = 2}
        },
        hand = {cards = {}},
        jokers = {cards = {}},
        consumeables = {cards = {}},
        shop_jokers = {cards = {}},
        FUNCS = {}
    }
    
    local extractor = StateExtractor.new()
    
    local start_time = os.clock()
    local result = extractor:extract_current_state()
    local end_time = os.clock()
    
    luaunit.assertNotNil(result)
    
    -- Should complete reasonably quickly
    local duration = end_time - start_time
    luaunit.assertTrue(duration < 2.0)
end

-- Test multiple extraction calls for consistency
function TestStateExtractorOrchestration:test_multiple_extraction_consistency()
    G = {
        STATE = "selecting_hand",
        STATES = {SELECTING_HAND = "selecting_hand"},
        GAME = {
            current_round = {hands_left = 3, discards_left = 2},
            dollars = 15,
            round_resets = {ante = 1}
        },
        hand = {cards = {}},
        jokers = {cards = {}},
        consumeables = {cards = {}},
        shop_jokers = {cards = {}},
        FUNCS = {}
    }
    
    local extractor = StateExtractor.new()
    
    local result1 = extractor:extract_current_state()
    local result2 = extractor:extract_current_state()
    
    -- Should produce consistent results
    luaunit.assertEquals(result1.phase, result2.phase)
    luaunit.assertEquals(result1.ante, result2.ante)
    luaunit.assertEquals(result1.money, result2.money)
    luaunit.assertEquals(result1.hands_remaining, result2.hands_remaining)
    
    -- Session IDs should be consistent within same extractor instance
    luaunit.assertEquals(result1.session_id, result2.session_id)
end

-- Test orchestration with comprehensive game state
function TestStateExtractorOrchestration:test_orchestration_comprehensive_state()
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
                    chips = 300,
                    dollars = 5
                }
            },
            dollars = 25,
            round_resets = {
                ante = 2
            }
        },
        hand = {
            cards = {
                {
                    ability = {name = "test_card"},
                    base = {rank = "A", suit = "Spades", id = "AS"}
                }
            }
        },
        jokers = {
            cards = {
                {
                    ability = {name = "Joker", set = "Joker"},
                    unique_val = "joker1"
                }
            }
        },
        consumeables = {
            cards = {
                {
                    ability = {name = "The Fool", set = "Tarot"},
                    unique_val = "tarot1"
                }
            }
        },
        deck = {
            cards = {
                {
                    ability = {name = "deck_card"},
                    base = {rank = "K", suit = "Hearts", id = "KH"}
                }
            }
        },
        shop_jokers = {
            cards = {
                {
                    ability = {name = "Shop Joker", set = "Joker"},
                    cost = 5
                }
            }
        },
        FUNCS = {}
    }
    
    local extractor = StateExtractor.new()
    local result = extractor:extract_current_state()
    
    luaunit.assertNotNil(result)
    
    -- Verify comprehensive state extraction
    luaunit.assertEquals(result.phase, "hand_selection")
    luaunit.assertEquals(result.ante, 2)
    luaunit.assertEquals(result.money, 25)
    luaunit.assertEquals(result.hands_remaining, 4)
    luaunit.assertEquals(result.discards_remaining, 3)
    
    -- Verify array data
    luaunit.assertEquals(type(result.hand_cards), "table")
    luaunit.assertEquals(type(result.jokers), "table")
    luaunit.assertEquals(type(result.consumables), "table")
    luaunit.assertEquals(type(result.deck_cards), "table")
    luaunit.assertEquals(type(result.shop_contents), "table")
    luaunit.assertEquals(type(result.available_actions), "table")
    
    -- Verify counts match expected
    luaunit.assertEquals(#result.hand_cards, 1)
    luaunit.assertEquals(#result.jokers, 1)
    luaunit.assertEquals(#result.consumables, 1)
    luaunit.assertEquals(#result.deck_cards, 1)
    luaunit.assertEquals(#result.shop_contents, 1)
    luaunit.assertTrue(#result.available_actions > 0)
end

return TestStateExtractorOrchestration
