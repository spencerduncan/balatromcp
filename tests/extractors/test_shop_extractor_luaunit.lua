-- Test file for ShopExtractor
-- Tests shop contents extraction functionality

local luaunit = require('luaunit')
local ShopExtractor = require("state_extractor.extractors.shop_extractor")

-- Test helper functions
local function create_mock_shop_item(ability_set, name, cost)
    return {
        ability = {
            set = ability_set,
            name = name or "Test Item"
        },
        cost = cost or 10
    }
end

local function create_mock_g_with_shop_jokers(joker_items)
    return {
        shop_jokers = {
            cards = joker_items or {}
        }
    }
end

local function create_mock_g_with_shop_consumables(consumable_items)
    return {
        shop_consumables = {
            cards = consumable_items or {}
        }
    }
end

local function create_mock_g_with_shop_boosters(booster_items)
    return {
        shop_booster = {
            cards = booster_items or {}
        }
    }
end

local function create_mock_g_with_shop_vouchers(voucher_items)
    return {
        shop_vouchers = {
            cards = voucher_items or {}
        }
    }
end

local function create_mock_g_with_full_shop(jokers, consumables, boosters, vouchers)
    return {
        shop_jokers = {
            cards = jokers or {}
        },
        shop_consumables = {
            cards = consumables or {}
        },
        shop_booster = {
            cards = boosters or {}
        },
        shop_vouchers = {
            cards = vouchers or {}
        }
    }
end

-- Test ShopExtractor
TestShopExtractor = {}

function TestShopExtractor:setUp()
    self.extractor = ShopExtractor.new()
    -- Store original G
    self.original_G = G
end

function TestShopExtractor:tearDown()
    -- Restore original G
    G = self.original_G
end

-- Test extractor creation and basic interface
function TestShopExtractor:test_extractor_creation()
    luaunit.assertNotNil(self.extractor)
    luaunit.assertEquals(self.extractor:get_name(), "shop_extractor")
end

-- Test extract method with valid game state
function TestShopExtractor:test_extract_with_valid_state()
    local jokers = {
        create_mock_shop_item("Joker", "Test Joker", 5)
    }
    G = create_mock_g_with_shop_jokers(jokers)
    
    local result = self.extractor:extract()
    
    luaunit.assertNotNil(result)
    luaunit.assertNotNil(result.shop_contents)
    luaunit.assertEquals(type(result.shop_contents), "table")
    luaunit.assertEquals(#result.shop_contents, 1)
end

-- Test extract method with invalid game state
function TestShopExtractor:test_extract_with_invalid_state()
    G = nil
    
    local result = self.extractor:extract()
    
    luaunit.assertNotNil(result)
    luaunit.assertNotNil(result.shop_contents)
    luaunit.assertEquals(type(result.shop_contents), "table")
    luaunit.assertEquals(#result.shop_contents, 0)
end

-- Test extract method with empty shop
function TestShopExtractor:test_extract_with_empty_shop()
    G = create_mock_g_with_full_shop()
    
    local result = self.extractor:extract()
    
    luaunit.assertNotNil(result)
    luaunit.assertNotNil(result.shop_contents)
    luaunit.assertEquals(#result.shop_contents, 0)
end

-- Test joker extraction
function TestShopExtractor:test_extract_jokers()
    local jokers = {
        create_mock_shop_item("Joker", "Test Joker 1", 5),
        create_mock_shop_item("Joker", "Test Joker 2", 8)
    }
    G = create_mock_g_with_shop_jokers(jokers)
    
    local contents = self.extractor:extract_shop_contents()
    
    luaunit.assertEquals(#contents, 2)
    
    -- Check first joker
    luaunit.assertEquals(contents[1].index, 0)
    luaunit.assertEquals(contents[1].item_type, "joker")
    luaunit.assertEquals(contents[1].name, "Test Joker 1")
    luaunit.assertEquals(contents[1].cost, 5)
    luaunit.assertNotNil(contents[1].properties)
    
    -- Check second joker
    luaunit.assertEquals(contents[2].index, 1)
    luaunit.assertEquals(contents[2].item_type, "joker")
    luaunit.assertEquals(contents[2].name, "Test Joker 2")
    luaunit.assertEquals(contents[2].cost, 8)
end

-- Test planet card extraction
function TestShopExtractor:test_extract_planets()
    local planets = {
        create_mock_shop_item("Planet", "Mercury", 3),
        create_mock_shop_item("Planet", "Venus", 4)
    }
    G = create_mock_g_with_shop_jokers(planets)
    
    local contents = self.extractor:extract_shop_contents()
    
    luaunit.assertEquals(#contents, 2)
    luaunit.assertEquals(contents[1].item_type, "planet")
    luaunit.assertEquals(contents[1].name, "Mercury")
    luaunit.assertEquals(contents[2].item_type, "planet")
    luaunit.assertEquals(contents[2].name, "Venus")
end

-- Test tarot card extraction
function TestShopExtractor:test_extract_tarots()
    local tarots = {
        create_mock_shop_item("Tarot", "The Fool", 3),
        create_mock_shop_item("Tarot", "The Magician", 3)
    }
    G = create_mock_g_with_shop_jokers(tarots)
    
    local contents = self.extractor:extract_shop_contents()
    
    luaunit.assertEquals(#contents, 2)
    luaunit.assertEquals(contents[1].item_type, "tarot")
    luaunit.assertEquals(contents[1].name, "The Fool")
    luaunit.assertEquals(contents[2].item_type, "tarot")
    luaunit.assertEquals(contents[2].name, "The Magician")
end

-- Test spectral card extraction
function TestShopExtractor:test_extract_spectrals()
    local spectrals = {
        create_mock_shop_item("Spectral", "Familiar", 4)
    }
    G = create_mock_g_with_shop_jokers(spectrals)
    
    local contents = self.extractor:extract_shop_contents()
    
    luaunit.assertEquals(#contents, 1)
    luaunit.assertEquals(contents[1].item_type, "spectral")
    luaunit.assertEquals(contents[1].name, "Familiar")
end

-- Test booster pack extraction
function TestShopExtractor:test_extract_boosters()
    local boosters = {
        create_mock_shop_item("Booster", "Arcana Pack", 4)
    }
    G = create_mock_g_with_shop_jokers(boosters)
    
    local contents = self.extractor:extract_shop_contents()
    
    luaunit.assertEquals(#contents, 1)
    luaunit.assertEquals(contents[1].item_type, "booster")
    luaunit.assertEquals(contents[1].name, "Arcana Pack")
end

-- Test unknown item type handling
function TestShopExtractor:test_extract_unknown_item_type()
    local unknowns = {
        create_mock_shop_item("CustomType", "Custom Item", 7)
    }
    G = create_mock_g_with_shop_jokers(unknowns)
    
    local contents = self.extractor:extract_shop_contents()
    
    luaunit.assertEquals(#contents, 1)
    luaunit.assertEquals(contents[1].item_type, "customtype")
    luaunit.assertEquals(contents[1].name, "Custom Item")
end

-- Test consumables from shop_consumables
function TestShopExtractor:test_extract_shop_consumables()
    local consumables = {
        create_mock_shop_item("Tarot", "The Hermit", 3),
        create_mock_shop_item("Planet", "Jupiter", 3)
    }
    G = create_mock_g_with_shop_consumables(consumables)
    
    local contents = self.extractor:extract_shop_contents()
    
    luaunit.assertEquals(#contents, 2)
    luaunit.assertEquals(contents[1].index, 0)
    luaunit.assertEquals(contents[1].item_type, "tarot")
    luaunit.assertEquals(contents[2].index, 1)
    luaunit.assertEquals(contents[2].item_type, "planet")
end

-- Test boosters from shop_booster
function TestShopExtractor:test_extract_shop_booster()
    local boosters = {
        create_mock_shop_item("Booster", "Standard Pack", 4)
    }
    G = create_mock_g_with_shop_boosters(boosters)
    
    local contents = self.extractor:extract_shop_contents()
    
    luaunit.assertEquals(#contents, 1)
    luaunit.assertEquals(contents[1].index, 0)
    luaunit.assertEquals(contents[1].item_type, "booster")
    luaunit.assertEquals(contents[1].name, "Standard Pack")
end

-- Test vouchers from shop_vouchers
function TestShopExtractor:test_extract_shop_vouchers()
    local vouchers = {
        create_mock_shop_item("Voucher", "Overstock", 10)
    }
    G = create_mock_g_with_shop_vouchers(vouchers)
    
    local contents = self.extractor:extract_shop_contents()
    
    luaunit.assertEquals(#contents, 1)
    luaunit.assertEquals(contents[1].index, 0)
    luaunit.assertEquals(contents[1].item_type, "voucher")
    luaunit.assertEquals(contents[1].name, "Overstock")
end

-- Test combined shop collections with correct indexing
function TestShopExtractor:test_extract_combined_shop_collections()
    local jokers = {
        create_mock_shop_item("Joker", "Joker 1", 5)
    }
    local consumables = {
        create_mock_shop_item("Tarot", "Tarot 1", 3)
    }
    local boosters = {
        create_mock_shop_item("Booster", "Booster 1", 4)
    }
    local vouchers = {
        create_mock_shop_item("Voucher", "Voucher 1", 10)
    }
    
    G = create_mock_g_with_full_shop(jokers, consumables, boosters, vouchers)
    
    local contents = self.extractor:extract_shop_contents()
    
    luaunit.assertEquals(#contents, 4)
    
    -- Check correct indexing across collections
    luaunit.assertEquals(contents[1].index, 0)  -- Joker
    luaunit.assertEquals(contents[1].item_type, "joker")
    
    luaunit.assertEquals(contents[2].index, 1)  -- Consumable continues indexing
    luaunit.assertEquals(contents[2].item_type, "tarot")
    
    luaunit.assertEquals(contents[3].index, 2)  -- Booster continues indexing
    luaunit.assertEquals(contents[3].item_type, "booster")
    
    luaunit.assertEquals(contents[4].index, 3)  -- Voucher continues indexing
    luaunit.assertEquals(contents[4].item_type, "voucher")
end

-- Test items without ability structure
function TestShopExtractor:test_extract_items_without_ability()
    local invalid_items = {
        { name = "Invalid Item" },  -- No ability
        { ability = { name = "Missing Set" } }  -- No ability.set
    }
    G = create_mock_g_with_shop_jokers(invalid_items)
    
    local contents = self.extractor:extract_shop_contents()
    
    luaunit.assertEquals(#contents, 0)  -- Should skip invalid items
end

-- Test items with missing name
function TestShopExtractor:test_extract_items_with_missing_name()
    local items = {
        {
            ability = {
                set = "Joker"
                -- Missing name
            },
            cost = 5
        }
    }
    G = create_mock_g_with_shop_jokers(items)
    
    local contents = self.extractor:extract_shop_contents()
    
    luaunit.assertEquals(#contents, 1)
    luaunit.assertEquals(contents[1].name, "Unknown")  -- Should use default
end

-- Test items with missing cost
function TestShopExtractor:test_extract_items_with_missing_cost()
    local items = {
        {
            ability = {
                set = "Joker",
                name = "Test Joker"
            }
            -- Missing cost
        }
    }
    G = create_mock_g_with_shop_jokers(items)
    
    local contents = self.extractor:extract_shop_contents()
    
    luaunit.assertEquals(#contents, 1)
    luaunit.assertEquals(contents[1].cost, 0)  -- Should use default
end

-- Test with invalid G structure
function TestShopExtractor:test_extract_with_invalid_g_structure()
    G = {
        shop_jokers = "not_a_table"
    }
    
    local contents = self.extractor:extract_shop_contents()
    
    luaunit.assertEquals(#contents, 0)
end

-- Test with missing shop collections
function TestShopExtractor:test_extract_with_missing_collections()
    G = {}  -- No shop collections
    
    local contents = self.extractor:extract_shop_contents()
    
    luaunit.assertEquals(#contents, 0)
end

-- Test with nil G
function TestShopExtractor:test_extract_with_nil_g()
    G = nil
    
    local contents = self.extractor:extract_shop_contents()
    
    luaunit.assertEquals(#contents, 0)
end

-- Test properties are empty (avoiding circular references)
function TestShopExtractor:test_extract_properties_are_empty()
    local jokers = {
        create_mock_shop_item("Joker", "Test Joker", 5)
    }
    G = create_mock_g_with_shop_jokers(jokers)
    
    local contents = self.extractor:extract_shop_contents()
    
    luaunit.assertEquals(#contents, 1)
    luaunit.assertNotNil(contents[1].properties)
    luaunit.assertEquals(type(contents[1].properties), "table")
    
    -- Check that properties table is empty
    local count = 0
    for _ in pairs(contents[1].properties) do
        count = count + 1
    end
    luaunit.assertEquals(count, 0)
end

-- Test large shop with multiple item types
function TestShopExtractor:test_extract_large_mixed_shop()
    local jokers = {}
    local consumables = {}
    
    -- Add multiple jokers
    for i = 1, 3 do
        table.insert(jokers, create_mock_shop_item("Joker", "Joker " .. i, i * 2))
    end
    
    -- Add multiple consumables
    for i = 1, 2 do
        table.insert(consumables, create_mock_shop_item("Planet", "Planet " .. i, i * 3))
    end
    
    G = create_mock_g_with_full_shop(jokers, consumables, {}, {})
    
    local contents = self.extractor:extract_shop_contents()
    
    luaunit.assertEquals(#contents, 5)
    
    -- Verify jokers
    for i = 1, 3 do
        luaunit.assertEquals(contents[i].index, i - 1)
        luaunit.assertEquals(contents[i].item_type, "joker")
        luaunit.assertEquals(contents[i].name, "Joker " .. i)
        luaunit.assertEquals(contents[i].cost, i * 2)
    end
    
    -- Verify consumables
    for i = 4, 5 do
        local consumable_index = i - 3
        luaunit.assertEquals(contents[i].index, i - 1)
        luaunit.assertEquals(contents[i].item_type, "planet")
        luaunit.assertEquals(contents[i].name, "Planet " .. consumable_index)
        luaunit.assertEquals(contents[i].cost, consumable_index * 3)
    end
end

return TestShopExtractor