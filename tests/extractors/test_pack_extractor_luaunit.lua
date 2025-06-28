-- Test file for PackExtractor
-- Tests pack contents extraction functionality

local luaunit = require('libs.luaunit')
local PackExtractor = require("state_extractor.extractors.pack_extractor")

-- Test helper functions
local function create_mock_pack_card(ability_set, name, cost, base_data)
    local card = {
        ability = {
            set = ability_set,
            name = name or "Test Card"
        },
        cost = cost or 0
    }
    
    -- Add base data for playing cards
    if base_data then
        card.base = base_data
    end
    
    return card
end

local function create_mock_playing_card(suit, value, id)
    return create_mock_pack_card("Playing", "Playing Card", 0, {
        suit = suit or "Spades",
        value = value or "A",
        id = id or "AS"
    })
end

local function create_mock_joker_card(name)
    return create_mock_pack_card("Joker", name or "Test Joker", 0)
end

local function create_mock_tarot_card(name)
    return create_mock_pack_card("Tarot", name or "Test Tarot", 0)
end

local function create_mock_planet_card(name)
    return create_mock_pack_card("Planet", name or "Test Planet", 0)
end

local function create_mock_spectral_card(name)
    return create_mock_pack_card("Spectral", name or "Test Spectral", 0)
end

local function create_mock_g_with_pack_cards(pack_cards)
    return {
        pack_cards = {
            cards = pack_cards or {}
        }
    }
end

local function create_mock_g_empty()
    return {}
end

-- Test PackExtractor
TestPackExtractor = {}

function TestPackExtractor:setUp()
    self.extractor = PackExtractor.new()
    -- Store original G
    self.original_G = G
end

function TestPackExtractor:tearDown()
    -- Restore original G
    G = self.original_G
end

-- Test extractor creation and basic interface
function TestPackExtractor:test_extractor_creation()
    luaunit.assertNotNil(self.extractor)
    luaunit.assertEquals(self.extractor:get_name(), "pack_extractor")
end

-- Test extract method with valid pack state
function TestPackExtractor:test_extract_with_valid_pack_state()
    local pack_cards = {
        create_mock_playing_card("Hearts", "K", "KH"),
        create_mock_joker_card("Test Joker")
    }
    G = create_mock_g_with_pack_cards(pack_cards)
    
    local result = self.extractor:extract()
    
    luaunit.assertNotNil(result)
    luaunit.assertNotNil(result.pack_contents)
    luaunit.assertEquals(type(result.pack_contents), "table")
    luaunit.assertEquals(#result.pack_contents, 2)
end

-- Test extract method with no pack_cards
function TestPackExtractor:test_extract_with_no_pack_cards()
    G = create_mock_g_empty()
    
    local result = self.extractor:extract()
    
    luaunit.assertNotNil(result)
    luaunit.assertNotNil(result.pack_contents)
    luaunit.assertEquals(type(result.pack_contents), "table")
    luaunit.assertEquals(#result.pack_contents, 0)
end

-- Test extract method with nil G
function TestPackExtractor:test_extract_with_nil_g()
    G = nil
    
    local result = self.extractor:extract()
    
    luaunit.assertNotNil(result)
    luaunit.assertNotNil(result.pack_contents)
    luaunit.assertEquals(type(result.pack_contents), "table")
    luaunit.assertEquals(#result.pack_contents, 0)
end

-- Test extract method with empty pack
function TestPackExtractor:test_extract_with_empty_pack()
    G = create_mock_g_with_pack_cards({})
    
    local result = self.extractor:extract()
    
    luaunit.assertNotNil(result)
    luaunit.assertNotNil(result.pack_contents)
    luaunit.assertEquals(#result.pack_contents, 0)
end

-- Test playing card extraction
function TestPackExtractor:test_extract_playing_cards()
    local pack_cards = {
        create_mock_playing_card("Hearts", "K", "KH"),
        create_mock_playing_card("Spades", "A", "AS")
    }
    G = create_mock_g_with_pack_cards(pack_cards)
    
    local result = self.extractor:extract()
    local pack_contents = result.pack_contents
    
    luaunit.assertEquals(#pack_contents, 2)
    
    -- Test first card
    luaunit.assertEquals(pack_contents[1].index, 0) -- 0-based indexing
    luaunit.assertEquals(pack_contents[1].card_type, "playing")
    luaunit.assertEquals(pack_contents[1].name, "Playing Card")
    luaunit.assertEquals(pack_contents[1].properties.suit, "Hearts")
    luaunit.assertEquals(pack_contents[1].properties.rank, "K")
    luaunit.assertEquals(pack_contents[1].properties.key, "KH")
    
    -- Test second card
    luaunit.assertEquals(pack_contents[2].index, 1)
    luaunit.assertEquals(pack_contents[2].card_type, "playing")
    luaunit.assertEquals(pack_contents[2].properties.suit, "Spades")
    luaunit.assertEquals(pack_contents[2].properties.rank, "A")
end

-- Test joker card extraction
function TestPackExtractor:test_extract_joker_cards()
    local pack_cards = {
        create_mock_joker_card("Test Joker 1"),
        create_mock_joker_card("Test Joker 2")
    }
    G = create_mock_g_with_pack_cards(pack_cards)
    
    local result = self.extractor:extract()
    local pack_contents = result.pack_contents
    
    luaunit.assertEquals(#pack_contents, 2)
    luaunit.assertEquals(pack_contents[1].card_type, "joker")
    luaunit.assertEquals(pack_contents[1].name, "Test Joker 1")
    luaunit.assertEquals(pack_contents[2].card_type, "joker")
    luaunit.assertEquals(pack_contents[2].name, "Test Joker 2")
end

-- Test tarot card extraction
function TestPackExtractor:test_extract_tarot_cards()
    local pack_cards = {
        create_mock_tarot_card("The Fool"),
        create_mock_tarot_card("The Magician")
    }
    G = create_mock_g_with_pack_cards(pack_cards)
    
    local result = self.extractor:extract()
    local pack_contents = result.pack_contents
    
    luaunit.assertEquals(#pack_contents, 2)
    luaunit.assertEquals(pack_contents[1].card_type, "tarot")
    luaunit.assertEquals(pack_contents[1].name, "The Fool")
    luaunit.assertEquals(pack_contents[2].card_type, "tarot")
    luaunit.assertEquals(pack_contents[2].name, "The Magician")
end

-- Test planet card extraction
function TestPackExtractor:test_extract_planet_cards()
    local pack_cards = {
        create_mock_planet_card("Mercury"),
        create_mock_planet_card("Venus")
    }
    G = create_mock_g_with_pack_cards(pack_cards)
    
    local result = self.extractor:extract()
    local pack_contents = result.pack_contents
    
    luaunit.assertEquals(#pack_contents, 2)
    luaunit.assertEquals(pack_contents[1].card_type, "planet")
    luaunit.assertEquals(pack_contents[1].name, "Mercury")
    luaunit.assertEquals(pack_contents[2].card_type, "planet")
    luaunit.assertEquals(pack_contents[2].name, "Venus")
end

-- Test spectral card extraction
function TestPackExtractor:test_extract_spectral_cards()
    local pack_cards = {
        create_mock_spectral_card("Familiar"),
        create_mock_spectral_card("Grim")
    }
    G = create_mock_g_with_pack_cards(pack_cards)
    
    local result = self.extractor:extract()
    local pack_contents = result.pack_contents
    
    luaunit.assertEquals(#pack_contents, 2)
    luaunit.assertEquals(pack_contents[1].card_type, "spectral")
    luaunit.assertEquals(pack_contents[1].name, "Familiar")
    luaunit.assertEquals(pack_contents[2].card_type, "spectral")
    luaunit.assertEquals(pack_contents[2].name, "Grim")
end

-- Test mixed pack contents
function TestPackExtractor:test_extract_mixed_pack_contents()
    local pack_cards = {
        create_mock_playing_card("Hearts", "K", "KH"),
        create_mock_joker_card("Test Joker"),
        create_mock_tarot_card("The Fool"),
        create_mock_planet_card("Mercury")
    }
    G = create_mock_g_with_pack_cards(pack_cards)
    
    local result = self.extractor:extract()
    local pack_contents = result.pack_contents
    
    luaunit.assertEquals(#pack_contents, 4)
    
    -- Verify each card type
    luaunit.assertEquals(pack_contents[1].card_type, "playing")
    luaunit.assertEquals(pack_contents[2].card_type, "joker")
    luaunit.assertEquals(pack_contents[3].card_type, "tarot")
    luaunit.assertEquals(pack_contents[4].card_type, "planet")
    
    -- Verify indices are correctly assigned
    luaunit.assertEquals(pack_contents[1].index, 0)
    luaunit.assertEquals(pack_contents[2].index, 1)
    luaunit.assertEquals(pack_contents[3].index, 2)
    luaunit.assertEquals(pack_contents[4].index, 3)
end

-- Test defensive behavior with malformed cards
function TestPackExtractor:test_extract_with_malformed_cards()
    local pack_cards = {
        {}, -- Empty card
        { ability = {} }, -- Card with empty ability
        create_mock_joker_card("Valid Joker"), -- Valid card
        nil -- Nil card
    }
    G = create_mock_g_with_pack_cards(pack_cards)
    
    local result = self.extractor:extract()
    local pack_contents = result.pack_contents
    
    -- Should only extract the valid joker (index 3 in the array)
    luaunit.assertEquals(#pack_contents, 1)
    luaunit.assertEquals(pack_contents[1].card_type, "joker")
    luaunit.assertEquals(pack_contents[1].name, "Valid Joker")
end

return TestPackExtractor