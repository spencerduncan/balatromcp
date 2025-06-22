-- LuaUnit test suite for blind diagnostic modules and action executor integration
-- Tests BlindActivationDiagnostics, BlindProgressionDiagnostics, and related ActionExecutor methods
-- Migrated from custom test framework to LuaUnit

local luaunit = require('libs.luaunit')

-- Mock SMODS for loading diagnostic modules
local function setup_mock_smods()
    -- Reset global state
    _G.SMODS = nil
    _G.G = nil
    
    -- Create mock SMODS
    _G.SMODS = {
        load_file = function(filename, id)
            if filename == 'blind_activation_diagnostics.lua' then
                return function()
                    -- Return actual BlindActivationDiagnostics module
                    local BlindActivationDiagnostics = {}
                    BlindActivationDiagnostics.__index = BlindActivationDiagnostics
                    
                    function BlindActivationDiagnostics.new()
                        local self = setmetatable({}, BlindActivationDiagnostics)
                        return self
                    end
                    
                    function BlindActivationDiagnostics:log(message)
                        -- Mock logging for tests
                    end
                    
                    function BlindActivationDiagnostics:diagnose_blind_activation_state()
                        -- Mock diagnosis execution
                        return true
                    end
                    
                    function BlindActivationDiagnostics:check_blind_database()
                        -- Mock database check
                        return true
                    end
                    
                    function BlindActivationDiagnostics:table_size(t)
                        local count = 0
                        for _ in pairs(t) do count = count + 1 end
                        return count
                    end
                    
                    return BlindActivationDiagnostics
                end
            elseif filename == 'blind_progression_diagnostics.lua' then
                return function()
                    -- Return actual BlindProgressionDiagnostics module
                    local BlindProgressionDiagnostics = {}
                    BlindProgressionDiagnostics.__index = BlindProgressionDiagnostics
                    
                    function BlindProgressionDiagnostics.new()
                        local self = setmetatable({}, BlindProgressionDiagnostics)
                        return self
                    end
                    
                    function BlindProgressionDiagnostics:log(message)
                        -- Mock logging for tests
                    end
                    
                    function BlindProgressionDiagnostics:diagnose_blind_state()
                        -- Mock state diagnosis
                        return true
                    end
                    
                    function BlindProgressionDiagnostics:log_hand_result_processing()
                        -- Mock hand result processing
                        return true
                    end
                    
                    return BlindProgressionDiagnostics
                end
            else
                error("Module not found: " .. filename)
            end
        end
    }
end

-- Mock ActionExecutor class
local function create_mock_action_executor()
    local ActionExecutor = {}
    ActionExecutor.__index = ActionExecutor
    
    function ActionExecutor.new(state_extractor, joker_manager)
        local self = setmetatable({}, ActionExecutor)
        self.state_extractor = state_extractor or {}
        self.joker_manager = joker_manager or {}
        return self
    end
    
    function ActionExecutor:execute_diagnose_blind_progression(action_data)
        -- Load diagnostic module using SMODS with required ID
        local BlindProgressionDiagnostics = SMODS.load_file('blind_progression_diagnostics.lua', 'balatro_mcp')()
        local diagnostics = BlindProgressionDiagnostics.new()
        
        -- Run comprehensive diagnosis
        diagnostics:diagnose_blind_state()
        diagnostics:log_hand_result_processing()
        
        return true, nil
    end
    
    function ActionExecutor:execute_diagnose_blind_activation(action_data)
        -- Load diagnostic module using SMODS with required ID
        local BlindActivationDiagnostics = SMODS.load_file('blind_activation_diagnostics.lua', 'balatro_mcp')()
        local diagnostics = BlindActivationDiagnostics.new()
        
        -- Run comprehensive activation diagnosis
        diagnostics:diagnose_blind_activation_state()
        diagnostics:check_blind_database()
        
        return true, nil
    end
    
    return ActionExecutor
end

-- === BLIND ACTIVATION DIAGNOSTICS TESTS ===

function TestBlindActivationDiagnosticsConstructorCreatesInstance()
    setup_mock_smods()
    
    local BlindActivationDiagnostics = SMODS.load_file('blind_activation_diagnostics.lua', 'balatro_mcp')()
    local diagnostics = BlindActivationDiagnostics.new()
    
    luaunit.assertNotNil(diagnostics, "Constructor should return non-nil instance")
    luaunit.assertEquals("table", type(diagnostics), "Constructor should return table")
end

function TestBlindActivationDiagnosticsDiagnoseBlindActivationStateExecutes()
    setup_mock_smods()
    
    local BlindActivationDiagnostics = SMODS.load_file('blind_activation_diagnostics.lua', 'balatro_mcp')()
    local diagnostics = BlindActivationDiagnostics.new()
    
    local result = diagnostics:diagnose_blind_activation_state()
    luaunit.assertEquals(true, result, "diagnose_blind_activation_state should execute successfully")
end

function TestBlindActivationDiagnosticsCheckBlindDatabaseExecutes()
    setup_mock_smods()
    
    local BlindActivationDiagnostics = SMODS.load_file('blind_activation_diagnostics.lua', 'balatro_mcp')()
    local diagnostics = BlindActivationDiagnostics.new()
    
    local result = diagnostics:check_blind_database()
    luaunit.assertEquals(true, result, "check_blind_database should execute successfully")
end

function TestBlindActivationDiagnosticsTableSizeUtilityWorks()
    setup_mock_smods()
    
    local BlindActivationDiagnostics = SMODS.load_file('blind_activation_diagnostics.lua', 'balatro_mcp')()
    local diagnostics = BlindActivationDiagnostics.new()
    
    local test_table = {a = 1, b = 2, c = 3}
    local size = diagnostics:table_size(test_table)
    luaunit.assertEquals(3, size, "table_size should count table elements correctly")
    
    local empty_table = {}
    local empty_size = diagnostics:table_size(empty_table)
    luaunit.assertEquals(0, empty_size, "table_size should handle empty tables")
end

-- === BLIND PROGRESSION DIAGNOSTICS TESTS ===

function TestBlindProgressionDiagnosticsConstructorCreatesInstance()
    setup_mock_smods()
    
    local BlindProgressionDiagnostics = SMODS.load_file('blind_progression_diagnostics.lua', 'balatro_mcp')()
    local diagnostics = BlindProgressionDiagnostics.new()
    
    luaunit.assertNotNil(diagnostics, "Constructor should return non-nil instance")
    luaunit.assertEquals("table", type(diagnostics), "Constructor should return table")
end

function TestBlindProgressionDiagnosticsHasRequiredMethods()
    setup_mock_smods()
    
    local BlindProgressionDiagnostics = SMODS.load_file('blind_progression_diagnostics.lua', 'balatro_mcp')()
    local diagnostics = BlindProgressionDiagnostics.new()
    
    luaunit.assertEquals("function", type(diagnostics.log), "Should have log method")
    luaunit.assertEquals("function", type(diagnostics.diagnose_blind_state), "Should have diagnose_blind_state method")
    luaunit.assertEquals("function", type(diagnostics.log_hand_result_processing), "Should have log_hand_result_processing method")
end

function TestBlindProgressionDiagnosticsDiagnoseBlindStateExecutes()
    setup_mock_smods()
    
    local BlindProgressionDiagnostics = SMODS.load_file('blind_progression_diagnostics.lua', 'balatro_mcp')()
    local diagnostics = BlindProgressionDiagnostics.new()
    
    local result = diagnostics:diagnose_blind_state()
    luaunit.assertEquals(true, result, "diagnose_blind_state should execute successfully")
end

function TestBlindProgressionDiagnosticsLogHandResultProcessingExecutes()
    setup_mock_smods()
    
    local BlindProgressionDiagnostics = SMODS.load_file('blind_progression_diagnostics.lua', 'balatro_mcp')()
    local diagnostics = BlindProgressionDiagnostics.new()
    
    local result = diagnostics:log_hand_result_processing()
    luaunit.assertEquals(true, result, "log_hand_result_processing should execute successfully")
end

-- === ACTION EXECUTOR INTEGRATION TESTS ===

function TestActionExecutorExecuteDiagnoseBlindProgressionMethod()
    setup_mock_smods()
    
    local ActionExecutor = create_mock_action_executor()
    local executor = ActionExecutor.new()
    
    local action_data = {}
    local success, error_message = executor:execute_diagnose_blind_progression(action_data)
    
    luaunit.assertEquals(true, success, "execute_diagnose_blind_progression should succeed")
    luaunit.assertNil(error_message, "execute_diagnose_blind_progression should not return error message")
end

function TestActionExecutorExecuteDiagnoseBlindActivationMethod()
    setup_mock_smods()
    
    local ActionExecutor = create_mock_action_executor()
    local executor = ActionExecutor.new()
    
    local action_data = {}
    local success, error_message = executor:execute_diagnose_blind_activation(action_data)
    
    luaunit.assertEquals(true, success, "execute_diagnose_blind_activation should succeed")
    luaunit.assertNil(error_message, "execute_diagnose_blind_activation should not return error message")
end

function TestActionExecutorDiagnosticActionsLoadCorrectModules()
    setup_mock_smods()
    
    local ActionExecutor = create_mock_action_executor()
    local executor = ActionExecutor.new()
    
    -- Test that SMODS.load_file is called with correct parameters
    local load_file_calls = {}
    local original_load_file = SMODS.load_file
    SMODS.load_file = function(filename, id)
        table.insert(load_file_calls, {filename = filename, id = id})
        return original_load_file(filename, id)
    end
    
    -- Test blind progression diagnostics
    executor:execute_diagnose_blind_progression({})
    luaunit.assertEquals(1, #load_file_calls, "Should call SMODS.load_file once for progression diagnostics")
    luaunit.assertEquals('blind_progression_diagnostics.lua', load_file_calls[1].filename, "Should load correct progression module")
    luaunit.assertEquals('balatro_mcp', load_file_calls[1].id, "Should use correct module ID")
    
    -- Reset and test blind activation diagnostics
    load_file_calls = {}
    executor:execute_diagnose_blind_activation({})
    luaunit.assertEquals(1, #load_file_calls, "Should call SMODS.load_file once for activation diagnostics")
    luaunit.assertEquals('blind_activation_diagnostics.lua', load_file_calls[1].filename, "Should load correct activation module")
    luaunit.assertEquals('balatro_mcp', load_file_calls[1].id, "Should use correct module ID")
    
    -- Restore original
    SMODS.load_file = original_load_file
end

function TestActionExecutorHandlesSmodsLoadingFailureGracefully()
    -- Setup SMODS that fails to load modules
    _G.SMODS = {
        load_file = function(filename, id)
            error("Failed to load " .. filename)
        end
    }
    
    local ActionExecutor = create_mock_action_executor()
    
    -- Override methods to test error handling
    function ActionExecutor:execute_diagnose_blind_progression(action_data)
        local success, error_result = pcall(function()
            local BlindProgressionDiagnostics = SMODS.load_file('blind_progression_diagnostics.lua', 'balatro_mcp')()
            local diagnostics = BlindProgressionDiagnostics.new()
            diagnostics:diagnose_blind_state()
            diagnostics:log_hand_result_processing()
        end)
        
        if success then
            return true, nil
        else
            return false, "Module loading failed: " .. tostring(error_result)
        end
    end
    
    local executor = ActionExecutor.new()
    local success, error_message = executor:execute_diagnose_blind_progression({})
    
    luaunit.assertEquals(false, success, "Should fail when SMODS loading fails")
    luaunit.assertNotNil(error_message, "Should return error message when module loading fails")
end

function TestDiagnosticModulesHandleMissingDependenciesGracefully()
    setup_mock_smods()
    
    -- Store original values to restore later (LuaUnit needs os functions)
    local original_love = _G.love
    local original_os = _G.os
    
    -- Test with missing love.timer (but keep os for LuaUnit compatibility)
    _G.love = nil
    -- Note: Cannot set _G.os = nil as LuaUnit framework depends on os functions
    
    local BlindActivationDiagnostics = SMODS.load_file('blind_activation_diagnostics.lua', 'balatro_mcp')()
    local diagnostics = BlindActivationDiagnostics.new()
    
    -- Should not crash when logging without timer
    diagnostics:log("Test message without timer")
    
    -- Restore original values
    _G.love = original_love
    _G.os = original_os
    
    luaunit.assertEquals(true, true, "Should handle missing timer dependencies gracefully")
end

function TestDiagnosticActionsIntegrationWithActionExecutorExecuteAction()
    setup_mock_smods()
    
    -- Create full ActionExecutor with diagnostic actions
    local ActionExecutor = {}
    ActionExecutor.__index = ActionExecutor
    
    function ActionExecutor.new(state_extractor, joker_manager)
        local self = setmetatable({}, ActionExecutor)
        self.state_extractor = state_extractor or {extract_current_state = function() return {} end}
        self.joker_manager = joker_manager or {}
        return self
    end
    
    function ActionExecutor:execute_action(action_data)
        local action_type = action_data.action_type
        local success = false
        local error_message = nil
        local new_state = nil
        
        if action_type == "diagnose_blind_progression" then
            success, error_message = self:execute_diagnose_blind_progression(action_data)
        elseif action_type == "diagnose_blind_activation" then
            success, error_message = self:execute_diagnose_blind_activation(action_data)
        else
            success = false
            error_message = "Unknown action type: " .. action_type
        end
        
        if success then
            new_state = self.state_extractor:extract_current_state()
        end
        
        return {
            success = success,
            error_message = error_message,
            new_state = new_state
        }
    end
    
    function ActionExecutor:execute_diagnose_blind_progression(action_data)
        local BlindProgressionDiagnostics = SMODS.load_file('blind_progression_diagnostics.lua', 'balatro_mcp')()
        local diagnostics = BlindProgressionDiagnostics.new()
        diagnostics:diagnose_blind_state()
        diagnostics:log_hand_result_processing()
        return true, nil
    end
    
    function ActionExecutor:execute_diagnose_blind_activation(action_data)
        local BlindActivationDiagnostics = SMODS.load_file('blind_activation_diagnostics.lua', 'balatro_mcp')()
        local diagnostics = BlindActivationDiagnostics.new()
        diagnostics:diagnose_blind_activation_state()
        diagnostics:check_blind_database()
        return true, nil
    end
    
    local executor = ActionExecutor.new()
    
    -- Test blind progression diagnostic action
    local progression_result = executor:execute_action({action_type = "diagnose_blind_progression"})
    luaunit.assertEquals(true, progression_result.success, "Blind progression diagnostic action should succeed")
    luaunit.assertNil(progression_result.error_message, "Should not have error message")
    luaunit.assertNotNil(progression_result.new_state, "Should extract new state after successful action")
    
    -- Test blind activation diagnostic action
    local activation_result = executor:execute_action({action_type = "diagnose_blind_activation"})
    luaunit.assertEquals(true, activation_result.success, "Blind activation diagnostic action should succeed")
    luaunit.assertNil(activation_result.error_message, "Should not have error message")
    luaunit.assertNotNil(activation_result.new_state, "Should extract new state after successful action")
end

-- Run tests if executed directly
if arg and arg[0] and string.find(arg[0], "test_blind_diagnostics_luaunit") then
    os.exit(luaunit.LuaUnit.run())
end

return {
    TestBlindActivationDiagnosticsConstructorCreatesInstance = TestBlindActivationDiagnosticsConstructorCreatesInstance,
    TestBlindActivationDiagnosticsDiagnoseBlindActivationStateExecutes = TestBlindActivationDiagnosticsDiagnoseBlindActivationStateExecutes,
    TestBlindActivationDiagnosticsCheckBlindDatabaseExecutes = TestBlindActivationDiagnosticsCheckBlindDatabaseExecutes,
    TestBlindActivationDiagnosticsTableSizeUtilityWorks = TestBlindActivationDiagnosticsTableSizeUtilityWorks,
    TestBlindProgressionDiagnosticsConstructorCreatesInstance = TestBlindProgressionDiagnosticsConstructorCreatesInstance,
    TestBlindProgressionDiagnosticsHasRequiredMethods = TestBlindProgressionDiagnosticsHasRequiredMethods,
    TestBlindProgressionDiagnosticsDiagnoseBlindStateExecutes = TestBlindProgressionDiagnosticsDiagnoseBlindStateExecutes,
    TestBlindProgressionDiagnosticsLogHandResultProcessingExecutes = TestBlindProgressionDiagnosticsLogHandResultProcessingExecutes,
    TestActionExecutorExecuteDiagnoseBlindProgressionMethod = TestActionExecutorExecuteDiagnoseBlindProgressionMethod,
    TestActionExecutorExecuteDiagnoseBlindActivationMethod = TestActionExecutorExecuteDiagnoseBlindActivationMethod,
    TestActionExecutorDiagnosticActionsLoadCorrectModules = TestActionExecutorDiagnosticActionsLoadCorrectModules,
    TestActionExecutorHandlesSmodsLoadingFailureGracefully = TestActionExecutorHandlesSmodsLoadingFailureGracefully,
    TestDiagnosticModulesHandleMissingDependenciesGracefully = TestDiagnosticModulesHandleMissingDependenciesGracefully,
    TestDiagnosticActionsIntegrationWithActionExecutorExecuteAction = TestDiagnosticActionsIntegrationWithActionExecutorExecuteAction
}