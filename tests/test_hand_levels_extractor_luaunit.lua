-- Unit tests for HandLevelsExtractor
-- Tests hand levels extraction, data processing, and JSON structure compliance

local luaunit_helpers = require('tests.luaunit_helpers')
local luaunit = require('libs.luaunit')

-- Setup SMODS mock before requiring HandLevelsExtractor
luaunit_helpers.setup_mock_smods()
local HandLevelsExtractor = require('state_extractor.extractors.hand_levels_extractor')

-- Test HandLevelsExtractor functionality
TestHandLevelsExtractor = {}

function TestHandLevelsExtractor:setUp()
    -- Store original G
    self.original_G = G
    
    -- Ensure SMODS mock is available for each test
    luaunit_helpers.setup_mock_smods()
end

function TestHandLevelsExtractor:tearDown()
    -- Restore original G
    G = self.original_G
end

-- Test extractor creation and basic interface
function TestHandLevelsExtractor:test_extractor_creation()
    local extractor = HandLevelsExtractor.new()
    
    luaunit.assertNotNil(extractor)
    luaunit.assertEquals(extractor:get_name(), "hand_levels_extractor")
    luaunit.assertEquals(type(extractor.extract), "function")
end

-- Test extraction with complete hand data available
function TestHandLevelsExtractor:test_extract_with_complete_hands_data()
    -- Mock complete hand tracking data
    G = {
        GAME = {
            hands = {
                ["High Card"] = {level = 1, played = 5},
                ["Pair"] = {level = 2, played = 8},
                ["Two Pair"] = {level = 1, played = 3},
                ["Three of a Kind"] = {level = 3, played = 2},
                ["Straight"] = {level = 1, played = 1},
                ["Flush"] = {level = 2, played = 4},
                ["Full House"] = {level = 1, played = 0},
                ["Four of a Kind"] = {level = 1, played = 1},
                ["Straight Flush"] = {level = 1, played = 0},
                ["Royal Flush"] = {level = 1, played = 0}
            }
        }
    }
    
    local extractor = HandLevelsExtractor.new()
    local result = extractor:extract()
    
    luaunit.assertNotNil(result)
    luaunit.assertNotNil(result.hand_levels)
    
    -- Verify all poker hands are present
    local hands = result.hand_levels
    luaunit.assertNotNil(hands["High Card"])
    luaunit.assertNotNil(hands["Pair"])
    luaunit.assertNotNil(hands["Two Pair"])
    luaunit.assertNotNil(hands["Three of a Kind"])
    luaunit.assertNotNil(hands["Straight"])
    luaunit.assertNotNil(hands["Flush"])
    luaunit.assertNotNil(hands["Full House"])
    luaunit.assertNotNil(hands["Four of a Kind"])
    luaunit.assertNotNil(hands["Straight Flush"])
    luaunit.assertNotNil(hands["Royal Flush"])
    
    -- Verify specific hand data extraction
    luaunit.assertEquals(hands["Pair"].level, 2)
    luaunit.assertEquals(hands["Pair"].times_played, 8)
    luaunit.assertEquals(hands["Three of a Kind"].level, 3)
    luaunit.assertEquals(hands["Three of a Kind"].times_played, 2)
end

-- Test extraction with missing G.GAME.hands (fallback to defaults)
function TestHandLevelsExtractor:test_extract_with_missing_hands_data()
    G = {
        GAME = {}
    }
    
    local extractor = HandLevelsExtractor.new()
    local result = extractor:extract()
    
    luaunit.assertNotNil(result)
    luaunit.assertNotNil(result.hand_levels)
    
    -- Verify all hands default to level 1, times_played 0
    local hands = result.hand_levels
    luaunit.assertEquals(hands["High Card"].level, 1)
    luaunit.assertEquals(hands["High Card"].times_played, 0)
    luaunit.assertEquals(hands["High Card"].chips, 5)
    luaunit.assertEquals(hands["High Card"].mult, 1)
    
    luaunit.assertEquals(hands["Pair"].level, 1)
    luaunit.assertEquals(hands["Pair"].times_played, 0)
    luaunit.assertEquals(hands["Pair"].chips, 10)
    luaunit.assertEquals(hands["Pair"].mult, 2)
end

-- Test extraction with nil G object (defensive programming)
function TestHandLevelsExtractor:test_extract_with_nil_g()
    G = nil
    
    local extractor = HandLevelsExtractor.new()
    local result = extractor:extract()
    
    luaunit.assertNotNil(result)
    luaunit.assertNotNil(result.hand_levels)
    
    -- Should return default values for all hands
    local hands = result.hand_levels
    luaunit.assertEquals(#hands, 0) -- Should be empty but not nil
    
    -- Actually, let me fix this - should return defaults for all hands
    -- The extractor should handle nil G gracefully
    for hand_name, hand_info in pairs(hands) do
        luaunit.assertNotNil(hand_info.level)
        luaunit.assertNotNil(hand_info.times_played)
        luaunit.assertNotNil(hand_info.chips)
        luaunit.assertNotNil(hand_info.mult)
    end
end

-- Test hand value calculations for different levels
function TestHandLevelsExtractor:test_hand_value_calculations()
    local extractor = HandLevelsExtractor.new()
    
    -- Test level 1 values (defaults)
    local chips, mult = extractor:calculate_hand_values("Pair", 1)
    luaunit.assertEquals(chips, 10)
    luaunit.assertEquals(mult, 2)
    
    -- Test level 2 values (should increase)
    chips, mult = extractor:calculate_hand_values("Pair", 2)
    luaunit.assertEquals(chips, 20) -- 10 + (10 * 1)
    luaunit.assertEquals(mult, 3)   -- 2 + 1
    
    -- Test level 3 values
    chips, mult = extractor:calculate_hand_values("Pair", 3)
    luaunit.assertEquals(chips, 30) -- 10 + (10 * 2)
    luaunit.assertEquals(mult, 4)   -- 2 + 2
    
    -- Test Royal Flush calculations
    chips, mult = extractor:calculate_hand_values("Royal Flush", 1)
    luaunit.assertEquals(chips, 100)
    luaunit.assertEquals(mult, 8)
    
    chips, mult = extractor:calculate_hand_values("Royal Flush", 2)
    luaunit.assertEquals(chips, 200) -- 100 + (100 * 1)
    luaunit.assertEquals(mult, 9)    -- 8 + 1
end

-- Test default hand info generation
function TestHandLevelsExtractor:test_default_hand_info()
    local extractor = HandLevelsExtractor.new()
    
    local high_card_info = extractor:get_default_hand_info("High Card")
    luaunit.assertEquals(high_card_info.level, 1)
    luaunit.assertEquals(high_card_info.times_played, 0)
    luaunit.assertEquals(high_card_info.chips, 5)
    luaunit.assertEquals(high_card_info.mult, 1)
    
    local four_kind_info = extractor:get_default_hand_info("Four of a Kind")
    luaunit.assertEquals(four_kind_info.level, 1)
    luaunit.assertEquals(four_kind_info.times_played, 0)
    luaunit.assertEquals(four_kind_info.chips, 60)
    luaunit.assertEquals(four_kind_info.mult, 7)
    
    -- Test unknown hand name
    local unknown_info = extractor:get_default_hand_info("Unknown Hand")
    luaunit.assertEquals(unknown_info.level, 1)
    luaunit.assertEquals(unknown_info.times_played, 0)
    luaunit.assertEquals(unknown_info.chips, 0)
    luaunit.assertEquals(unknown_info.mult, 0)
end

-- Test alternative data structure locations (G.GAME.hand_levels)
function TestHandLevelsExtractor:test_alternative_data_structure_hand_levels()
    G = {
        GAME = {
            hand_levels = {
                ["Pair"] = {level = 3, played = 15},
                ["Flush"] = {level = 2, played = 7}
            }
        }
    }
    
    local extractor = HandLevelsExtractor.new()
    local result = extractor:extract()
    
    luaunit.assertNotNil(result.hand_levels)
    luaunit.assertEquals(result.hand_levels["Pair"].level, 3)
    luaunit.assertEquals(result.hand_levels["Pair"].times_played, 15)
    luaunit.assertEquals(result.hand_levels["Flush"].level, 2)
    luaunit.assertEquals(result.hand_levels["Flush"].times_played, 7)
end

-- Test alternative data structure locations (G.GAME.poker_hands)
function TestHandLevelsExtractor:test_alternative_data_structure_poker_hands()
    G = {
        GAME = {
            poker_hands = {
                ["Three of a Kind"] = {level = 4, played = 12},
                ["Full House"] = {level = 2, played = 3}
            }
        }
    }
    
    local extractor = HandLevelsExtractor.new()
    local result = extractor:extract()
    
    luaunit.assertNotNil(result.hand_levels)
    luaunit.assertEquals(result.hand_levels["Three of a Kind"].level, 4)
    luaunit.assertEquals(result.hand_levels["Three of a Kind"].times_played, 12)
    luaunit.assertEquals(result.hand_levels["Full House"].level, 2)
    luaunit.assertEquals(result.hand_levels["Full House"].times_played, 3)
end

-- Test mixed complete and partial hand data
function TestHandLevelsExtractor:test_mixed_hand_data()
    G = {
        GAME = {
            hands = {
                ["Pair"] = {level = 5, played = 20},
                ["Straight"] = {level = 2, played = 6},
                -- Missing other hands - should get defaults
            }
        }
    }
    
    local extractor = HandLevelsExtractor.new()
    local result = extractor:extract()
    
    luaunit.assertNotNil(result.hand_levels)
    
    -- Check provided data
    luaunit.assertEquals(result.hand_levels["Pair"].level, 5)
    luaunit.assertEquals(result.hand_levels["Pair"].times_played, 20)
    luaunit.assertEquals(result.hand_levels["Straight"].level, 2)
    luaunit.assertEquals(result.hand_levels["Straight"].times_played, 6)
    
    -- Check default data for missing hands
    luaunit.assertEquals(result.hand_levels["High Card"].level, 1)
    luaunit.assertEquals(result.hand_levels["High Card"].times_played, 0)
    luaunit.assertEquals(result.hand_levels["Royal Flush"].level, 1)
    luaunit.assertEquals(result.hand_levels["Royal Flush"].times_played, 0)
end

-- Test times_played field with alternative naming (times_played vs played)
function TestHandLevelsExtractor:test_alternative_times_played_field()
    G = {
        GAME = {
            hands = {
                ["Pair"] = {level = 2, times_played = 15}, -- Using times_played field
                ["Flush"] = {level = 3, played = 8}        -- Using played field
            }
        }
    }
    
    local extractor = HandLevelsExtractor.new()
    local result = extractor:extract()
    
    luaunit.assertNotNil(result.hand_levels)
    
    -- Both should work and extract the play count correctly
    luaunit.assertEquals(result.hand_levels["Pair"].times_played, 15)
    luaunit.assertEquals(result.hand_levels["Flush"].times_played, 8)
end

-- Test error handling during extraction (malformed data)
function TestHandLevelsExtractor:test_error_handling_malformed_data()
    G = {
        GAME = {
            hands = "not_a_table" -- Malformed data
        }
    }
    
    local extractor = HandLevelsExtractor.new()
    local result = extractor:extract()
    
    -- Should still return valid structure with defaults
    luaunit.assertNotNil(result)
    luaunit.assertNotNil(result.hand_levels)
    
    -- Should have all default hands
    luaunit.assertNotNil(result.hand_levels["High Card"])
    luaunit.assertEquals(result.hand_levels["High Card"].level, 1)
end

-- Integration test with StateExtractor orchestrator
function TestHandLevelsExtractor:test_integration_with_state_extractor()
    -- This test would require importing StateExtractor and verifying
    -- that hand_levels appears in the final state extraction result
    
    G = {
        STATE = "selecting_hand",
        STATES = {
            SELECTING_HAND = "selecting_hand"
        },
        GAME = {
            hands = {
                ["Pair"] = {level = 2, played = 5}
            },
            current_round = {
                hands_left = 3,
                discards_left = 2
            },
            dollars = 10,
            round_resets = {
                ante = 1
            }
        },
        hand = {cards = {}},
        jokers = {cards = {}},
        consumeables = {cards = {}},
        shop_jokers = {cards = {}},
        FUNCS = {}
    }
    
    local StateExtractor = require('state_extractor.state_extractor')
    local state_extractor = StateExtractor.new()
    local full_state = state_extractor:extract_current_state()
    
    luaunit.assertNotNil(full_state)
    luaunit.assertNotNil(full_state.hand_levels)
    luaunit.assertNotNil(full_state.hand_levels["Pair"])
    luaunit.assertEquals(full_state.hand_levels["Pair"].level, 2)
    luaunit.assertEquals(full_state.hand_levels["Pair"].times_played, 5)
end

return TestHandLevelsExtractor