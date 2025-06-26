-- Test file for StateExtractorUtils
-- Tests utility functions for safe state extraction

local luaunit = require('luaunit')
local StateExtractorUtils = require("state_extractor.utils.state_extractor_utils")

-- Test StateExtractorUtils
TestStateExtractorUtils = {}

function TestStateExtractorUtils:setUp()
    -- Setup test data
    self.test_table = {
        level1 = {
            level2 = {
                level3 = "deep_value",
                number_value = 42,
                boolean_value = true,
                nil_value = nil
            },
            string_value = "test_string",
            array = {1, 2, 3, "four"}
        },
        root_string = "root_value",
        root_number = 100
    }
end

function TestStateExtractorUtils:tearDown()
    -- Cleanup
end

-- Test safe_check_path with valid paths
function TestStateExtractorUtils:test_safe_check_path_valid()
    luaunit.assertTrue(StateExtractorUtils.safe_check_path(self.test_table, {"level1"}))
    luaunit.assertTrue(StateExtractorUtils.safe_check_path(self.test_table, {"level1", "level2"}))
    luaunit.assertTrue(StateExtractorUtils.safe_check_path(self.test_table, {"level1", "level2", "level3"}))
    luaunit.assertTrue(StateExtractorUtils.safe_check_path(self.test_table, {"level1", "string_value"}))
    luaunit.assertTrue(StateExtractorUtils.safe_check_path(self.test_table, {"root_string"}))
end

-- Test safe_check_path with invalid paths
function TestStateExtractorUtils:test_safe_check_path_invalid()
    luaunit.assertFalse(StateExtractorUtils.safe_check_path(self.test_table, {"nonexistent"}))
    luaunit.assertFalse(StateExtractorUtils.safe_check_path(self.test_table, {"level1", "nonexistent"}))
    luaunit.assertFalse(StateExtractorUtils.safe_check_path(self.test_table, {"level1", "level2", "nonexistent"}))
    luaunit.assertFalse(StateExtractorUtils.safe_check_path(self.test_table, {"level1", "level2", "level3", "too_deep"}))
end

-- Test safe_check_path with nil values
function TestStateExtractorUtils:test_safe_check_path_nil_values()
    luaunit.assertFalse(StateExtractorUtils.safe_check_path(self.test_table, {"level1", "level2", "nil_value"}))
    luaunit.assertFalse(StateExtractorUtils.safe_check_path(nil, {"any", "path"}))
end

-- Test safe_check_path with empty path
function TestStateExtractorUtils:test_safe_check_path_empty_path()
    luaunit.assertTrue(StateExtractorUtils.safe_check_path(self.test_table, {}))
    luaunit.assertFalse(StateExtractorUtils.safe_check_path(nil, {}))
end

-- Test safe_check_path with non-table intermediate values
function TestStateExtractorUtils:test_safe_check_path_non_table_intermediate()
    luaunit.assertFalse(StateExtractorUtils.safe_check_path(self.test_table, {"root_string", "should_fail"}))
    luaunit.assertFalse(StateExtractorUtils.safe_check_path(self.test_table, {"root_number", "should_fail"}))
    luaunit.assertFalse(StateExtractorUtils.safe_check_path(self.test_table, {"level1", "level2", "level3", "should_fail"}))
end

-- Test safe_primitive_nested_value with valid paths
function TestStateExtractorUtils:test_safe_primitive_nested_value_valid()
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(self.test_table, {"level1", "level2", "level3"}, "default"), "deep_value")
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(self.test_table, {"level1", "level2", "number_value"}, 0), 42)
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(self.test_table, {"level1", "level2", "boolean_value"}, false), true)
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(self.test_table, {"level1", "string_value"}, "default"), "test_string")
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(self.test_table, {"root_string"}, "default"), "root_value")
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(self.test_table, {"root_number"}, 0), 100)
end

-- Test safe_primitive_nested_value with invalid paths
function TestStateExtractorUtils:test_safe_primitive_nested_value_invalid()
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(self.test_table, {"nonexistent"}, "default"), "default")
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(self.test_table, {"level1", "nonexistent"}, "default"), "default")
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(self.test_table, {"level1", "level2", "nonexistent"}, 42), 42)
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(self.test_table, {"level1", "level2", "level3", "too_deep"}, "default"), "default")
end

-- Test safe_primitive_nested_value with nil values
function TestStateExtractorUtils:test_safe_primitive_nested_value_nil_values()
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(self.test_table, {"level1", "level2", "nil_value"}, "default"), "default")
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(nil, {"any", "path"}, "default"), "default")
end

-- Test safe_primitive_nested_value with non-primitive values
function TestStateExtractorUtils:test_safe_primitive_nested_value_non_primitive()
    -- Should return default when target is a table/object
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(self.test_table, {"level1"}, "default"), "default")
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(self.test_table, {"level1", "level2"}, "default"), "default")
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(self.test_table, {"level1", "array"}, "default"), "default")
end

-- Test safe_primitive_nested_value with different default types
function TestStateExtractorUtils:test_safe_primitive_nested_value_different_defaults()
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(self.test_table, {"nonexistent"}, "string_default"), "string_default")
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(self.test_table, {"nonexistent"}, 999), 999)
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(self.test_table, {"nonexistent"}, true), true)
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(self.test_table, {"nonexistent"}, false), false)
end

-- Test safe_primitive_value with valid values
function TestStateExtractorUtils:test_safe_primitive_value_valid()
    local test_obj = {
        string_prop = "test_value",
        number_prop = 123,
        boolean_prop = true,
        table_prop = {nested = "value"},
        nil_prop = nil
    }
    
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_value(test_obj, "string_prop", "default"), "test_value")
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_value(test_obj, "number_prop", 0), 123)
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_value(test_obj, "boolean_prop", false), true)
end

-- Test safe_primitive_value with invalid values
function TestStateExtractorUtils:test_safe_primitive_value_invalid()
    local test_obj = {
        string_prop = "test_value",
        table_prop = {nested = "value"},
        nil_prop = nil
    }
    
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_value(test_obj, "nonexistent", "default"), "default")
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_value(test_obj, "nil_prop", "default"), "default")
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_value(test_obj, "table_prop", "default"), "default")
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_value(nil, "any_prop", "default"), "default")
end

-- Test safe_primitive_value with non-table objects
function TestStateExtractorUtils:test_safe_primitive_value_non_table()
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_value("not_a_table", "prop", "default"), "default")
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_value(123, "prop", "default"), "default")
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_value(true, "prop", "default"), "default")
end

-- Test edge cases with empty strings and zero values
function TestStateExtractorUtils:test_edge_cases_empty_and_zero()
    local test_obj = {
        empty_string = "",
        zero_number = 0,
        false_boolean = false
    }
    
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_value(test_obj, "empty_string", "default"), "")
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_value(test_obj, "zero_number", 42), 0)
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_value(test_obj, "false_boolean", true), false)
end

-- Test with complex nested structures
function TestStateExtractorUtils:test_complex_nested_structures()
    local complex_table = {
        game = {
            current_round = {
                hands_left = 3,
                discards_left = 2,
                blind = {
                    name = "Small Blind",
                    ante = 1
                }
            },
            stats = {
                money = 10,
                ante = 1
            }
        }
    }
    
    luaunit.assertTrue(StateExtractorUtils.safe_check_path(complex_table, {"game", "current_round", "hands_left"}))
    luaunit.assertTrue(StateExtractorUtils.safe_check_path(complex_table, {"game", "current_round", "blind", "name"}))
    luaunit.assertFalse(StateExtractorUtils.safe_check_path(complex_table, {"game", "current_round", "blind", "nonexistent"}))
    
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(complex_table, {"game", "current_round", "hands_left"}, 0), 3)
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(complex_table, {"game", "current_round", "blind", "name"}, "Unknown"), "Small Blind")
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(complex_table, {"game", "stats", "money"}, 0), 10)
end

-- Test performance with deep nesting
function TestStateExtractorUtils:test_performance_deep_nesting()
    local deep_table = {}
    local current = deep_table
    
    -- Create a 10-level deep nested structure
    for i = 1, 10 do
        current["level" .. i] = {}
        current = current["level" .. i]
    end
    current.final_value = "deep_success"
    
    local path = {}
    for i = 1, 10 do
        table.insert(path, "level" .. i)
    end
    table.insert(path, "final_value")
    
    local start_time = os.clock()
    local result = StateExtractorUtils.safe_primitive_nested_value(deep_table, path, "default")
    local end_time = os.clock()
    
    luaunit.assertEquals(result, "deep_success")
    
    -- Should complete quickly
    local duration = end_time - start_time
    luaunit.assertTrue(duration < 1.0)
end

-- Test with circular references (should not cause infinite loops)
function TestStateExtractorUtils:test_circular_reference_safety()
    local circular_table = {
        data = "test"
    }
    circular_table.self_ref = circular_table
    
    -- These should not cause infinite loops
    luaunit.assertTrue(StateExtractorUtils.safe_check_path(circular_table, {"data"}))
    luaunit.assertTrue(StateExtractorUtils.safe_check_path(circular_table, {"self_ref"}))
    luaunit.assertFalse(StateExtractorUtils.safe_check_path(circular_table, {"self_ref", "self_ref", "self_ref", "nonexistent"}))
    
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(circular_table, {"data"}, "default"), "test")
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(circular_table, {"self_ref"}, "default"), "default")  -- Should return default for non-primitive
end

-- Test type checking behavior
function TestStateExtractorUtils:test_type_checking()
    local mixed_types = {
        string_val = "hello",
        number_val = 42,
        boolean_val = true,
        table_val = {nested = "value"},
        function_val = function() return "test" end
    }
    
    -- Primitive values should be returned
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_value(mixed_types, "string_val", "default"), "hello")
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_value(mixed_types, "number_val", 0), 42)
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_value(mixed_types, "boolean_val", false), true)
    
    -- Non-primitive values should return default
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_value(mixed_types, "table_val", "default"), "default")
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_value(mixed_types, "function_val", "default"), "default")
end

-- Test with array-like tables
function TestStateExtractorUtils:test_array_like_tables()
    local array_table = {
        cards = {
            {name = "card1", value = 1},
            {name = "card2", value = 2},
            {name = "card3", value = 3}
        }
    }
    
    luaunit.assertTrue(StateExtractorUtils.safe_check_path(array_table, {"cards"}))
    luaunit.assertTrue(StateExtractorUtils.safe_check_path(array_table, {"cards", 1}))
    luaunit.assertTrue(StateExtractorUtils.safe_check_path(array_table, {"cards", 1, "name"}))
    luaunit.assertFalse(StateExtractorUtils.safe_check_path(array_table, {"cards", 5}))  -- Out of bounds
    
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(array_table, {"cards", 1, "name"}, "default"), "card1")
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(array_table, {"cards", 2, "value"}, 0), 2)
    luaunit.assertEquals(StateExtractorUtils.safe_primitive_nested_value(array_table, {"cards", 5, "name"}, "default"), "default")
end

return TestStateExtractorUtils