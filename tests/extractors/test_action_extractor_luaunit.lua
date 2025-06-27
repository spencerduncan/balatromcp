-- Test file for ActionExtractor
-- Tests available actions detection functionality

local luaunit = require('libs.luaunit')
local ActionExtractor = require('state_extractor.extractors.action_extractor')

-- Test helper functions
local function create_mock_g_with_phase(phase_key)
    local mock_states = {
        SELECTING_HAND = "selecting_hand",
        SHOP = "shop", 
        BLIND_SELECT = "blind_select"
    }
    
    return {
        STATE = mock_states[phase_key] or "selecting_hand",
        STATES = mock_states,
        GAME = {
            current_round = {
                hands_left = 3,
                discards_left = 2
            }
        },
        consumeables = {
            cards = {}
        }
    }
end

local function create_mock_g_with_hands_discards(hands_left, discards_left)
    return {
        STATE = "selecting_hand",
        STATES = {
            SELECTING_HAND = "selecting_hand",
            SHOP = "shop",
            BLIND_SELECT = "blind_select"
        },
        GAME = {
            current_round = {
                hands_left = hands_left,
                discards_left = discards_left
            }
        },
        consumeables = {
            cards = {}
        }
    }
end

local function create_mock_g_with_consumables(consumable_count)
    local consumables = {}
    for i = 1, consumable_count do
        table.insert(consumables, {name = "test_consumable_" .. i})
    end
    
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
            }
        },
        consumeables = {
            cards = consumables
        }
    }
end

-- Test ActionExtractor
TestActionExtractor = {}

function TestActionExtractor:setUp()
    self.extractor = ActionExtractor.new()
    -- Store original G
    self.original_G = G
end

function TestActionExtractor:tearDown()
    -- Restore original G
    G = self.original_G
end

-- Test extractor creation and basic interface
function TestActionExtractor:test_extractor_creation()
    luaunit.assertNotNil(self.extractor)
    luaunit.assertEquals(self.extractor:get_name(), "action_extractor")
end

-- Test extract method with valid game state
function TestActionExtractor:test_extract_with_valid_state()
    G = create_mock_g_with_phase("SELECTING_HAND")
    
    local result = self.extractor:extract()
    
    luaunit.assertNotNil(result)
    luaunit.assertNotNil(result.available_actions)
    luaunit.assertTrue(type(result.available_actions) == "table")
    luaunit.assertTrue(#result.available_actions > 0)
end

-- Test extract method with invalid game state
function TestActionExtractor:test_extract_with_invalid_state()
    G = nil
    
    local result = self.extractor:extract()
    
    luaunit.assertNotNil(result)
    luaunit.assertNotNil(result.available_actions)
    luaunit.assertEquals(type(result.available_actions), "table")
end

-- Test hand selection phase actions
function TestActionExtractor:test_hand_selection_phase_actions()
    G = create_mock_g_with_phase("SELECTING_HAND")
    
    local actions = self.extractor:get_available_actions()
    
    luaunit.assertNotNil(actions)
    luaunit.assertTrue(type(actions) == "table")
    
    -- Check for expected hand selection actions
    local action_set = {}
    for _, action in ipairs(actions) do
        action_set[action] = true
    end
    
    luaunit.assertTrue(action_set["play_hand"])  -- Should be present with hands_left > 0
    luaunit.assertTrue(action_set["discard_cards"])  -- Should be present with discards_left > 0
    luaunit.assertTrue(action_set["go_to_shop"])
    luaunit.assertTrue(action_set["sort_hand_by_rank"])
    luaunit.assertTrue(action_set["sort_hand_by_suit"])
    luaunit.assertTrue(action_set["sell_joker"])
    luaunit.assertTrue(action_set["sell_consumable"])
    luaunit.assertTrue(action_set["reorder_jokers"])
    luaunit.assertTrue(action_set["move_playing_card"])
    luaunit.assertTrue(action_set["use_consumable"])
end

-- Test hand selection phase with no hands remaining
function TestActionExtractor:test_hand_selection_no_hands_remaining()
    G = create_mock_g_with_hands_discards(0, 2)
    
    local actions = self.extractor:get_available_actions()
    
    local action_set = {}
    for _, action in ipairs(actions) do
        action_set[action] = true
    end
    
    luaunit.assertFalse(action_set["play_hand"])  -- Should not be present with hands_left = 0
    luaunit.assertTrue(action_set["discard_cards"])  -- Should still be present with discards_left > 0
end

-- Test hand selection phase with no discards remaining
function TestActionExtractor:test_hand_selection_no_discards_remaining()
    G = create_mock_g_with_hands_discards(3, 0)
    
    local actions = self.extractor:get_available_actions()
    
    local action_set = {}
    for _, action in ipairs(actions) do
        action_set[action] = true
    end
    
    luaunit.assertTrue(action_set["play_hand"])  -- Should be present with hands_left > 0
    luaunit.assertFalse(action_set["discard_cards"])  -- Should not be present with discards_left = 0
end

-- Test shop phase actions
function TestActionExtractor:test_shop_phase_actions()
    G = create_mock_g_with_phase("SHOP")
    
    local actions = self.extractor:get_available_actions()
    
    luaunit.assertNotNil(actions)
    luaunit.assertTrue(type(actions) == "table")
    
    -- Check for expected shop actions
    local action_set = {}
    for _, action in ipairs(actions) do
        action_set[action] = true
    end
    
    luaunit.assertTrue(action_set["buy_item"])
    luaunit.assertTrue(action_set["sell_joker"])
    luaunit.assertTrue(action_set["sell_consumable"])
    luaunit.assertTrue(action_set["reroll_shop"])
    luaunit.assertTrue(action_set["reorder_jokers"])
    luaunit.assertTrue(action_set["use_consumable"])
    luaunit.assertTrue(action_set["go_next"])
    
    -- Should not have hand selection specific actions
    luaunit.assertFalse(action_set["play_hand"])
    luaunit.assertFalse(action_set["discard_cards"])
    luaunit.assertFalse(action_set["sort_hand_by_rank"])
end

-- Test blind selection phase actions
function TestActionExtractor:test_blind_selection_phase_actions()
    G = create_mock_g_with_phase("BLIND_SELECT")
    
    local actions = self.extractor:get_available_actions()
    
    luaunit.assertNotNil(actions)
    luaunit.assertTrue(type(actions) == "table")
    
    -- Check for expected blind selection actions
    local action_set = {}
    for _, action in ipairs(actions) do
        action_set[action] = true
    end
    
    luaunit.assertTrue(action_set["select_blind"])
    luaunit.assertTrue(action_set["reroll_boss"])
    luaunit.assertTrue(action_set["skip_blind"])
    
    -- Should not have hand selection or shop specific actions
    luaunit.assertFalse(action_set["play_hand"])
    luaunit.assertFalse(action_set["buy_item"])
    luaunit.assertFalse(action_set["go_to_shop"])
end

-- Test unknown phase defaults to hand selection
function TestActionExtractor:test_unknown_phase_defaults_to_hand_selection()
    G = {
        STATE = "unknown_phase",
        STATES = {
            SELECTING_HAND = "selecting_hand",
            SHOP = "shop",
            BLIND_SELECT = "blind_select"
        },
        GAME = {
            current_round = {
                hands_left = 3,
                discards_left = 2
            }
        },
        consumeables = {
            cards = {}
        }
    }
    
    local actions = self.extractor:get_available_actions()
    
    local action_set = {}
    for _, action in ipairs(actions) do
        action_set[action] = true
    end
    
    -- Should have hand selection actions as default
    luaunit.assertTrue(action_set["play_hand"])
    luaunit.assertTrue(action_set["go_to_shop"])
    luaunit.assertTrue(action_set["sort_hand_by_rank"])
end

-- Test has_consumables with no consumables
function TestActionExtractor:test_has_consumables_empty()
    G = create_mock_g_with_consumables(0)
    
    local result = self.extractor:has_consumables()
    
    luaunit.assertFalse(result)
end

-- Test has_consumables with consumables present
function TestActionExtractor:test_has_consumables_present()
    G = create_mock_g_with_consumables(2)
    
    local result = self.extractor:has_consumables()
    
    luaunit.assertTrue(result)
end

-- Test has_consumables with invalid G state
function TestActionExtractor:test_has_consumables_invalid_state()
    G = {}
    
    local result = self.extractor:has_consumables()
    
    luaunit.assertFalse(result)
end

-- Test has_consumables with nil G
function TestActionExtractor:test_has_consumables_nil_g()
    G = nil
    
    local result = self.extractor:has_consumables()
    
    luaunit.assertFalse(result)
end

-- Test is_joker_reorder_available (currently returns false)
function TestActionExtractor:test_is_joker_reorder_available()
    G = create_mock_g_with_phase("SELECTING_HAND")
    
    local result = self.extractor:is_joker_reorder_available()
    
    luaunit.assertFalse(result)  -- Currently a placeholder that returns false
end

-- Test actions include consumable usage when consumables are present
function TestActionExtractor:test_actions_include_consumable_usage()
    G = create_mock_g_with_consumables(1)
    
    local actions = self.extractor:get_available_actions()
    
    local action_set = {}
    for _, action in ipairs(actions) do
        action_set[action] = true
    end
    
    luaunit.assertTrue(action_set["use_consumable"])
end

-- Test actions behavior with missing game state components
function TestActionExtractor:test_actions_with_missing_game_state()
    G = {
        STATE = "selecting_hand",
        STATES = {
            SELECTING_HAND = "selecting_hand"
        }
        -- Missing GAME.current_round
    }
    
    local actions = self.extractor:get_available_actions()
    
    luaunit.assertNotNil(actions)
    luaunit.assertTrue(type(actions) == "table")
    
    local action_set = {}
    for _, action in ipairs(actions) do
        action_set[action] = true
    end
    
    -- Should not have play_hand or discard_cards without proper game state
    luaunit.assertFalse(action_set["play_hand"])
    luaunit.assertFalse(action_set["discard_cards"])
    
    -- Should still have basic actions
    luaunit.assertTrue(action_set["go_to_shop"])
    luaunit.assertTrue(action_set["sort_hand_by_rank"])
end

-- Test actions behavior with invalid hands_left type
function TestActionExtractor:test_actions_with_invalid_hands_left()
    G = {
        STATE = "selecting_hand",
        STATES = {
            SELECTING_HAND = "selecting_hand"
        },
        GAME = {
            current_round = {
                hands_left = "invalid",  -- Not a number
                discards_left = 2
            }
        },
        consumeables = {
            cards = {}
        }
    }
    
    local actions = self.extractor:get_available_actions()
    
    local action_set = {}
    for _, action in ipairs(actions) do
        action_set[action] = true
    end
    
    -- Should not have play_hand with invalid hands_left
    luaunit.assertFalse(action_set["play_hand"])
    luaunit.assertTrue(action_set["discard_cards"])  -- Should still work with valid discards_left
end

-- Test actions behavior with invalid discards_left type
function TestActionExtractor:test_actions_with_invalid_discards_left()
    G = {
        STATE = "selecting_hand",
        STATES = {
            SELECTING_HAND = "selecting_hand"
        },
        GAME = {
            current_round = {
                hands_left = 3,
                discards_left = "invalid"  -- Not a number
            }
        },
        consumeables = {
            cards = {}
        }
    }
    
    local actions = self.extractor:get_available_actions()
    
    local action_set = {}
    for _, action in ipairs(actions) do
        action_set[action] = true
    end
    
    luaunit.assertTrue(action_set["play_hand"])  -- Should still work with valid hands_left
    -- Should not have discard_cards with invalid discards_left
    luaunit.assertFalse(action_set["discard_cards"])
end

return TestActionExtractor