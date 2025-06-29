-- Comprehensive test coverage for Action Validation System
-- Tests framework, validators, tracking, and integration scenarios

local luaunit = require('libs.luaunit')
local luaunit_helpers = require('tests.luaunit_helpers')

-- Load validation components for testing
local function load_validation_components()
    local ValidationResult = assert(SMODS.load_file("action_executor/validators/validation_result.lua"))()
    local ActionValidator = assert(SMODS.load_file("action_executor/validators/action_validator.lua"))()
    local BlindValidator = assert(SMODS.load_file("action_executor/validators/blind_validator.lua"))()
    local RerollValidator = assert(SMODS.load_file("action_executor/validators/reroll_validator.lua"))()
    local RerollTracker = assert(SMODS.load_file("action_executor/utils/reroll_tracker.lua"))()
    
    return {
        ValidationResult = ValidationResult,
        ActionValidator = ActionValidator,
        BlindValidator = BlindValidator,
        RerollValidator = RerollValidator,
        RerollTracker = RerollTracker
    }
end

-- Test ValidationResult functionality
TestValidationResult = {}

function TestValidationResult:setUp()
    luaunit_helpers.setup_mock_smods()
    self.components = load_validation_components()
end

function TestValidationResult:tearDown()
    luaunit_helpers.cleanup_mock_smods()
end

function TestValidationResult:test_success_result()
    local result = self.components.ValidationResult.success("Test passed")
    
    luaunit.assertTrue(result:is_success())
    luaunit.assertFalse(result:is_failure())
    luaunit.assertTrue(result.is_valid)
    luaunit.assertEquals(result.success_message, "Test passed")
    luaunit.assertNil(result.error_message)
end

function TestValidationResult:test_error_result()
    local result = self.components.ValidationResult.error("Test failed")
    
    luaunit.assertFalse(result:is_success())
    luaunit.assertTrue(result:is_failure())
    luaunit.assertFalse(result.is_valid)
    luaunit.assertEquals(result.error_message, "Test failed")
    luaunit.assertNil(result.success_message)
end

function TestValidationResult:test_get_message()
    local success_result = self.components.ValidationResult.success("Success message")
    local error_result = self.components.ValidationResult.error("Error message")
    
    luaunit.assertEquals(success_result:get_message(), "Success message")
    luaunit.assertEquals(error_result:get_message(), "Error message")
end

-- Test RerollTracker functionality
TestRerollTracker = {}

function TestRerollTracker:setUp()
    luaunit_helpers.setup_mock_smods()
    self.components = load_validation_components()
    self.tracker = self.components.RerollTracker.new()
    
    -- Setup mock game state
    _G.G = {
        GAME = {}
    }
end

function TestRerollTracker:tearDown()
    luaunit_helpers.cleanup_mock_smods()
    _G.G = nil
end

function TestRerollTracker:test_ante_based_tracking()
    -- Use reroll in ante 1
    local success, msg = self.tracker:increment_reroll_usage(1)
    luaunit.assertTrue(success)
    luaunit.assertEquals(self.tracker:get_reroll_count(1), 1)
    
    -- Move to ante 2 - should start fresh
    luaunit.assertEquals(self.tracker:get_reroll_count(2), 0)
    
    -- Use reroll in ante 2
    self.tracker:increment_reroll_usage(2)
    luaunit.assertEquals(self.tracker:get_reroll_count(2), 1)
    
    -- Ante 1 count should be preserved
    luaunit.assertEquals(self.tracker:get_reroll_count(1), 1)
end

function TestRerollTracker:test_multiple_rerolls_same_ante()
    -- Use multiple rerolls in same ante
    self.tracker:increment_reroll_usage(3)
    self.tracker:increment_reroll_usage(3)
    self.tracker:increment_reroll_usage(3)
    
    luaunit.assertEquals(self.tracker:get_reroll_count(3), 3)
end

function TestRerollTracker:test_limit_checking()
    -- Test limit checking for Director's Cut
    luaunit.assertFalse(self.tracker:is_reroll_limit_reached(5, 1))
    
    self.tracker:increment_reroll_usage(5)
    luaunit.assertTrue(self.tracker:is_reroll_limit_reached(5, 1))
end

function TestRerollTracker:test_invalid_ante_handling()
    local success, msg = self.tracker:increment_reroll_usage(-1)
    luaunit.assertFalse(success)
    luaunit.assertStrContains(msg, "Invalid ante number")
    
    luaunit.assertEquals(self.tracker:get_reroll_count(-1), 0)
    luaunit.assertEquals(self.tracker:get_reroll_count(nil), 0)
end

-- Test BlindValidator functionality
TestBlindValidator = {}

function TestBlindValidator:setUp()
    luaunit_helpers.setup_mock_smods()
    self.components = load_validation_components()
    self.validator = self.components.BlindValidator.new()
end

function TestBlindValidator:tearDown()
    luaunit_helpers.cleanup_mock_smods()
end

function TestBlindValidator:test_blind_progression_enforcement()
    local game_state = {
        blind_on_deck = "big",
        blind_select_opts = {
            big = {},
            small = {},
            boss = {}
        }
    }
    
    local action_data = {blind_type = "small"} -- Agent tries wrong blind
    
    local result = self.validator:validate(action_data, game_state)
    
    luaunit.assertTrue(result.is_valid)
    luaunit.assertEquals(action_data.blind_type, "big") -- Overridden to correct blind
end

function TestBlindValidator:test_missing_blind_on_deck()
    local game_state = {
        blind_on_deck = nil,
        blind_select_opts = {}
    }
    
    local action_data = {blind_type = "small"}
    
    local result = self.validator:validate(action_data, game_state)
    
    luaunit.assertFalse(result.is_valid)
    luaunit.assertStrContains(result.error_message, "No blind progression available")
end

function TestBlindValidator:test_blind_not_available()
    local game_state = {
        blind_on_deck = "boss",
        blind_select_opts = {
            small = {},
            big = {}
            -- boss not available
        }
    }
    
    local action_data = {blind_type = "small"}
    
    local result = self.validator:validate(action_data, game_state)
    
    luaunit.assertFalse(result.is_valid)
    luaunit.assertStrContains(result.error_message, "not available")
    luaunit.assertStrContains(result.error_message, "boss")
end

-- Test RerollValidator functionality
TestRerollValidator = {}

function TestRerollValidator:setUp()
    luaunit_helpers.setup_mock_smods()
    self.components = load_validation_components()
    self.validator = self.components.RerollValidator.new()
    
    -- Setup mock game state
    _G.G = {
        GAME = {}
    }
end

function TestRerollValidator:tearDown()
    luaunit_helpers.cleanup_mock_smods()
    _G.G = nil
end

function TestRerollValidator:test_directors_cut_validation()
    local game_state = {
        current_ante = 1,
        dollars = 20,
        bankrupt_at = 0,
        owned_vouchers = {
            {name = "Director's Cut", active = true}
        }
    }
    
    local action_data = {}
    
    -- First reroll should pass
    local result = self.validator:validate(action_data, game_state)
    luaunit.assertTrue(result.is_valid)
    
    -- Simulate reroll usage
    self.validator:get_reroll_tracker():increment_reroll_usage(1)
    
    -- Second reroll should fail
    local result2 = self.validator:validate(action_data, game_state)
    luaunit.assertFalse(result2.is_valid)
    luaunit.assertStrContains(result2.error_message, "only 1 boss reroll per ante")
end

function TestRerollValidator:test_retcon_unlimited_rerolls()
    local game_state = {
        current_ante = 2,
        dollars = 50,
        bankrupt_at = 0,
        owned_vouchers = {
            {name = "Retcon", active = true}
        }
    }
    
    local action_data = {}
    
    -- Multiple rerolls should all pass with Retcon
    for i = 1, 5 do
        local result = self.validator:validate(action_data, game_state)
        luaunit.assertTrue(result.is_valid)
        self.validator:get_reroll_tracker():increment_reroll_usage(2)
    end
end

function TestRerollValidator:test_no_voucher_required()
    local game_state = {
        current_ante = 1,
        dollars = 20,
        bankrupt_at = 0,
        owned_vouchers = {}
    }
    
    local action_data = {}
    
    local result = self.validator:validate(action_data, game_state)
    luaunit.assertFalse(result.is_valid)
    luaunit.assertStrContains(result.error_message, "requires 'Director's Cut' or 'Retcon' voucher")
end

function TestRerollValidator:test_insufficient_funds()
    local game_state = {
        current_ante = 1,
        dollars = 5, -- Less than $10 required
        bankrupt_at = 0,
        owned_vouchers = {
            {name = "Director's Cut", active = true}
        }
    }
    
    local action_data = {}
    
    local result = self.validator:validate(action_data, game_state)
    luaunit.assertFalse(result.is_valid)
    luaunit.assertStrContains(result.error_message, "Insufficient funds")
end

-- Test ActionValidator framework
TestActionValidator = {}

function TestActionValidator:setUp()
    luaunit_helpers.setup_mock_smods()
    self.components = load_validation_components()
    self.validator = self.components.ActionValidator.new()
    
    -- Setup mock game state
    _G.G = {
        GAME = {
            blind_on_deck = "big",
            round_resets = {ante = 1},
            dollars = 20
        },
        blind_select_opts = {
            big = {},
            small = {}
        }
    }
end

function TestActionValidator:tearDown()
    luaunit_helpers.cleanup_mock_smods()
    _G.G = nil
end

function TestActionValidator:test_validator_registration()
    local blind_validator = self.components.BlindValidator.new()
    local success, msg = self.validator:register_validator(blind_validator)
    
    luaunit.assertTrue(success)
    luaunit.assertEquals(self.validator:get_validator_count(), 1)
    
    local validators = self.validator:get_validators_for_action("select_blind")
    luaunit.assertEquals(#validators, 1)
end

function TestActionValidator:test_validation_integration()
    -- Register validators
    local blind_validator = self.components.BlindValidator.new()
    local reroll_validator = self.components.RerollValidator.new()
    
    self.validator:register_validator(blind_validator)
    self.validator:register_validator(reroll_validator)
    self.validator:initialize()
    
    -- Test blind validation
    local action_data = {blind_type = "small"}
    local game_state = self.validator:get_current_game_state()
    
    local result = self.validator:validate_action("select_blind", action_data, game_state)
    luaunit.assertTrue(result.is_valid)
    luaunit.assertEquals(action_data.blind_type, "big") -- Should be overridden
end

function TestActionValidator:test_no_validators_registered()
    local action_data = {some_param = "value"}
    local game_state = {}
    
    local result = self.validator:validate_action("unknown_action", action_data, game_state)
    luaunit.assertTrue(result.is_valid) -- Should allow actions with no validators
end

-- Test integration with ActionExecutor (mock test)
TestActionExecutorIntegration = {}

function TestActionExecutorIntegration:setUp()
    luaunit_helpers.setup_mock_smods()
    self.components = load_validation_components()
    
    -- Setup complete mock game state
    _G.G = {
        GAME = {
            blind_on_deck = "boss",
            round_resets = {ante = 3},
            dollars = 50,
            bankrupt_at = 0
        },
        blind_select_opts = {
            boss = {
                config = {
                    blind = {name = "Boss Blind"}
                }
            }
        },
        FUNCS = {
            select_blind = function() end,
            reroll_boss = function() end
        }
    }
end

function TestActionExecutorIntegration:tearDown()
    luaunit_helpers.cleanup_mock_smods()
    _G.G = nil
end

function TestActionExecutorIntegration:test_blind_selection_override_simulation()
    -- Simulate what should happen in ActionExecutor
    local validator = self.components.ActionValidator.new()
    local blind_validator = self.components.BlindValidator.new()
    validator:register_validator(blind_validator)
    validator:initialize()
    
    local action_data = {
        action_type = "select_blind",
        blind_type = "small" -- Agent tries wrong blind
    }
    
    local game_state = validator:get_current_game_state()
    local result = validator:validate_action("select_blind", action_data, game_state)
    
    luaunit.assertTrue(result.is_valid)
    luaunit.assertEquals(action_data.blind_type, "boss") -- Should be overridden to correct progression
end

function TestActionExecutorIntegration:test_reroll_validation_simulation()
    -- Simulate reroll validation with voucher
    local validator = self.components.ActionValidator.new()
    local reroll_validator = self.components.RerollValidator.new()
    validator:register_validator(reroll_validator)
    validator:initialize()
    
    local action_data = {action_type = "reroll_boss"}
    local game_state = validator:get_current_game_state()
    
    -- Add voucher to game state
    game_state.owned_vouchers = {
        {name = "Director's Cut", active = true}
    }
    
    local result = validator:validate_action("reroll_boss", action_data, game_state)
    luaunit.assertTrue(result.is_valid)
end

-- Run all tests
function run_all_validation_tests()
    print("BalatroMCP: Running Action Validation System tests...")
    
    local runner = luaunit.LuaUnit.new()
    runner:setOutputType("text")
    
    local result = runner:runSuite(
        TestValidationResult,
        TestRerollTracker,
        TestBlindValidator,
        TestRerollValidator,
        TestActionValidator,
        TestActionExecutorIntegration
    )
    
    if result.notPassedCount == 0 then
        print("BalatroMCP: All validation tests PASSED!")
    else
        print("BalatroMCP: Some validation tests FAILED - " .. result.notPassedCount .. " failures")
    end
    
    return result.notPassedCount == 0
end

return {
    TestValidationResult = TestValidationResult,
    TestRerollTracker = TestRerollTracker,
    TestBlindValidator = TestBlindValidator,
    TestRerollValidator = TestRerollValidator,
    TestActionValidator = TestActionValidator,
    TestActionExecutorIntegration = TestActionExecutorIntegration,
    run_all_validation_tests = run_all_validation_tests
}