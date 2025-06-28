-- LuaUnit tests for ActionExecutor use_pack_tarot functionality
-- Tests parameter validation, tarot card validation, and target selection

local luaunit = require('libs.luaunit')

-- =============================================================================
-- SHARED SETUP AND TEARDOWN FUNCTIONALITY
-- =============================================================================

local test_state = {}

local function setUp()
    -- Save original globals
    test_state.original_g = G
    
    -- Set up clean environment
    G = nil
end

local function tearDown()
    -- Restore original globals
    G = test_state.original_g
end

-- =============================================================================
-- USE PACK TAROT PARAMETER VALIDATION TESTS
-- =============================================================================

function testUsePackTarotMissingPackIndex()
    setUp()
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    local action_data = {
        target_card_indices = {0, 1}
        -- Missing pack_index
    }
    
    local success, error_message = executor:execute_use_pack_tarot(action_data)
    luaunit.assertEquals(false, success, "Should return false for missing pack_index")
    luaunit.assertEquals("Invalid pack index", error_message, "Should return correct error message")
    tearDown()
end

function testUsePackTarotNegativePackIndex()
    setUp()
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    local action_data = {
        pack_index = -1,
        target_card_indices = {0, 1}
    }
    
    local success, error_message = executor:execute_use_pack_tarot(action_data)
    luaunit.assertEquals(false, success, "Should return false for negative pack_index")
    luaunit.assertEquals("Invalid pack index", error_message, "Should return correct error message")
    tearDown()
end

function testUsePackTarotNoGameState()
    setUp()
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    -- G is nil (no game state)
    
    local action_data = {
        pack_index = 0,
        target_card_indices = {0, 1}
    }
    
    local success, error_message = executor:execute_use_pack_tarot(action_data)
    luaunit.assertEquals(false, success, "Should return false when no game state available")
    luaunit.assertEquals("Game state not available", error_message, "Should return correct error message")
    tearDown()
end

function testUsePackTarotNoPackCards()
    setUp()
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    -- Mock game state without pack_cards
    G = {
        STATE = 1,
        STATES = {SELECTING_HAND = 1},
        FUNCS = {
            use_card = function() end
        }
    }
    
    local action_data = {
        pack_index = 0,
        target_card_indices = {0, 1}
    }
    
    local success, error_message = executor:execute_use_pack_tarot(action_data)
    luaunit.assertEquals(false, success, "Should return false when no pack cards available")
    luaunit.assertEquals("No pack offers available", error_message, "Should return correct error message")
    tearDown()
end

function testUsePackTarotPackIndexOutOfBounds()
    setUp()
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    -- Mock game state with limited pack cards
    G = {
        STATE = 1,
        STATES = {SELECTING_HAND = 1},
        FUNCS = {
            use_card = function() end
        },
        pack_cards = {
            cards = {
                {ability = {set = "Tarot", name = "The Fool"}}
            }
        }
    }
    
    local action_data = {
        pack_index = 5, -- Out of bounds
        target_card_indices = {0, 1}
    }
    
    local success, error_message = executor:execute_use_pack_tarot(action_data)
    luaunit.assertEquals(false, success, "Should return false for out of bounds pack index")
    luaunit.assertStrContains(error_message, "Pack offer not found at index: 5", "Should return correct error message")
    tearDown()
end

-- =============================================================================
-- TAROT CARD VALIDATION TESTS
-- =============================================================================

function testUsePackTarotNotTarotCard()
    setUp()
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    -- Mock game state with non-tarot card
    G = {
        STATE = 1,
        STATES = {SELECTING_HAND = 1},
        FUNCS = {
            use_card = function() end
        },
        pack_cards = {
            cards = {
                {ability = {set = "Planet", name = "Mercury"}} -- Not a tarot card
            }
        }
    }
    
    local action_data = {
        pack_index = 0,
        target_card_indices = {0, 1}
    }
    
    local success, error_message = executor:execute_use_pack_tarot(action_data)
    luaunit.assertEquals(false, success, "Should return false for non-tarot card")
    luaunit.assertStrContains(error_message, "is not a tarot card", "Should return correct error message")
    luaunit.assertStrContains(error_message, "found: Planet", "Should specify what was found instead")
    tearDown()
end

function testUsePackTarotCardWithoutAbility()
    setUp()
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    -- Mock game state with card missing ability
    G = {
        STATE = 1,
        STATES = {SELECTING_HAND = 1},
        FUNCS = {
            use_card = function() end
        },
        pack_cards = {
            cards = {
                {} -- Card without ability
            }
        }
    }
    
    local action_data = {
        pack_index = 0,
        target_card_indices = {0, 1}
    }
    
    local success, error_message = executor:execute_use_pack_tarot(action_data)
    luaunit.assertEquals(false, success, "Should return false for card without ability")
    luaunit.assertStrContains(error_message, "is not a tarot card", "Should return correct error message")
    tearDown()
end

-- =============================================================================
-- TARGET CARD VALIDATION TESTS  
-- =============================================================================

function testUsePackTarotInvalidTargetIndex()
    setUp()
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    -- Mock game state with tarot card and limited hand
    G = {
        STATE = 1,
        STATES = {SELECTING_HAND = 1},
        FUNCS = {
            use_card = function() end
        },
        pack_cards = {
            cards = {
                {ability = {set = "Tarot", name = "The Hierophant"}}
            }
        },
        hand = {
            cards = {
                {base = {value = "Ace", suit = "Spades"}},
                {base = {value = "King", suit = "Hearts"}}
            },
            add_to_highlighted = function() end
        }
    }
    
    local action_data = {
        pack_index = 0,
        target_card_indices = {0, 5} -- Index 5 is out of bounds for 2-card hand
    }
    
    local success, error_message = executor:execute_use_pack_tarot(action_data)
    luaunit.assertEquals(false, success, "Should return false for invalid target index")
    luaunit.assertStrContains(error_message, "Invalid target card index: 5", "Should return correct error message")
    tearDown()
end

function testUsePackTarotNegativeTargetIndex()
    setUp()
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    -- Mock game state with tarot card and hand
    G = {
        STATE = 1,
        STATES = {SELECTING_HAND = 1},
        FUNCS = {
            use_card = function() end
        },
        pack_cards = {
            cards = {
                {ability = {set = "Tarot", name = "The Hierophant"}}
            }
        },
        hand = {
            cards = {
                {base = {value = "Ace", suit = "Spades"}},
                {base = {value = "King", suit = "Hearts"}}
            },
            add_to_highlighted = function() end
        }
    }
    
    local action_data = {
        pack_index = 0,
        target_card_indices = {-1, 0} -- Negative index
    }
    
    local success, error_message = executor:execute_use_pack_tarot(action_data)
    luaunit.assertEquals(false, success, "Should return false for negative target index")
    luaunit.assertStrContains(error_message, "Invalid target card index: -1", "Should return correct error message")
    tearDown()
end

function testUsePackTarotNoHandCardsForTargeting()
    setUp()
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    -- Mock game state with tarot card but no hand
    G = {
        STATE = 1,
        STATES = {SELECTING_HAND = 1},
        FUNCS = {
            use_card = function() end
        },
        pack_cards = {
            cards = {
                {ability = {set = "Tarot", name = "The Hierophant"}}
            }
        }
        -- No hand property
    }
    
    local action_data = {
        pack_index = 0,
        target_card_indices = {0, 1}
    }
    
    local success, error_message = executor:execute_use_pack_tarot(action_data)
    luaunit.assertEquals(false, success, "Should return false when no hand cards available")
    luaunit.assertEquals("No hand cards available for targeting", error_message, "Should return correct error message")
    tearDown()
end

-- =============================================================================
-- SUCCESSFUL EXECUTION TESTS
-- =============================================================================

function testUsePackTarotSuccessWithTargets()
    setUp()
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    local highlighted_cards = {}
    
    -- Mock game state with complete setup
    G = {
        STATE = 1,
        STATES = {SELECTING_HAND = 1},
        FUNCS = {
            use_card = function(params)
                return true
            end
        },
        pack_cards = {
            cards = {
                {ability = {set = "Tarot", name = "The Hierophant"}}
            }
        },
        hand = {
            cards = {
                {base = {value = "Ace", suit = "Spades"}},
                {base = {value = "King", suit = "Hearts"}},
                {base = {value = "Queen", suit = "Diamonds"}}
            },
            add_to_highlighted = function(self, card)
                table.insert(highlighted_cards, card)
            end
        }
    }
    
    local action_data = {
        pack_index = 0,
        target_card_indices = {0, 2} -- Target first and third cards
    }
    
    local success, error_message = executor:execute_use_pack_tarot(action_data)
    luaunit.assertEquals(true, success, "Should return true for successful tarot use")
    luaunit.assertEquals(nil, error_message, "Should not return error message on success")
    luaunit.assertEquals(2, #highlighted_cards, "Should highlight exactly 2 target cards")
    tearDown()
end

function testUsePackTarotSuccessWithoutTargets()
    setUp()
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    local highlighted_cards = {}
    
    -- Mock game state with complete setup
    G = {
        STATE = 1,
        STATES = {SELECTING_HAND = 1},
        FUNCS = {
            use_card = function(params)
                return true
            end
        },
        pack_cards = {
            cards = {
                {ability = {set = "Tarot", name = "The Fool"}} -- Doesn't require targets
            }
        },
        hand = {
            cards = {
                {base = {value = "Ace", suit = "Spades"}},
                {base = {value = "King", suit = "Hearts"}}
            },
            add_to_highlighted = function(self, card)
                table.insert(highlighted_cards, card)
            end
        }
    }
    
    local action_data = {
        pack_index = 0
        -- No target_card_indices provided
    }
    
    local success, error_message = executor:execute_use_pack_tarot(action_data)
    luaunit.assertEquals(true, success, "Should return true for successful tarot use without targets")
    luaunit.assertEquals(nil, error_message, "Should not return error message on success")
    luaunit.assertEquals(0, #highlighted_cards, "Should not highlight any cards when no targets provided")
    tearDown()
end

function testUsePackTarotUseFunctionError()
    setUp()
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    -- Mock game state where use_card function throws error
    G = {
        STATE = 1,
        STATES = {SELECTING_HAND = 1},
        FUNCS = {
            use_card = function(params)
                error("Simulated tarot use error")
            end
        },
        pack_cards = {
            cards = {
                {ability = {set = "Tarot", name = "The Hierophant"}}
            }
        },
        hand = {
            cards = {
                {base = {value = "Ace", suit = "Spades"}}
            },
            add_to_highlighted = function() end
        }
    }
    
    local action_data = {
        pack_index = 0,
        target_card_indices = {0}
    }
    
    local success, error_message = executor:execute_use_pack_tarot(action_data)
    luaunit.assertEquals(false, success, "Should return false when use_card function errors")
    luaunit.assertStrContains(error_message, "Pack tarot use failed:", "Should return error message with failure prefix")
    tearDown()
end

-- =============================================================================
-- EDGE CASE TESTS
-- =============================================================================

function testUsePackTarotEmptyTargetArray()
    setUp()
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    -- Mock game state with complete setup
    G = {
        STATE = 1,
        STATES = {SELECTING_HAND = 1},
        FUNCS = {
            use_card = function(params)
                return true
            end
        },
        pack_cards = {
            cards = {
                {ability = {set = "Tarot", name = "The Fool"}}
            }
        },
        hand = {
            cards = {
                {base = {value = "Ace", suit = "Spades"}}
            },
            add_to_highlighted = function() end
        }
    }
    
    local action_data = {
        pack_index = 0,
        target_card_indices = {} -- Empty array
    }
    
    local success, error_message = executor:execute_use_pack_tarot(action_data)
    luaunit.assertEquals(true, success, "Should return true with empty target array")
    luaunit.assertEquals(nil, error_message, "Should not return error message on success")
    tearDown()
end

function testUsePackTarotNoUseFunctionAvailable()
    setUp()
    local ActionExecutor = require("action_executor")
    local StateExtractor = require("state_extractor")
    local JokerManager = require("joker_manager")
    
    local state_extractor = StateExtractor.new()
    local joker_manager = JokerManager.new()
    local executor = ActionExecutor.new(state_extractor, joker_manager)
    
    -- Mock game state without use_card function
    G = {
        STATE = 1,
        STATES = {SELECTING_HAND = 1},
        FUNCS = {
            -- No use_card function
        },
        pack_cards = {
            cards = {
                {ability = {set = "Tarot", name = "The Hierophant"}}
            }
        }
    }
    
    local action_data = {
        pack_index = 0,
        target_card_indices = {0}
    }
    
    local success, error_message = executor:execute_use_pack_tarot(action_data)
    luaunit.assertEquals(false, success, "Should return false when use_card function not available")
    luaunit.assertEquals("Use card function not available", error_message, "Should return correct error message")
    tearDown()
end

return {
    testUsePackTarotMissingPackIndex = testUsePackTarotMissingPackIndex,
    testUsePackTarotNegativePackIndex = testUsePackTarotNegativePackIndex,
    testUsePackTarotNoGameState = testUsePackTarotNoGameState,
    testUsePackTarotNoPackCards = testUsePackTarotNoPackCards,
    testUsePackTarotPackIndexOutOfBounds = testUsePackTarotPackIndexOutOfBounds,
    testUsePackTarotNotTarotCard = testUsePackTarotNotTarotCard,
    testUsePackTarotCardWithoutAbility = testUsePackTarotCardWithoutAbility,
    testUsePackTarotInvalidTargetIndex = testUsePackTarotInvalidTargetIndex,
    testUsePackTarotNegativeTargetIndex = testUsePackTarotNegativeTargetIndex,
    testUsePackTarotNoHandCardsForTargeting = testUsePackTarotNoHandCardsForTargeting,
    testUsePackTarotSuccessWithTargets = testUsePackTarotSuccessWithTargets,
    testUsePackTarotSuccessWithoutTargets = testUsePackTarotSuccessWithoutTargets,
    testUsePackTarotUseFunctionError = testUsePackTarotUseFunctionError,
    testUsePackTarotEmptyTargetArray = testUsePackTarotEmptyTargetArray,
    testUsePackTarotNoUseFunctionAvailable = testUsePackTarotNoUseFunctionAvailable
}