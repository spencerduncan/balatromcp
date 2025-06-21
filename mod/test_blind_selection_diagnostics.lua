-- Test module for blind selection diagnostics
-- This validates our diagnostic approach and confirms our hypothesis

local function run_blind_selection_diagnostic_tests()
    print("=== BLIND SELECTION DIAGNOSTIC TESTS ===")
    
    -- Test 1: Diagnostic module loading
    local success1, BlindSelectionDiagnostics = pcall(require, 'blind_selection_diagnostics')
    local test1_result = success1 and BlindSelectionDiagnostics ~= nil
    print("Test 1 - Diagnostic module loads: " .. (test1_result and "PASS" or "FAIL"))
    
    if not test1_result then
        print("Cannot continue tests - diagnostic module failed to load")
        return
    end
    
    -- Test 2: Diagnostic object creation
    local success2, diagnostics = pcall(BlindSelectionDiagnostics.new)
    local test2_result = success2 and diagnostics ~= nil
    print("Test 2 - Diagnostic object creation: " .. (test2_result and "PASS" or "FAIL"))
    
    if not test2_result then
        print("Cannot continue tests - diagnostic object creation failed")
        return
    end
    
    -- Test 3: Log function works
    local success3 = pcall(diagnostics.log, diagnostics, "Test log message")
    print("Test 3 - Log function works: " .. (success3 and "PASS" or "FAIL"))
    
    -- Test 4: Game structure analysis (mock G object)
    local mock_G = {
        GAME = {
            config = nil,  -- This is our test case
            dollars = 100,
            round = 1
        },
        STATE = 1,
        STATES = {
            BLIND_SELECT = 1,
            PLAYING = 2
        },
        FUNCS = {
            select_blind = function() end
        }
    }
    
    -- Temporarily replace G for testing
    local original_G = _G.G
    _G.G = mock_G
    
    local success4 = pcall(diagnostics.log_complete_game_structure, diagnostics)
    print("Test 4 - Game structure analysis: " .. (success4 and "PASS" or "FAIL"))
    
    -- Test 5: Blind objects analysis
    local success5 = pcall(diagnostics.log_blind_objects_structure, diagnostics)
    print("Test 5 - Blind objects analysis: " .. (success5 and "PASS" or "FAIL"))
    
    -- Test 6: Function analysis
    local success6 = pcall(diagnostics.analyze_select_blind_function, diagnostics)
    print("Test 6 - Function analysis: " .. (success6 and "PASS" or "FAIL"))
    
    -- Test 7: Argument testing
    local success7 = pcall(diagnostics.test_blind_selection_arguments, diagnostics)
    print("Test 7 - Argument testing: " .. (success7 and "PASS" or "FAIL"))
    
    -- Test 8: Complete diagnosis
    local success8 = pcall(diagnostics.run_complete_diagnosis, diagnostics)
    print("Test 8 - Complete diagnosis: " .. (success8 and "PASS" or "FAIL"))
    
    -- Restore original G
    _G.G = original_G
    
    -- Test results summary
    local tests_passed = 0
    local tests = {test1_result, test2_result, success3, success4, success5, success6, success7, success8}
    for _, result in ipairs(tests) do
        if result then tests_passed = tests_passed + 1 end
    end
    
    print("=== DIAGNOSTIC TEST RESULTS ===")
    print("Tests passed: " .. tests_passed .. "/" .. #tests)
    
    if tests_passed == #tests then
        print("ALL TESTS PASSED - Diagnostic module is ready")
        return true
    else
        print("SOME TESTS FAILED - Diagnostic module needs fixes")
        return false
    end
end

-- Test integration with action executor
local function test_action_executor_integration()
    print("=== ACTION EXECUTOR INTEGRATION TEST ===")
    
    -- Test that action executor can load and use diagnostics
    local success1, ActionExecutor = pcall(require, 'action_executor')
    print("Test 1 - ActionExecutor loads: " .. (success1 and "PASS" or "FAIL"))
    
    if not success1 then
        return false
    end
    
    -- Mock dependencies
    local mock_state_extractor = {
        extract_current_state = function() return {} end
    }
    local mock_joker_manager = {}
    
    local success2, executor = pcall(ActionExecutor.new, mock_state_extractor, mock_joker_manager)
    print("Test 2 - ActionExecutor creation: " .. (success2 and "PASS" or "FAIL"))
    
    if not success2 then
        return false
    end
    
    -- Test that the new blind selection logic works
    local mock_action_data = {
        blind_type = "small"
    }
    
    -- Set up minimal mock environment
    local original_G = _G.G
    local original_SMODS = _G.SMODS
    
    _G.G = {
        STATE = 1,
        STATES = {BLIND_SELECT = 1},
        FUNCS = {
            select_blind = function(arg)
                -- Mock function that expects specific argument structure
                if type(arg) == "table" and arg.config then
                    return true
                else
                    error("attempt to index field 'config' (a nil value)")
                end
            end
        },
        GAME = {
            config = nil  -- This is our test case - config is nil
        }
    }
    
    -- Mock SMODS environment for runtime loading test
    _G.SMODS = {
        load_file = function(filename, id)
            if filename == 'blind_selection_diagnostics.lua' and id == 'blind_selection_diagnostics' then
                -- Return the actual diagnostics module
                local BlindSelectionDiagnostics = require('blind_selection_diagnostics')
                return function() return BlindSelectionDiagnostics end
            else
                error("No ID was provided! Usage without an ID is only available when file is first loaded.")
            end
        end
    }
    
    local success3, result = pcall(executor.execute_select_blind, executor, mock_action_data)
    print("Test 3 - New blind selection logic: " .. (success3 and "PASS" or "FAIL"))
    
    if success3 and result then
        print("Result success: " .. tostring(result.success))
        if result.error_message then
            print("Error message: " .. result.error_message)
        end
    end
    
    -- Restore original environment
    _G.G = original_G
    _G.SMODS = original_SMODS
    
    return success3
end

-- Test SMODS runtime loading specifically
local function test_smods_runtime_loading()
    print("=== SMODS RUNTIME LOADING TEST ===")
    
    local original_SMODS = _G.SMODS
    local smods_load_calls = {}
    
    -- Mock SMODS with tracking
    _G.SMODS = {
        load_file = function(filename, id)
            table.insert(smods_load_calls, {filename = filename, id = id})
            
            if filename == 'blind_selection_diagnostics.lua' then
                if id == 'blind_selection_diagnostics' then
                    -- Return the actual diagnostics module
                    local BlindSelectionDiagnostics = require('blind_selection_diagnostics')
                    return function() return BlindSelectionDiagnostics end
                else
                    error("No ID was provided! Usage without an ID is only available when file is first loaded.")
                end
            else
                error("File not found: " .. tostring(filename))
            end
        end
    }
    
    local ActionExecutor = require('action_executor')
    local mock_state_extractor = {extract_current_state = function() return {} end}
    local mock_joker_manager = {}
    local executor = ActionExecutor.new(mock_state_extractor, mock_joker_manager)
    
    -- Set up mock G environment
    local original_G = _G.G
    _G.G = {
        STATE = 1,
        STATES = {BLIND_SELECT = 1},
        FUNCS = {select_blind = function() return true end},
        GAME = {config = nil}
    }
    
    local mock_action_data = {blind_type = "small"}
    
    -- Test 1: SMODS.load_file called with correct parameters
    local success1, result1 = pcall(executor.execute_select_blind, executor, mock_action_data)
    local test1_result = success1 and #smods_load_calls == 1 and
                        smods_load_calls[1].filename == 'blind_selection_diagnostics.lua' and
                        smods_load_calls[1].id == 'blind_selection_diagnostics'
    print("Test 1 - SMODS.load_file called with ID parameter: " .. (test1_result and "PASS" or "FAIL"))
    
    -- Test 2: Error handling when ID is missing
    smods_load_calls = {}  -- Reset
    _G.SMODS.load_file = function(filename, id)
        table.insert(smods_load_calls, {filename = filename, id = id})
        if not id then
            error("No ID was provided! Usage without an ID is only available when file is first loaded.")
        end
        return function() return require('blind_selection_diagnostics') end
    end
    
    local success2, result2 = pcall(executor.execute_select_blind, executor, mock_action_data)
    local test2_result = success2  -- Should succeed because we're providing ID
    print("Test 2 - Runtime loading with ID succeeds: " .. (test2_result and "PASS" or "FAIL"))
    
    -- Test 3: Verify error when ID is missing (simulate old behavior)
    local ActionExecutorOld = require('action_executor')
    -- Mock the old execute_select_blind temporarily to test error case
    local original_execute = ActionExecutorOld.execute_select_blind
    ActionExecutorOld.execute_select_blind = function(self, action_data)
        -- Old version without ID parameter
        local BlindSelectionDiagnostics = SMODS.load_file('blind_selection_diagnostics.lua')()
        return {success = true}
    end
    
    local executor_old = ActionExecutorOld.new(mock_state_extractor, mock_joker_manager)
    local success3, result3 = pcall(executor_old.execute_select_blind, executor_old, mock_action_data)
    local test3_result = not success3 and string.find(tostring(result3), "No ID was provided")
    print("Test 3 - Old behavior fails without ID: " .. (test3_result and "PASS" or "FAIL"))
    
    -- Restore original function
    ActionExecutorOld.execute_select_blind = original_execute
    
    -- Restore original environment
    _G.G = original_G
    _G.SMODS = original_SMODS
    
    return test1_result and test2_result and test3_result
end

-- Run all tests
local function run_all_tests()
    print("Starting blind selection diagnostic validation...")
    
    local diagnostic_tests_passed = run_blind_selection_diagnostic_tests()
    print("")
    
    local integration_tests_passed = test_action_executor_integration()
    print("")
    
    local smods_runtime_tests_passed = test_smods_runtime_loading()
    print("")
    
    print("=== OVERALL TEST RESULTS ===")
    print("Diagnostic tests: " .. (diagnostic_tests_passed and "PASS" or "FAIL"))
    print("Integration tests: " .. (integration_tests_passed and "PASS" or "FAIL"))
    print("SMODS runtime loading tests: " .. (smods_runtime_tests_passed and "PASS" or "FAIL"))
    
    local all_tests_passed = diagnostic_tests_passed and integration_tests_passed and smods_runtime_tests_passed
    
    if all_tests_passed then
        print("SUCCESS: All tests passed - SMODS runtime loading fix is validated")
        print("RECOMMENDATION: Deploy this solution to resolve SMODS ID parameter error")
    else
        print("FAILURE: Some tests failed - SMODS runtime loading fix needs refinement")
    end
    
    return all_tests_passed
end

-- Execute tests
return run_all_tests()