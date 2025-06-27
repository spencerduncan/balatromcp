-- Test file for CardUtils
-- Tests card-specific utility functions for state extraction

local luaunit = require('libs.luaunit')
local CardUtils = require("state_extractor.utils.card_utils")

-- Test helper functions
local function create_card_with_enhancement(enhancement_name)
    return {
        ability = {
            name = enhancement_name
        }
    }
end

local function create_card_with_edition(edition_type)
    local card = {
        edition = {}
    }
    card.edition[edition_type] = true
    return card
end

local function create_card_with_seal(seal_type)
    return {
        seal = seal_type
    }
end

local function create_joker_with_properties(mult, chips)
    return {
        ability = {
            mult = mult,
            t_chips = chips
        }
    }
end

local function create_blind_with_properties(name, is_boss)
    return {
        name = name,
        boss = is_boss
    }
end

-- Test CardUtils
TestCardUtils = {}

function TestCardUtils:setUp()
    -- Setup test data
end

function TestCardUtils:tearDown()
    -- Cleanup
end

-- Test get_card_enhancement_safe with valid enhancements
function TestCardUtils:test_get_card_enhancement_safe_valid()
    local enhancement_tests = {
        {input = "m_bonus", expected = "bonus"},
        {input = "m_mult", expected = "mult"},
        {input = "m_wild", expected = "wild"},
        {input = "m_glass", expected = "glass"},
        {input = "m_steel", expected = "steel"},
        {input = "m_stone", expected = "stone"},
        {input = "m_gold", expected = "gold"}
    }
    
    for _, test in ipairs(enhancement_tests) do
        local card = create_card_with_enhancement(test.input)
        local result = CardUtils.get_card_enhancement_safe(card)
        luaunit.assertEquals(result, test.expected)
    end
end

-- Test get_card_enhancement_safe with invalid/unknown enhancements
function TestCardUtils:test_get_card_enhancement_safe_invalid()
    local card = create_card_with_enhancement("unknown_enhancement")
    local result = CardUtils.get_card_enhancement_safe(card)
    luaunit.assertEquals(result, "none")
end

-- Test get_card_enhancement_safe with nil/missing data
function TestCardUtils:test_get_card_enhancement_safe_nil_data()
    luaunit.assertEquals(CardUtils.get_card_enhancement_safe(nil), "none")
    luaunit.assertEquals(CardUtils.get_card_enhancement_safe({}), "none")
    luaunit.assertEquals(CardUtils.get_card_enhancement_safe({ability = {}}), "none")
    luaunit.assertEquals(CardUtils.get_card_enhancement_safe({ability = {name = nil}}), "none")
end

-- Test get_card_enhancement_safe with non-string ability name
function TestCardUtils:test_get_card_enhancement_safe_non_string()
    local card = {
        ability = {
            name = 123  -- Not a string
        }
    }
    local result = CardUtils.get_card_enhancement_safe(card)
    luaunit.assertEquals(result, "none")
end

-- Test get_card_edition_safe with valid editions
function TestCardUtils:test_get_card_edition_safe_valid()
    local edition_tests = {
        {input = "foil", expected = "foil"},
        {input = "holo", expected = "holographic"},
        {input = "polychrome", expected = "polychrome"},
        {input = "negative", expected = "negative"}
    }
    
    for _, test in ipairs(edition_tests) do
        local card = create_card_with_edition(test.input)
        local result = CardUtils.get_card_edition_safe(card)
        luaunit.assertEquals(result, test.expected)
    end
end

-- Test get_card_edition_safe with multiple editions (should return first found)
function TestCardUtils:test_get_card_edition_safe_multiple()
    local card = {
        edition = {
            foil = true,
            holo = true  -- Should return foil since it's checked first
        }
    }
    local result = CardUtils.get_card_edition_safe(card)
    luaunit.assertEquals(result, "foil")
end

-- Test get_card_edition_safe with nil/missing data
function TestCardUtils:test_get_card_edition_safe_nil_data()
    luaunit.assertEquals(CardUtils.get_card_edition_safe(nil), "none")
    luaunit.assertEquals(CardUtils.get_card_edition_safe({}), "none")
    luaunit.assertEquals(CardUtils.get_card_edition_safe({edition = {}}), "none")
    luaunit.assertEquals(CardUtils.get_card_edition_safe({edition = "not_a_table"}), "none")
end

-- Test get_card_edition_safe with false values
function TestCardUtils:test_get_card_edition_safe_false_values()
    local card = {
        edition = {
            foil = false,
            holo = false,
            polychrome = false,
            negative = false
        }
    }
    local result = CardUtils.get_card_edition_safe(card)
    luaunit.assertEquals(result, "none")
end

-- Test get_card_seal_safe with valid seals
function TestCardUtils:test_get_card_seal_safe_valid()
    local seal_tests = {"red", "blue", "gold", "purple"}
    
    for _, seal_type in ipairs(seal_tests) do
        local card = create_card_with_seal(seal_type)
        local result = CardUtils.get_card_seal_safe(card)
        luaunit.assertEquals(result, seal_type)
    end
end

-- Test get_card_seal_safe with nil/missing data
function TestCardUtils:test_get_card_seal_safe_nil_data()
    luaunit.assertEquals(CardUtils.get_card_seal_safe(nil), "none")
    luaunit.assertEquals(CardUtils.get_card_seal_safe({}), "none")
    luaunit.assertEquals(CardUtils.get_card_seal_safe({seal = nil}), "none")
end

-- Test extract_joker_properties_safe with valid joker
function TestCardUtils:test_extract_joker_properties_safe_valid()
    local joker = create_joker_with_properties(5, 30)
    local result = CardUtils.extract_joker_properties_safe(joker)
    
    luaunit.assertNotNil(result)
    luaunit.assertEquals(type(result), "table")
    luaunit.assertEquals(result.mult, 5)
    luaunit.assertEquals(result.chips, 30)
end

-- Test extract_joker_properties_safe with nil/missing data
function TestCardUtils:test_extract_joker_properties_safe_nil_data()
    local result = CardUtils.extract_joker_properties_safe(nil)
    luaunit.assertNotNil(result)
    luaunit.assertEquals(type(result), "table")
    
    local result2 = CardUtils.extract_joker_properties_safe({})
    luaunit.assertEquals(result2.mult, 0)
    luaunit.assertEquals(result2.chips, 0)
end

-- Test extract_joker_properties_safe with partial data
function TestCardUtils:test_extract_joker_properties_safe_partial()
    local joker = {
        ability = {
            mult = 3
            -- Missing t_chips
        }
    }
    local result = CardUtils.extract_joker_properties_safe(joker)
    
    luaunit.assertEquals(result.mult, 3)
    luaunit.assertEquals(result.chips, 0)  -- Should default to 0
end

-- Test determine_blind_type_safe with small blind
function TestCardUtils:test_determine_blind_type_safe_small()
    local blind = create_blind_with_properties("Small Blind", false)
    local result = CardUtils.determine_blind_type_safe(blind)
    luaunit.assertEquals(result, "small")
end

-- Test determine_blind_type_safe with big blind
function TestCardUtils:test_determine_blind_type_safe_big()
    local blind = create_blind_with_properties("Big Blind", false)
    local result = CardUtils.determine_blind_type_safe(blind)
    luaunit.assertEquals(result, "big")
end

-- Test determine_blind_type_safe with boss blind
function TestCardUtils:test_determine_blind_type_safe_boss()
    local blind = create_blind_with_properties("The Hook", true)
    local result = CardUtils.determine_blind_type_safe(blind)
    luaunit.assertEquals(result, "boss")
end

-- Test determine_blind_type_safe with nil/missing data
function TestCardUtils:test_determine_blind_type_safe_nil_data()
    luaunit.assertEquals(CardUtils.determine_blind_type_safe(nil), "small")
    luaunit.assertEquals(CardUtils.determine_blind_type_safe({}), "small")
end

-- Test determine_blind_type_safe with boss priority over name
function TestCardUtils:test_determine_blind_type_safe_boss_priority()
    local blind = create_blind_with_properties("Big Boss Blind", true)
    local result = CardUtils.determine_blind_type_safe(blind)
    luaunit.assertEquals(result, "boss")  -- Boss should take priority over "Big" in name
end

-- Test determine_blind_type_safe with case insensitive name matching
function TestCardUtils:test_determine_blind_type_safe_case_insensitive()
    local blind_tests = {
        {name = "big blind", expected = "big"},
        {name = "BIG BLIND", expected = "big"},
        {name = "The Big One", expected = "big"},
        {name = "Small blind", expected = "small"},
        {name = "Random Name", expected = "small"}
    }
    
    for _, test in ipairs(blind_tests) do
        local blind = create_blind_with_properties(test.name, false)
        local result = CardUtils.determine_blind_type_safe(blind)
        luaunit.assertEquals(result, test.expected)
    end
end

-- Test legacy methods for backward compatibility
function TestCardUtils:test_legacy_get_card_enhancement()
    local card = create_card_with_enhancement("m_bonus")
    local result = CardUtils.get_card_enhancement(card)
    luaunit.assertEquals(result, "bonus")
    
    luaunit.assertEquals(CardUtils.get_card_enhancement(nil), "none")
end

function TestCardUtils:test_legacy_get_card_edition()
    local card = create_card_with_edition("foil")
    local result = CardUtils.get_card_edition(card)
    luaunit.assertEquals(result, "foil")
    
    luaunit.assertEquals(CardUtils.get_card_edition(nil), "none")
end

function TestCardUtils:test_legacy_get_card_seal()
    local card = create_card_with_seal("red")
    local result = CardUtils.get_card_seal(card)
    luaunit.assertEquals(result, "red")
    
    luaunit.assertEquals(CardUtils.get_card_seal({}), "none")
end

function TestCardUtils:test_legacy_extract_joker_properties()
    local joker = create_joker_with_properties(5, 30)
    local result = CardUtils.extract_joker_properties(joker)
    
    luaunit.assertNotNil(result)
    luaunit.assertEquals(result.mult, 5)
    luaunit.assertEquals(result.chips, 30)
    
    luaunit.assertNotNil(CardUtils.extract_joker_properties(nil))
end

function TestCardUtils:test_legacy_determine_blind_type()
    local boss_blind = create_blind_with_properties("The Hook", true)
    luaunit.assertEquals(CardUtils.determine_blind_type(boss_blind), "boss")
    
    local big_blind = create_blind_with_properties("Big Blind", false)
    luaunit.assertEquals(CardUtils.determine_blind_type(big_blind), "big")
    
    luaunit.assertEquals(CardUtils.determine_blind_type(nil), "small")
end

-- Test complex card structures
function TestCardUtils:test_complex_card_structures()
    local complex_card = {
        ability = {
            name = "m_glass"
        },
        edition = {
            foil = true
        },
        seal = "gold"
    }
    
    luaunit.assertEquals(CardUtils.get_card_enhancement_safe(complex_card), "glass")
    luaunit.assertEquals(CardUtils.get_card_edition_safe(complex_card), "foil")
    luaunit.assertEquals(CardUtils.get_card_seal_safe(complex_card), "gold")
end

-- Test edge cases with empty strings and special values
function TestCardUtils:test_edge_cases_special_values()
    local card_with_empty_name = {
        ability = {
            name = ""  -- Empty string
        }
    }
    luaunit.assertEquals(CardUtils.get_card_enhancement_safe(card_with_empty_name), "none")
    
    local card_with_empty_seal = create_card_with_seal("")
    luaunit.assertEquals(CardUtils.get_card_seal_safe(card_with_empty_seal), "")
    
    local blind_with_empty_name = create_blind_with_properties("", false)
    luaunit.assertEquals(CardUtils.determine_blind_type_safe(blind_with_empty_name), "small")
end

-- Test type safety with invalid data types
function TestCardUtils:test_type_safety()
    local invalid_card = {
        ability = "not_a_table"
    }
    luaunit.assertEquals(CardUtils.get_card_enhancement_safe(invalid_card), "none")
    
    local invalid_edition_card = {
        edition = "not_a_table"
    }
    luaunit.assertEquals(CardUtils.get_card_edition_safe(invalid_edition_card), "none")
    
    local invalid_blind = {
        name = 123,  -- Not a string
        boss = "not_a_boolean"
    }
    luaunit.assertEquals(CardUtils.determine_blind_type_safe(invalid_blind), "small")
end

-- Test performance with repeated calls
function TestCardUtils:test_performance_repeated_calls()
    local card = create_card_with_enhancement("m_bonus")
    
    local start_time = os.clock()
    for i = 1, 1000 do
        CardUtils.get_card_enhancement_safe(card)
    end
    local end_time = os.clock()
    
    local duration = end_time - start_time
    luaunit.assertTrue(duration < 1.0)  -- Should complete quickly
end

-- Test circular reference safety
function TestCardUtils:test_circular_reference_safety()
    local circular_card = {
        ability = {
            name = "m_bonus"
        }
    }
    circular_card.self_ref = circular_card
    
    -- Should not cause infinite loops
    local result = CardUtils.get_card_enhancement_safe(circular_card)
    luaunit.assertEquals(result, "bonus")
    
    local circular_joker = {
        ability = {
            mult = 5,
            t_chips = 30
        }
    }
    circular_joker.self_ref = circular_joker
    
    local props = CardUtils.extract_joker_properties_safe(circular_joker)
    luaunit.assertEquals(props.mult, 5)
    luaunit.assertEquals(props.chips, 30)
end

-- Test that safe methods avoid extracting complex objects
function TestCardUtils:test_safe_methods_avoid_complex_objects()
    local joker_with_complex_extra = {
        ability = {
            mult = 5,
            t_chips = 30,
            extra = {
                complex_object = {},
                nested_function = function() return "test" end
            }
        }
    }
    
    local props = CardUtils.extract_joker_properties_safe(joker_with_complex_extra)
    
    -- Should only contain primitive values
    luaunit.assertEquals(props.mult, 5)
    luaunit.assertEquals(props.chips, 30)
    luaunit.assertNil(props.extra)  -- Should not extract complex extra object
end

-- Test consistency between safe and legacy methods
function TestCardUtils:test_consistency_between_safe_and_legacy()
    local test_card = create_card_with_enhancement("m_steel")
    
    local safe_result = CardUtils.get_card_enhancement_safe(test_card)
    local legacy_result = CardUtils.get_card_enhancement(test_card)
    
    luaunit.assertEquals(safe_result, legacy_result)
end

return TestCardUtils