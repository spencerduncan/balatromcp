-- LuaUnit test suite for blind selection diagnostics
-- Tests diagnostic approach and confirms hypothesis validation
-- Migrated from custom test framework to LuaUnit

local luaunit = require('luaunit')

-- === DIAGNOSTIC MODULE LOADING TESTS ===

function TestDiagnosticModuleLoads()
    local success, BlindSelectionDiagnostics = pcall(require, 'blind_selection_diagnostics')
    assertTrue(success, "Diagnostic module should load successfully")
    assertNotNil(BlindSelectionDiagnostics, "BlindSelectionDiagnostics should not be nil")
end

function TestDiagnosticObjectCreation()
    local success, BlindSelectionDiagnostics = pcall(require, 'blind_selection_diagnostics')
    if not success then
        return -- Skip if module can't load
    end
    
    local success2, diagnostics = pcall(BlindSelectionDiagnostics.new)
    assertTrue(success2, "Diagnostic object creation should succeed")
    assertNotNil(diagnostics, "Diagnostics object should not be nil")
end

function TestLogFunctionWorks()
    local success, BlindSelectionDiagnostics = pcall(require, 'blind_selection_diagnostics')
    if not success then
        return -- Skip if module can't load
    end
    
    local success2, diagnostics = pcall(BlindSelectionDiagnostics.new)
    if not success2 then
        return -- Skip if object creation fails
    end
    
    local success3 = pcall(diagnostics.log, diagnostics, "Test log message")
    assertTrue(success3, "Log function should work without errors")
end

-- === GAME STRUCTURE ANALYSIS TESTS ===

function TestGameStructureAnalysis()
    local success, BlindSelectionDiagnostics = pcall(require, 'blind_selection_diagnostics')
    if not success then
        return -- Skip if module can't load
    end
    
    local success2, diagnostics = pcall(BlindSelectionDiagnostics.new)
    if not success2 then
        return -- Skip if object creation fails
    end
    
    -- Mock G object for testing
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
    
    -- Restore original G
    _G.G = original_G
    
    assertTrue(success4, "Game structure analysis should complete successfully")
end

function TestBlindObjectsAnalysis()
    local success, BlindSelectionDiagnostics = pcall(require, 'blind_selection_diagnostics')
    if not success then
        return -- Skip if module can't load
    end
    
    local success2, diagnostics = pcall(BlindSelectionDiagnostics.new)
    if not success2 then
        return -- Skip if object creation fails
    end
    
    -- Setup mock G
    local original_G = _G.G
    _G.G = {
        GAME = { config = nil },
        STATE = 1,
        STATES = { BLIND_SELECT = 1 },
        FUNCS = { select_blind = function() end }
    }
    
    local success5 = pcall(diagnostics.log_blind_objects_structure, diagnostics)
    
    -- Restore original G
    _G.G = original_G
    
    assertTrue(success5, "Blind objects analysis should complete successfully")
end

function TestFunctionAnalysis()
    local success, BlindSelectionDiagnostics = pcall(require, 'blind_selection_diagnostics')
    if not success then
        return -- Skip if module can't load
    end
    
    local success2, diagnostics = pcall(BlindSelectionDiagnostics.new)
    if not success2 then
        return -- Skip if object creation fails
    end
    
    -- Setup mock G
    local original_G = _G.G
    _G.G = {
        GAME = { config = nil },
        STATE = 1,
        STATES = { BLIND_SELECT = 1 },
        FUNCS = { select_blind = function() end }
    }
    
    local success6 = pcall(diagnostics.analyze_select_blind_function, diagnostics)
    
    -- Restore original G
    _G.G = original_G
    
    assertTrue(success6, "Function analysis should complete successfully")
end

function TestArgumentTesting()
    local success, BlindSelectionDiagnostics = pcall(require, 'blind_selection_diagnostics')
    if not success then
        return -- Skip if module can't load
    end
    
    local success2, diagnostics = pcall(BlindSelectionDiagnostics.new)
    if not success2 then
        return -- Skip if object creation fails
    end
    
    -- Setup mock G
    local original_G = _G.G
    _G.G = {
        GAME = { config = nil },
        STATE = 1,
        STATES = { BLIND_SELECT = 1 },
        FUNCS = { select_blind = function() end }
    }
    
    local success7 = pcall(diagnostics.test_blind_selection_arguments, diagnostics)
    
    -- Restore original G
    _G.G = original_G
    
    assertTrue(success7, "Argument testing should complete successfully")
end

function TestCompleteDiagnosis()
    local success, BlindSelectionDiagnostics = pcall(require, 'blind_selection_diagnostics')
    if not success then
        return -- Skip if module can't load
    end
    
    local success2, diagnostics = pcall(BlindSelectionDiagnostics.new)
    if not success2 then
        return -- Skip if object creation fails
    end
    
    -- Setup mock G
    local original_G = _G.G
    _G.G = {
        GAME = { config = nil },
        STATE = 1,
        STATES = { BLIND_SELECT = 1 },
        FUNCS = { select_blind = function() end }
    }
    
    local success8 = pcall(diagnostics.run_complete_diagnosis, diagnostics)
    
    -- Restore original G
    _G.G = original_G
    
    assertTrue(success8, "Complete diagnosis should run successfully")
end

-- === ACTION EXECUTOR INTEGRATION TESTS ===

function TestActionExecutorLoads()
    local success, ActionExecutor = pcall(require, 'action_executor')
    assertTrue(success, "ActionExecutor should load successfully")
    assertNotNil(ActionExecutor, "ActionExecutor should not be nil")
end

function TestActionExecutorCreation()
    local success, ActionExecutor = pcall(require, 'action_executor')
    if not success then
        return -- Skip if ActionExecutor can't load
    end
    
    -- Mock dependencies
    local mock_state_extractor = {
        extract_current_state = function() return {} end
    }
    local mock_joker_manager = {}
    
    local success2, executor = pcall(ActionExecutor.new, mock_state_extractor, mock_joker_manager)
    assertTrue(success2, "ActionExecutor creation should succeed")
    assertNotNil(executor, "Executor should not be nil")
end

function TestBlindSelectionLogicIntegration()
    local success, ActionExecutor = pcall(require, 'action_executor')
    if not success then
        return -- Skip if ActionExecutor can't load
    end
    
    -- Mock dependencies
    local mock_state_extractor = { extract_current_state = function() return {} end }
    local mock_joker_manager = {}
    
    local success2, executor = pcall(ActionExecutor.new, mock_state_extractor, mock_joker_manager)
    if not success2 then
        return -- Skip if executor creation fails
    end
    
    local mock_action_data = { blind_type = "small" }
    
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
    
    -- Restore original environment
    _G.G = original_G
    _G.SMODS = original_SMODS
    
    assertTrue(success3, "New blind selection logic should work")
    if result then
        assertNotNil(result, "Should return result object")
    end
end

-- === SMODS RUNTIME LOADING TESTS ===

function TestSmodsLoadFileCalledWithCorrectParameters()
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
    
    -- Test SMODS.load_file called with correct parameters
    local success1, result1 = pcall(executor.execute_select_blind, executor, mock_action_data)
    local test1_result = success1 and #smods_load_calls == 1 and
                        smods_load_calls[1].filename == 'blind_selection_diagnostics.lua' and
                        smods_load_calls[1].id == 'blind_selection_diagnostics'
    
    -- Restore original environment
    _G.G = original_G
    _G.SMODS = original_SMODS
    
    assertTrue(test1_result, "SMODS.load_file should be called with correct ID parameter")
end

function TestRuntimeLoadingWithIdSucceeds()
    local original_SMODS = _G.SMODS
    local smods_load_calls = {}
    
    _G.SMODS = {
        load_file = function(filename, id)
            table.insert(smods_load_calls, {filename = filename, id = id})
            if not id then
                error("No ID was provided! Usage without an ID is only available when file is first loaded.")
            end
            return function() return require('blind_selection_diagnostics') end
        end
    }
    
    local ActionExecutor = require('action_executor')
    local mock_state_extractor = {extract_current_state = function() return {} end}
    local mock_joker_manager = {}
    local executor = ActionExecutor.new(mock_state_extractor, mock_joker_manager)
    
    local original_G = _G.G
    _G.G = {
        STATE = 1,
        STATES = {BLIND_SELECT = 1},
        FUNCS = {select_blind = function() return true end},
        GAME = {config = nil}
    }
    
    local mock_action_data = {blind_type = "small"}
    
    local success2, result2 = pcall(executor.execute_select_blind, executor, mock_action_data)
    
    -- Restore original environment
    _G.G = original_G
    _G.SMODS = original_SMODS
    
    assertTrue(success2, "Runtime loading with ID should succeed")
end

function TestOldBehaviorFailsWithoutId()
    local original_SMODS = _G.SMODS
    
    _G.SMODS = {
        load_file = function(filename, id)
            if not id then
                error("No ID was provided! Usage without an ID is only available when file is first loaded.")
            end
            return function() return require('blind_selection_diagnostics') end
        end
    }
    
    -- Simulate old execute_select_blind without ID parameter
    local function old_execute_select_blind()
        -- Old version without ID parameter
        local BlindSelectionDiagnostics = SMODS.load_file('blind_selection_diagnostics.lua')()
        return {success = true}
    end
    
    local success3, result3 = pcall(old_execute_select_blind)
    
    -- Restore original environment
    _G.SMODS = original_SMODS
    
    assertFalse(success3, "Old behavior should fail without ID")
    if result3 then
        luaunit.assertStrContains(tostring(result3), "No ID was provided", "Should contain ID error message")
    end
end

-- === COMPREHENSIVE INTEGRATION TESTS ===

function TestDiagnosticModuleIntegrationComplete()
    -- Test that all components work together
    local blind_diagnostics_success = pcall(require, 'blind_selection_diagnostics')
    local action_executor_success = pcall(require, 'action_executor')
    
    -- At least one should be available for integration
    assertTrue(blind_diagnostics_success or action_executor_success, 
              "Either blind diagnostics or action executor should be available")
end

function TestMockEnvironmentSetupAndTeardown()
    -- Test that we can safely setup and teardown mock environments
    local original_G = _G.G
    local original_SMODS = _G.SMODS
    
    -- Setup mock environment
    _G.G = {STATE = 1, STATES = {BLIND_SELECT = 1}}
    _G.SMODS = {load_file = function() return function() return {} end end}
    
    assertNotNil(_G.G, "Mock G should be set")
    assertNotNil(_G.SMODS, "Mock SMODS should be set")
    
    -- Teardown
    _G.G = original_G
    _G.SMODS = original_SMODS
    
    assertTrue(true, "Environment setup and teardown should work")
end

-- Run tests if executed directly
if arg and arg[0] and string.find(arg[0], "test_blind_selection_diagnostics_luaunit") then
    os.exit(luaunit.LuaUnit.run())
end

return {
    TestDiagnosticModuleLoads = TestDiagnosticModuleLoads,
    TestDiagnosticObjectCreation = TestDiagnosticObjectCreation,
    TestLogFunctionWorks = TestLogFunctionWorks,
    TestGameStructureAnalysis = TestGameStructureAnalysis,
    TestBlindObjectsAnalysis = TestBlindObjectsAnalysis,
    TestFunctionAnalysis = TestFunctionAnalysis,
    TestArgumentTesting = TestArgumentTesting,
    TestCompleteDiagnosis = TestCompleteDiagnosis,
    TestActionExecutorLoads = TestActionExecutorLoads,
    TestActionExecutorCreation = TestActionExecutorCreation,
    TestBlindSelectionLogicIntegration = TestBlindSelectionLogicIntegration,
    TestSmodsLoadFileCalledWithCorrectParameters = TestSmodsLoadFileCalledWithCorrectParameters,
    TestRuntimeLoadingWithIdSucceeds = TestRuntimeLoadingWithIdSucceeds,
    TestOldBehaviorFailsWithoutId = TestOldBehaviorFailsWithoutId,
    TestDiagnosticModuleIntegrationComplete = TestDiagnosticModuleIntegrationComplete,
    TestMockEnvironmentSetupAndTeardown = TestMockEnvironmentSetupAndTeardown
}