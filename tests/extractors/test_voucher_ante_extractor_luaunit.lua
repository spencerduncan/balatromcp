-- Test suite for VoucherAnteExtractor
-- Tests voucher and ante information extraction functionality

local luaunit = require('libs.luaunit')

-- Global test setup
local SMODS = {
    load_file = function(path)
        return loadfile(path)
    end
}

local function setup_mock_g()
    return {
        GAME = {
            round_resets = {
                ante = 3,
                blind = 1
            },
            vouchers = {
                v_overstock = true,
                v_clearance_sale = {
                    name = "Clearance Sale",
                    effect = "All cards in shop cost $1 less",
                    active = true
                }
            }
        },
        shop_vouchers = {
            cards = {
                {
                    ability = {
                        name = "Overstock",
                        effect = "+1 shop slot",
                        description = "Increases shop size"
                    },
                    cost = 10
                },
                {
                    ability = {
                        name = "Clearance Sale", 
                        effect = "All cards cost $1 less",
                        description = "Reduces shop prices"
                    },
                    cost = 8
                }
            }
        },
        consumeables = {
            cards = {
                {
                    ability = {
                        name = "Skip Blind",
                        set = "Spectral",
                        effect = "Skip next blind"
                    },
                    unique_val = "skip_123"
                },
                {
                    ability = {
                        name = "The Fool",
                        set = "Tarot",
                        effect = "Creates a random joker"
                    },
                    unique_val = "fool_456"
                }
            }
        }
    }
end

TestVoucherAnteExtractor = {}

function TestVoucherAnteExtractor:setUp()
    -- Mock the global dependencies
    G = setup_mock_g()
    
    -- Load required modules
    local StateExtractorUtils = assert(SMODS.load_file("state_extractor/utils/state_extractor_utils.lua"))()
    local IExtractor = assert(SMODS.load_file("state_extractor/extractors/i_extractor.lua"))()
    local VoucherAnteExtractor = assert(SMODS.load_file("state_extractor/extractors/voucher_ante_extractor.lua"))()
    
    self.extractor = VoucherAnteExtractor.new()
end

function TestVoucherAnteExtractor:test_extractor_creation()
    luaunit.assertNotNil(self.extractor)
    luaunit.assertEquals(self.extractor:get_name(), "voucher_ante_extractor")
end

function TestVoucherAnteExtractor:test_get_current_ante()
    local current_ante = self.extractor:get_current_ante()
    luaunit.assertEquals(current_ante, 3)
end

function TestVoucherAnteExtractor:test_get_ante_requirements()
    local requirements = self.extractor:get_ante_requirements()
    luaunit.assertNotNil(requirements)
    luaunit.assertEquals(requirements.next_ante, 4)
    luaunit.assertEquals(requirements.blinds_remaining, 1)
end

function TestVoucherAnteExtractor:test_extract_owned_vouchers()
    local owned_vouchers = self.extractor:extract_owned_vouchers()
    luaunit.assertNotNil(owned_vouchers)
    luaunit.assertEquals(#owned_vouchers, 2)
    
    -- Check for boolean voucher
    local overstock_found = false
    for _, voucher in ipairs(owned_vouchers) do
        if voucher.name == "v_overstock" then
            overstock_found = true
            luaunit.assertEquals(voucher.active, true)
            break
        end
    end
    luaunit.assertTrue(overstock_found)
    
    -- Check for table voucher
    local clearance_found = false
    for _, voucher in ipairs(owned_vouchers) do
        if voucher.name == "Clearance Sale" then
            clearance_found = true
            luaunit.assertEquals(voucher.effect, "All cards in shop cost $1 less")
            luaunit.assertEquals(voucher.active, true)
            break
        end
    end
    luaunit.assertTrue(clearance_found)
end

function TestVoucherAnteExtractor:test_extract_shop_vouchers()
    local shop_vouchers = self.extractor:extract_shop_vouchers()
    luaunit.assertNotNil(shop_vouchers)
    luaunit.assertEquals(#shop_vouchers, 2)
    
    local overstock_shop = shop_vouchers[1]
    luaunit.assertEquals(overstock_shop.name, "Overstock")
    luaunit.assertEquals(overstock_shop.cost, 10)
    luaunit.assertEquals(overstock_shop.index, 0) -- 0-based indexing
    luaunit.assertTrue(overstock_shop.available)
    
    local clearance_shop = shop_vouchers[2]
    luaunit.assertEquals(clearance_shop.name, "Clearance Sale")
    luaunit.assertEquals(clearance_shop.cost, 8)
    luaunit.assertEquals(clearance_shop.index, 1)
end

function TestVoucherAnteExtractor:test_extract_skip_vouchers()
    local skip_vouchers = self.extractor:extract_skip_vouchers()
    luaunit.assertNotNil(skip_vouchers)
    
    -- Should find the "Skip Blind" consumable
    local skip_found = false
    for _, skip_voucher in ipairs(skip_vouchers) do
        if skip_voucher.name == "Skip Blind" then
            skip_found = true
            luaunit.assertEquals(skip_voucher.type, "Spectral")
            luaunit.assertEquals(skip_voucher.quantity, 1)
            luaunit.assertEquals(skip_voucher.id, "skip_123")
            break
        end
    end
    luaunit.assertTrue(skip_found)
end

function TestVoucherAnteExtractor:test_is_skip_consumable()
    luaunit.assertTrue(self.extractor:is_skip_consumable("Skip Blind", "Spectral", {}))
    luaunit.assertTrue(self.extractor:is_skip_consumable("Pass Turn", "Tarot", {}))
    luaunit.assertFalse(self.extractor:is_skip_consumable("The Fool", "Tarot", {}))
    luaunit.assertFalse(self.extractor:is_skip_consumable("Normal Card", "Standard", {}))
end

function TestVoucherAnteExtractor:test_is_skip_voucher_effect()
    luaunit.assertTrue(self.extractor:is_skip_voucher_effect("Skip Pack", "Skip next ante"))
    luaunit.assertTrue(self.extractor:is_skip_voucher_effect("Ante Bypass", "Bypass current ante"))
    luaunit.assertFalse(self.extractor:is_skip_voucher_effect("Normal Voucher", "Normal effect"))
end

function TestVoucherAnteExtractor:test_full_extract()
    local result = self.extractor:extract()
    luaunit.assertNotNil(result)
    luaunit.assertNotNil(result.vouchers_ante)
    
    local voucher_data = result.vouchers_ante
    luaunit.assertEquals(voucher_data.current_ante, 3)
    luaunit.assertNotNil(voucher_data.ante_requirements)
    luaunit.assertEquals(voucher_data.ante_requirements.next_ante, 4)
    luaunit.assertNotNil(voucher_data.owned_vouchers)
    luaunit.assertNotNil(voucher_data.shop_vouchers)
    luaunit.assertNotNil(voucher_data.skip_vouchers)
end

function TestVoucherAnteExtractor:test_extract_error_handling()
    -- Test with nil G object
    local original_g = G
    G = nil
    
    local result = self.extractor:extract()
    luaunit.assertNotNil(result)
    luaunit.assertNotNil(result.vouchers_ante)
    
    local voucher_data = result.vouchers_ante
    luaunit.assertEquals(voucher_data.current_ante, 1) -- Default fallback
    luaunit.assertEquals(#voucher_data.owned_vouchers, 0)
    luaunit.assertEquals(#voucher_data.shop_vouchers, 0)
    luaunit.assertEquals(#voucher_data.skip_vouchers, 0)
    
    -- Restore G
    G = original_g
end

function TestVoucherAnteExtractor:test_extract_empty_shop()
    -- Test with empty shop vouchers
    G.shop_vouchers = {cards = {}}
    
    local shop_vouchers = self.extractor:extract_shop_vouchers()
    luaunit.assertNotNil(shop_vouchers)
    luaunit.assertEquals(#shop_vouchers, 0)
end

function TestVoucherAnteExtractor:test_extract_no_consumables()
    -- Test with no consumables
    G.consumeables = {cards = {}}
    
    local skip_vouchers = self.extractor:extract_skip_vouchers()
    luaunit.assertNotNil(skip_vouchers)
    -- May still have skip vouchers from owned vouchers, so just check it's a table
    luaunit.assertEquals(type(skip_vouchers), "table")
end

function TestVoucherAnteExtractor:test_extract_missing_shop_vouchers()
    -- Test with missing shop_vouchers structure
    G.shop_vouchers = nil
    
    local shop_vouchers = self.extractor:extract_shop_vouchers()
    luaunit.assertNotNil(shop_vouchers)
    luaunit.assertEquals(#shop_vouchers, 0)
end

function TestVoucherAnteExtractor:test_extract_alternative_voucher_paths()
    -- Test extracting from alternative voucher storage paths
    G.GAME.vouchers = nil
    G.GAME.used_vouchers = {
        v_telescope = {
            name = "Telescope",
            effect = "Earn $1 at end of round",
            active = false
        }
    }
    
    local owned_vouchers = self.extractor:extract_owned_vouchers()
    luaunit.assertNotNil(owned_vouchers)
    luaunit.assertEquals(#owned_vouchers, 1)
    luaunit.assertEquals(owned_vouchers[1].name, "Telescope")
    luaunit.assertEquals(owned_vouchers[1].active, false)
end

function TestVoucherAnteExtractor:test_extract_complex_skip_vouchers()
    -- Add a voucher that provides skip effects
    G.GAME.vouchers.v_ante_skip = {
        name = "Ante Skip Voucher",
        effect = "Skip next ante requirement",
        active = true
    }
    
    local skip_vouchers = self.extractor:extract_skip_vouchers()
    luaunit.assertNotNil(skip_vouchers)
    
    -- Should find both consumable skip and voucher skip
    local voucher_skip_found = false
    for _, skip_voucher in ipairs(skip_vouchers) do
        if skip_voucher.name == "Ante Skip Voucher" then
            voucher_skip_found = true
            luaunit.assertEquals(skip_voucher.type, "voucher")
            luaunit.assertEquals(skip_voucher.quantity, 1)
            break
        end
    end
    luaunit.assertTrue(voucher_skip_found)
end

function TestVoucherAnteExtractor:test_extract_voucher_data_types()
    -- Test handling different voucher data types
    G.GAME.vouchers = {
        simple_boolean = true,
        complex_table = {
            name = "Complex Voucher",
            effect = "Complex effect",
            description = "Complex description",
            active = true
        },
        false_boolean = false
    }
    
    local owned_vouchers = self.extractor:extract_owned_vouchers()
    luaunit.assertNotNil(owned_vouchers)
    luaunit.assertEquals(#owned_vouchers, 3)
    
    -- Check boolean vouchers
    local simple_found = false
    local false_found = false
    for _, voucher in ipairs(owned_vouchers) do
        if voucher.name == "simple_boolean" then
            simple_found = true
            luaunit.assertEquals(voucher.active, true)
        elseif voucher.name == "false_boolean" then
            false_found = true
            luaunit.assertEquals(voucher.active, false)
        end
    end
    luaunit.assertTrue(simple_found)
    luaunit.assertTrue(false_found)
end

function TestVoucherAnteExtractor:test_interface_compliance()
    -- Test that the extractor implements the IExtractor interface correctly
    local IExtractor = assert(SMODS.load_file("state_extractor/extractors/i_extractor.lua"))()
    
    luaunit.assertTrue(IExtractor.validate_implementation(self.extractor))
    luaunit.assertEquals(type(self.extractor.extract), "function")
    luaunit.assertEquals(type(self.extractor.get_name), "function")
    luaunit.assertEquals(self.extractor:get_name(), "voucher_ante_extractor")
end

function TestVoucherAnteExtractor:test_defensive_shop_voucher_extraction()
    -- Test with malformed shop voucher data
    G.shop_vouchers.cards = {
        nil, -- nil entry
        {}, -- empty table
        {ability = nil}, -- nil ability
        {ability = {name = "Valid Voucher"}}, -- valid entry
        {ability = {name = "Another Valid", cost = nil}} -- missing cost
    }
    
    local shop_vouchers = self.extractor:extract_shop_vouchers()
    luaunit.assertNotNil(shop_vouchers)
    -- Should handle malformed data gracefully and extract valid entries
    luaunit.assertGreaterThan(#shop_vouchers, 0)
end

function TestVoucherAnteExtractor:test_defensive_consumable_extraction()
    -- Test with malformed consumable data
    G.consumeables.cards = {
        nil, -- nil entry
        {}, -- empty table
        {ability = nil}, -- nil ability
        {ability = {name = "Skip Test", set = "Spectral"}}, -- valid skip
        {ability = {name = nil, set = "Tarot"}} -- nil name
    }
    
    local skip_vouchers = self.extractor:extract_skip_vouchers()
    luaunit.assertNotNil(skip_vouchers)
    -- Should handle malformed data gracefully
    luaunit.assertEquals(type(skip_vouchers), "table")
end

function TestVoucherAnteExtractor:test_extract_comprehensive_integration()
    -- Test the complete extraction pipeline
    local full_result = self.extractor:extract()
    luaunit.assertNotNil(full_result)
    luaunit.assertNotNil(full_result.vouchers_ante)
    
    local data = full_result.vouchers_ante
    
    -- Validate structure completeness
    luaunit.assertNotNil(data.current_ante)
    luaunit.assertNotNil(data.ante_requirements)
    luaunit.assertNotNil(data.owned_vouchers)
    luaunit.assertNotNil(data.shop_vouchers)
    luaunit.assertNotNil(data.skip_vouchers)
    
    -- Validate data types
    luaunit.assertEquals(type(data.current_ante), "number")
    luaunit.assertEquals(type(data.ante_requirements), "table")
    luaunit.assertEquals(type(data.owned_vouchers), "table")
    luaunit.assertEquals(type(data.shop_vouchers), "table")
    luaunit.assertEquals(type(data.skip_vouchers), "table")
    
    -- Validate content presence
    luaunit.assertGreaterThan(data.current_ante, 0)
    luaunit.assertGreaterThan(#data.owned_vouchers, 0)
    luaunit.assertGreaterThan(#data.shop_vouchers, 0)
end

return TestVoucherAnteExtractor