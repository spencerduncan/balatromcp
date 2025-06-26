-- Test file for JokerReorderExtractor
-- Tests joker reorder availability detection functionality

local luaunit = require('luaunit')
local JokerReorderExtractor = require("state_extractor.extractors.joker_reorder_extractor")

-- Test helper functions
local function create_mock_g_with_jokers(joker_count)
    local jokers = {}
    for i = 1, joker_count do
        table.insert(jokers, {
            ability = {
                name = "Test Joker " .. i,
                set = "Joker"
            }
        })
    end
    
    return {
        jokers = {
            cards = jokers
        }
    }
end

local function create_mock_g_empty()
    return {
        jokers = {
            cards = {}
        }
    }
end

-- Test JokerReorderExtractor
TestJokerReorderExtractor = {}

function TestJokerReorderExtractor:setUp()
    self.extractor = JokerReorderExtractor.new()
    -- Store original G
    self.original_G = G
end

function TestJokerReorderExtractor:tearDown()
    -- Restore original G
    G = self.original_G
end

-- Test extractor creation and basic interface
function TestJokerReorderExtractor:test_extractor_creation()
    luaunit.assertNotNil(self.extractor)
    luaunit.assertEquals(self.extractor:get_name(), "joker_reorder_extractor")
end

-- Test extract method with valid game state
function TestJokerReorderExtractor:test_extract_with_valid_state()
    G = create_mock_g_with_jokers(2)
    
    local result = self.extractor:extract()
    
    luaunit.assertNotNil(result)
    luaunit.assertNotNil(result.post_hand_joker_reorder_available)
    luaunit.assertEquals(type(result.post_hand_joker_reorder_available), "boolean")
end

-- Test extract method with invalid game state
function TestJokerReorderExtractor:test_extract_with_invalid_state()
    G = nil
    
    local result = self.extractor:extract()
    
    luaunit.assertNotNil(result)
    luaunit.assertNotNil(result.post_hand_joker_reorder_available)
    luaunit.assertEquals(type(result.post_hand_joker_reorder_available), "boolean")
    luaunit.assertEquals(result.post_hand_joker_reorder_available, false)
end

-- Test extract method with empty jokers
function TestJokerReorderExtractor:test_extract_with_empty_jokers()
    G = create_mock_g_empty()
    
    local result = self.extractor:extract()
    
    luaunit.assertNotNil(result)
    luaunit.assertEquals(result.post_hand_joker_reorder_available, false)
end

-- Test extract method with multiple jokers
function TestJokerReorderExtractor:test_extract_with_multiple_jokers()
    G = create_mock_g_with_jokers(3)
    
    local result = self.extractor:extract()
    
    luaunit.assertNotNil(result)
    luaunit.assertEquals(result.post_hand_joker_reorder_available, false)  -- Currently placeholder returns false
end

-- Test is_joker_reorder_available method directly
function TestJokerReorderExtractor:test_is_joker_reorder_available_placeholder()
    G = create_mock_g_with_jokers(2)
    
    local result = self.extractor:is_joker_reorder_available()
    
    luaunit.assertEquals(result, false)  -- Currently a placeholder that always returns false
end

-- Test is_joker_reorder_available with no jokers
function TestJokerReorderExtractor:test_is_joker_reorder_available_no_jokers()
    G = create_mock_g_empty()
    
    local result = self.extractor:is_joker_reorder_available()
    
    luaunit.assertEquals(result, false)
end

-- Test is_joker_reorder_available with nil G
function TestJokerReorderExtractor:test_is_joker_reorder_available_nil_g()
    G = nil
    
    local result = self.extractor:is_joker_reorder_available()
    
    luaunit.assertEquals(result, false)
end

-- Test error handling in extract method
function TestJokerReorderExtractor:test_extract_handles_errors()
    -- Force an error by making is_joker_reorder_available throw
    local original_method = self.extractor.is_joker_reorder_available
    self.extractor.is_joker_reorder_available = function()
        error("Test error")
    end
    
    G = create_mock_g_with_jokers(1)
    
    local result = self.extractor:extract()
    
    luaunit.assertNotNil(result)
    luaunit.assertEquals(result.post_hand_joker_reorder_available, false)  -- Should default to false on error
    
    -- Restore original method
    self.extractor.is_joker_reorder_available = original_method
end

-- Test extract method returns correct structure
function TestJokerReorderExtractor:test_extract_returns_correct_structure()
    G = create_mock_g_with_jokers(1)
    
    local result = self.extractor:extract()
    
    luaunit.assertNotNil(result)
    luaunit.assertEquals(type(result), "table")
    
    -- Check that only expected key is present
    local key_count = 0
    for key, _ in pairs(result) do
        key_count = key_count + 1
        luaunit.assertEquals(key, "post_hand_joker_reorder_available")
    end
    luaunit.assertEquals(key_count, 1)
end

-- Test with various game states that might affect joker reordering in the future
function TestJokerReorderExtractor:test_with_different_game_phases()
    local test_states = {
        {
            STATE = "selecting_hand",
            STATES = { SELECTING_HAND = "selecting_hand" },
            jokers = { cards = { { ability = { name = "Test", set = "Joker" } } } }
        },
        {
            STATE = "shop",
            STATES = { SHOP = "shop" },
            jokers = { cards = { { ability = { name = "Test", set = "Joker" } } } }
        },
        {
            STATE = "blind_select",
            STATES = { BLIND_SELECT = "blind_select" },
            jokers = { cards = { { ability = { name = "Test", set = "Joker" } } } }
        }
    }
    
    for _, state in ipairs(test_states) do
        G = state
        
        local result = self.extractor:extract()
        
        -- Currently all should return false due to placeholder implementation
        luaunit.assertEquals(result.post_hand_joker_reorder_available, false)
    end
end

-- Test with invalid joker structures
function TestJokerReorderExtractor:test_with_invalid_joker_structures()
    G = {
        jokers = "not_a_table"  -- Invalid structure
    }
    
    local result = self.extractor:extract()
    
    luaunit.assertEquals(result.post_hand_joker_reorder_available, false)
end

-- Test with missing jokers collection
function TestJokerReorderExtractor:test_with_missing_jokers_collection()
    G = {}  -- No jokers collection
    
    local result = self.extractor:extract()
    
    luaunit.assertEquals(result.post_hand_joker_reorder_available, false)
end

-- Test with jokers but no cards array
function TestJokerReorderExtractor:test_with_jokers_no_cards_array()
    G = {
        jokers = {}  -- Missing cards array
    }
    
    local result = self.extractor:extract()
    
    luaunit.assertEquals(result.post_hand_joker_reorder_available, false)
end

-- Test consistency across multiple calls
function TestJokerReorderExtractor:test_consistency_across_calls()
    G = create_mock_g_with_jokers(2)
    
    local result1 = self.extractor:extract()
    local result2 = self.extractor:extract()
    local result3 = self.extractor:extract()
    
    luaunit.assertEquals(result1.post_hand_joker_reorder_available, result2.post_hand_joker_reorder_available)
    luaunit.assertEquals(result2.post_hand_joker_reorder_available, result3.post_hand_joker_reorder_available)
end

-- Test that method doesn't modify global state
function TestJokerReorderExtractor:test_does_not_modify_global_state()
    local original_g = create_mock_g_with_jokers(2)
    G = original_g
    
    -- Make a deep copy for comparison
    local original_joker_count = #G.jokers.cards
    local original_first_joker_name = G.jokers.cards[1].ability.name
    
    self.extractor:extract()
    
    -- Verify G hasn't been modified
    luaunit.assertEquals(#G.jokers.cards, original_joker_count)
    luaunit.assertEquals(G.jokers.cards[1].ability.name, original_first_joker_name)
end

-- Test performance with large number of jokers
function TestJokerReorderExtractor:test_performance_with_many_jokers()
    G = create_mock_g_with_jokers(20)  -- Large number of jokers
    
    local start_time = os.clock()
    local result = self.extractor:extract()
    local end_time = os.clock()
    
    luaunit.assertEquals(result.post_hand_joker_reorder_available, false)
    
    -- Should complete quickly even with many jokers (placeholder implementation)
    local duration = end_time - start_time
    luaunit.assertTrue(duration < 1.0)  -- Should complete in less than 1 second
end

return TestJokerReorderExtractor