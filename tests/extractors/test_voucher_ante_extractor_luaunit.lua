-- Test file for VoucherAnteExtractor
-- Tests voucher and ante extraction functionality

local luaunit = require('libs.luaunit')
local VoucherAnteExtractor = require("state_extractor.extractors.voucher_ante_extractor")

-- Test helper functions
local function create_mock_shop_voucher(name, cost, effect)
    return {
        ability = {
            set = "Voucher",
            name = name or "Test Voucher",
            effect = effect or "Test effect",
            description = "Test description"
        },
        cost = cost or 10
    }
end

local function create_mock_owned_voucher(name, effect, active)
    return {
        name = name or "Test Voucher",
        effect = effect or "Test effect", 
        description = "Test description",
        active = active ~= false
    }
end

local function create_mock_consumable(name, set, ability_name)
    return {
        ability = {
            set = set or "Tarot",
            name = ability_name or name or "Test Consumable"
        },
        unique_val = "consumable_" .. (name or "test")
    }
end

local function create_mock_g_with_ante(ante)
    return {
        GAME = {
            round_resets = {
                ante = ante or 1,
                blind = 0
            },
            dollars = 100
        }
    }
end

local function create_mock_g_with_vouchers(owned_vouchers, shop_vouchers, consumables)
    local mock_g = {
        GAME = {
            round_resets = {
                ante = 3,
                blind = 1
            },
            dollars = 150,
            vouchers = owned_vouchers or {}
        },
        shop_vouchers = {
            cards = shop_vouchers or {}
        },
        consumeables = {
            cards = consumables or {}
        }
    }
    return mock_g
end

local function create_mock_g_with_alternative_voucher_paths(path_type, voucher_data)
    local mock_g = {
        GAME = {
            round_resets = {
                ante = 2,
                blind = 0
            },
            dollars = 75
        }
    }
    
    if path_type == "used_vouchers" then
        mock_g.GAME.used_vouchers = voucher_data or {}
    elseif path_type == "owned_vouchers" then
        mock_g.GAME.owned_vouchers = voucher_data or {}
    else
        mock_g.GAME.vouchers = voucher_data or {}
    end
    
    return mock_g
end

-- Test VoucherAnteExtractor
TestVoucherAnteExtractor = {}

function TestVoucherAnteExtractor:setUp()
    self.extractor = VoucherAnteExtractor.new()
    -- Store original G
    self.original_G = G
end

function TestVoucherAnteExtractor:tearDown()
    -- Restore original G
    G = self.original_G
end

-- Test basic extractor properties
function TestVoucherAnteExtractor:test_get_name()
    luaunit.assertEquals(self.extractor:get_name(), "voucher_ante_extractor")
end

-- Test current ante extraction
function TestVoucherAnteExtractor:test_get_current_ante_basic()
    G = create_mock_g_with_ante(5)
    local ante = self.extractor:get_current_ante()
    luaunit.assertEquals(ante, 5)
end

function TestVoucherAnteExtractor:test_get_current_ante_nil_game()
    G = nil
    local ante = self.extractor:get_current_ante()
    luaunit.assertEquals(ante, 1)  -- Should return default value
end

function TestVoucherAnteExtractor:test_get_current_ante_missing_path()
    G = {GAME = {}}  -- Missing round_resets.ante
    local ante = self.extractor:get_current_ante()
    luaunit.assertEquals(ante, 1)  -- Should return default value
end

-- Test ante requirements extraction
function TestVoucherAnteExtractor:test_get_ante_requirements()
    G = create_mock_g_with_ante(3)
    local requirements = self.extractor:get_ante_requirements()
    
    luaunit.assertNotNil(requirements)
    luaunit.assertEquals(requirements.next_ante, 4)
    luaunit.assertEquals(type(requirements.blinds_remaining), "number")
end

-- Test shop vouchers extraction
function TestVoucherAnteExtractor:test_extract_shop_vouchers_empty()
    G = {shop_vouchers = {cards = {}}}
    local shop_vouchers = self.extractor:extract_shop_vouchers()
    
    luaunit.assertNotNil(shop_vouchers)
    luaunit.assertEquals(#shop_vouchers, 0)
end

function TestVoucherAnteExtractor:test_extract_shop_vouchers_single()
    local mock_voucher = create_mock_shop_voucher("Overstock", 20, "Adds extra shop slot")
    G = {shop_vouchers = {cards = {mock_voucher}}}
    
    local shop_vouchers = self.extractor:extract_shop_vouchers()
    
    luaunit.assertEquals(#shop_vouchers, 1)
    luaunit.assertEquals(shop_vouchers[1].index, 0)  -- 0-based indexing
    luaunit.assertEquals(shop_vouchers[1].name, "Overstock")
    luaunit.assertEquals(shop_vouchers[1].cost, 20)
    luaunit.assertEquals(shop_vouchers[1].available, true)
end

function TestVoucherAnteExtractor:test_extract_shop_vouchers_multiple()
    local voucher1 = create_mock_shop_voucher("Overstock", 20, "Extra shop slot")
    local voucher2 = create_mock_shop_voucher("Clearance Sale", 30, "Rerolls cost less")
    G = {shop_vouchers = {cards = {voucher1, voucher2}}}
    
    local shop_vouchers = self.extractor:extract_shop_vouchers()
    
    luaunit.assertEquals(#shop_vouchers, 2)
    luaunit.assertEquals(shop_vouchers[1].name, "Overstock")
    luaunit.assertEquals(shop_vouchers[2].name, "Clearance Sale")
    luaunit.assertEquals(shop_vouchers[2].index, 1)
end

function TestVoucherAnteExtractor:test_extract_shop_vouchers_nil_path()
    G = {}  -- No shop_vouchers path
    local shop_vouchers = self.extractor:extract_shop_vouchers()
    
    luaunit.assertNotNil(shop_vouchers)
    luaunit.assertEquals(#shop_vouchers, 0)
end

-- Test owned vouchers extraction
function TestVoucherAnteExtractor:test_extract_owned_vouchers_empty_primary_path()
    G = create_mock_g_with_vouchers({}, {}, {})
    local owned_vouchers = self.extractor:extract_owned_vouchers()
    
    luaunit.assertNotNil(owned_vouchers)
    luaunit.assertEquals(#owned_vouchers, 0)
end

function TestVoucherAnteExtractor:test_extract_owned_vouchers_table_format()
    local voucher_data = {
        overstock = {
            name = "Overstock",
            effect = "Adds extra shop slot",
            active = true
        },
        clearance = {
            name = "Clearance Sale", 
            effect = "Rerolls cost less",
            active = true
        }
    }
    
    G = create_mock_g_with_vouchers(voucher_data, {}, {})
    local owned_vouchers = self.extractor:extract_owned_vouchers()
    
    luaunit.assertNotNil(owned_vouchers)
    luaunit.assertEquals(#owned_vouchers, 2)
    
    -- Find vouchers by name (order not guaranteed)
    local overstock_found = false
    local clearance_found = false
    
    for _, voucher in ipairs(owned_vouchers) do
        if voucher.name == "Overstock" then
            overstock_found = true
            luaunit.assertEquals(voucher.effect, "Adds extra shop slot")
            luaunit.assertEquals(voucher.active, true)
        elseif voucher.name == "Clearance Sale" then
            clearance_found = true
            luaunit.assertEquals(voucher.effect, "Rerolls cost less")
            luaunit.assertEquals(voucher.active, true)
        end
    end
    
    luaunit.assertTrue(overstock_found, "Overstock voucher should be found")
    luaunit.assertTrue(clearance_found, "Clearance Sale voucher should be found")
end

function TestVoucherAnteExtractor:test_extract_owned_vouchers_boolean_format()
    local voucher_data = {
        overstock = true,
        clearance = false
    }
    
    G = create_mock_g_with_vouchers(voucher_data, {}, {})
    local owned_vouchers = self.extractor:extract_owned_vouchers()
    
    luaunit.assertEquals(#owned_vouchers, 2)
    
    -- Check that boolean values are converted correctly
    for _, voucher in ipairs(owned_vouchers) do
        if voucher.name == "overstock" then
            luaunit.assertEquals(voucher.active, true)
        elseif voucher.name == "clearance" then
            luaunit.assertEquals(voucher.active, false)
        end
    end
end

function TestVoucherAnteExtractor:test_extract_owned_vouchers_alternative_paths()
    local voucher_data = {
        test_voucher = {
            name = "Test Voucher",
            effect = "Test effect",
            active = true
        }
    }
    
    -- Test used_vouchers path
    G = create_mock_g_with_alternative_voucher_paths("used_vouchers", voucher_data)
    local owned_vouchers = self.extractor:extract_owned_vouchers()
    luaunit.assertEquals(#owned_vouchers, 1)
    luaunit.assertEquals(owned_vouchers[1].name, "Test Voucher")
    
    -- Test owned_vouchers path
    G = create_mock_g_with_alternative_voucher_paths("owned_vouchers", voucher_data)
    owned_vouchers = self.extractor:extract_owned_vouchers()
    luaunit.assertEquals(#owned_vouchers, 1)
    luaunit.assertEquals(owned_vouchers[1].name, "Test Voucher")
end

-- Test skip vouchers extraction
function TestVoucherAnteExtractor:test_extract_skip_vouchers_empty()
    G = create_mock_g_with_vouchers({}, {}, {})
    local skip_vouchers = self.extractor:extract_skip_vouchers()
    
    luaunit.assertNotNil(skip_vouchers)
    luaunit.assertEquals(#skip_vouchers, 0)
end

function TestVoucherAnteExtractor:test_extract_skip_vouchers_from_consumables()
    local skip_consumable = create_mock_consumable("Skip Card", "Spectral", "Skip")
    G = create_mock_g_with_vouchers({}, {}, {skip_consumable})
    
    local skip_vouchers = self.extractor:extract_skip_vouchers()
    
    luaunit.assertEquals(#skip_vouchers, 1)
    luaunit.assertEquals(skip_vouchers[1].name, "Skip")
    luaunit.assertEquals(skip_vouchers[1].type, "Spectral")
    luaunit.assertEquals(skip_vouchers[1].quantity, 1)
end

function TestVoucherAnteExtractor:test_extract_skip_vouchers_from_owned_vouchers()
    local skip_voucher_data = {
        ante_skip = {
            name = "Ante Skipper",
            effect = "Skip current ante",
            active = true
        }
    }
    
    G = create_mock_g_with_vouchers(skip_voucher_data, {}, {})
    local skip_vouchers = self.extractor:extract_skip_vouchers()
    
    luaunit.assertEquals(#skip_vouchers, 1)
    luaunit.assertEquals(skip_vouchers[1].name, "Ante Skipper")
    luaunit.assertEquals(skip_vouchers[1].type, "voucher")
    luaunit.assertEquals(skip_vouchers[1].quantity, 1)
end

-- Test helper method: is_skip_consumable
function TestVoucherAnteExtractor:test_is_skip_consumable()
    luaunit.assertTrue(self.extractor:is_skip_consumable("Skip Card", "Spectral", {}))
    luaunit.assertTrue(self.extractor:is_skip_consumable("Pass Blind", "Tarot", {}))
    luaunit.assertTrue(self.extractor:is_skip_consumable("Bypass Ante", "Planet", {}))
    luaunit.assertFalse(self.extractor:is_skip_consumable("Normal Card", "Tarot", {}))
    luaunit.assertFalse(self.extractor:is_skip_consumable(nil, "Tarot", {}))
end

-- Test helper method: is_skip_voucher_effect
function TestVoucherAnteExtractor:test_is_skip_voucher_effect()
    luaunit.assertTrue(self.extractor:is_skip_voucher_effect("Ante Skip", "Skip the current ante"))
    luaunit.assertTrue(self.extractor:is_skip_voucher_effect("Bypass Card", "Bypass blind requirements"))
    luaunit.assertTrue(self.extractor:is_skip_voucher_effect("Pass Helper", "Pass current round"))
    luaunit.assertFalse(self.extractor:is_skip_voucher_effect("Normal Voucher", "Normal effect"))
    luaunit.assertFalse(self.extractor:is_skip_voucher_effect(nil, nil))
end

-- Test full extraction
function TestVoucherAnteExtractor:test_full_extract()
    local owned_vouchers = {
        overstock = {
            name = "Overstock",
            effect = "Adds extra shop slot",
            active = true
        }
    }
    
    local shop_vouchers = {
        create_mock_shop_voucher("Clearance Sale", 30, "Rerolls cost less")
    }
    
    local consumables = {
        create_mock_consumable("Skip Card", "Spectral", "Skip")
    }
    
    G = create_mock_g_with_vouchers(owned_vouchers, shop_vouchers, consumables)
    
    local result = self.extractor:extract()
    
    luaunit.assertNotNil(result)
    luaunit.assertNotNil(result.vouchers_ante)
    
    local data = result.vouchers_ante
    luaunit.assertNotNil(data.current_ante)
    luaunit.assertNotNil(data.ante_requirements)
    luaunit.assertNotNil(data.owned_vouchers)
    luaunit.assertNotNil(data.shop_vouchers)
    luaunit.assertNotNil(data.skip_vouchers)
    
    luaunit.assertEquals(data.current_ante, 3)
    luaunit.assertEquals(#data.owned_vouchers, 1)
    luaunit.assertEquals(#data.shop_vouchers, 1)
    luaunit.assertEquals(#data.skip_vouchers, 1)
end

function TestVoucherAnteExtractor:test_extract_error_handling()
    G = nil  -- Force an error condition
    
    local result = self.extractor:extract()
    
    luaunit.assertNotNil(result)
    luaunit.assertNotNil(result.vouchers_ante)
    
    local data = result.vouchers_ante
    luaunit.assertEquals(data.current_ante, 1)
    luaunit.assertEquals(#data.owned_vouchers, 0)
    luaunit.assertEquals(#data.shop_vouchers, 0)
    luaunit.assertEquals(#data.skip_vouchers, 0)
end

-- Run the tests
if _G.luaunit then
    local runner = luaunit.LuaUnit.new()
    runner:setOutputType("text")
    runner:runSuite()
end

return TestVoucherAnteExtractor