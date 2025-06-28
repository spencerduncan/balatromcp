-- LuaUnit tests for BalatroMCP action processing timing and concurrency
-- Tests processing_action flag management and state extraction timing

local luaunit_helpers = require('tests.luaunit_helpers')
local luaunit = require('libs.luaunit')

-- Helper function to set up before each test
local function setUp()
    luaunit_helpers.setup_mock_love_filesystem()
    luaunit_helpers.setup_mock_smods()
    
    -- Mock the required components with tracking capabilities
    _G.DebugLogger = {
        new = function(...)
            return {
                info = function(self, msg, component) end,
                error = function(self, msg, component) end,
                warn = function(self, msg, component) end,
                test_environment = function(self) end
            }
        end
    }
    
    -- Mock MessageManager with success/failure tracking
    _G.MockMessageManager = {
        write_action_result_should_succeed = true,
        write_action_result_calls = 0,
        
        new = function(transport, prefix)
            return {
                transport = transport,
                prefix = prefix,
                write_action_result = function(self, result_data)
                    _G.MockMessageManager.write_action_result_calls = _G.MockMessageManager.write_action_result_calls + 1
                    return _G.MockMessageManager.write_action_result_should_succeed
                end,
                read_actions = function(self)
                    return nil -- No actions by default
                end
            }
        end
    }
    
    _G.MessageManager = _G.MockMessageManager
    
    -- Mock StateExtractor
    _G.StateExtractor = {
        new = function()
            return {
                extract_current_state = function(self)
                    return {
                        current_phase = "test_phase",
                        money = 100
                    }
                end
            }
        end
    }
    
    -- Mock ActionExecutor  
    _G.ActionExecutor = {
        new = function(state_extractor, joker_manager)
            return {
                execute_action = function(self, action_data)
                    return {
                        success = true,
                        error_message = nil
                    }
                end
            }
        end
    }
    
    -- Mock JokerManager
    _G.JokerManager = {
        new = function()
            return {
                set_crash_diagnostics = function(self, diagnostics) end
            }
        end
    }
    
    -- Mock CrashDiagnostics
    _G.CrashDiagnostics = {
        new = function()
            return {
                wrap_state_extractor = function(self, extractor) return extractor end,
                monitor_joker_operations = function(self) end
            }
        end
    }
    
    -- Mock G object with minimal game state
    _G.G = {
        STATE = 0, -- Normal game state
        GAME = {
            round_resets = {
                ante = 1
            }
        }
    }
    
    -- Reset call counters
    _G.MockMessageManager.write_action_result_calls = 0
    _G.MockMessageManager.write_action_result_should_succeed = true
end

-- Helper function to clean up after each test
local function tearDown()
    _G.DebugLogger = nil
    _G.MessageManager = nil
    _G.MockMessageManager = nil
    _G.StateExtractor = nil
    _G.ActionExecutor = nil
    _G.JokerManager = nil
    _G.CrashDiagnostics = nil
    _G.G = nil
    _G.SMODS = nil
    _G.love = nil
end

-- Test successful action processing timing
local function TestActionProcessingFlagResetOnSuccess()
    setUp()
    
    -- Load BalatroMCP
    local BalatroMCP = assert(SMODS.load_file("BalatroMCP.lua"))()
    local mcp = BalatroMCP.new()
    
    -- Override the message manager with our mock
    mcp.message_manager = _G.MockMessageManager.new()
    
    -- Initialize with minimal setup
    mcp.processing_action = false
    mcp.pending_state_extraction = false
    mcp.pending_action_result = nil
    
    -- Simulate action execution result
    mcp.pending_action_result = {
        sequence = 1,
        action_type = "test_action",
        success = true,
        error_message = nil,
        timestamp = os.time()
    }
    mcp.pending_state_extraction = true
    mcp.processing_action = true -- Set as if action was just executed
    
    -- Process delayed state extraction 
    mcp:handle_delayed_state_extraction()
    
    -- Verify flag was reset after successful write
    luaunit.assertFalse(mcp.processing_action, "processing_action flag should be reset after successful action result write")
    luaunit.assertFalse(mcp.pending_state_extraction, "pending_state_extraction should be reset")
    luaunit.assertNil(mcp.pending_action_result, "pending_action_result should be cleared")
    luaunit.assertEquals(_G.MockMessageManager.write_action_result_calls, 1, "write_action_result should be called once")
    
    tearDown()
end

-- Test failed action result write keeps flag set
local function TestActionProcessingFlagKeptOnWriteFailure()
    setUp()
    
    -- Configure MessageManager to fail writes
    _G.MockMessageManager.write_action_result_should_succeed = false
    
    -- Load BalatroMCP
    local BalatroMCP = assert(SMODS.load_file("BalatroMCP.lua"))()
    local mcp = BalatroMCP.new()
    
    -- Override the message manager with our mock
    mcp.message_manager = _G.MockMessageManager.new()
    
    -- Initialize with minimal setup
    mcp.processing_action = false
    mcp.pending_state_extraction = false
    mcp.pending_action_result = nil
    
    -- Simulate action execution result
    mcp.pending_action_result = {
        sequence = 1,
        action_type = "test_action",
        success = true,
        error_message = nil,
        timestamp = os.time()
    }
    mcp.pending_state_extraction = true
    mcp.processing_action = true -- Set as if action was just executed
    
    -- Process delayed state extraction 
    mcp:handle_delayed_state_extraction()
    
    -- Verify flag is kept set when write fails
    luaunit.assertTrue(mcp.processing_action, "processing_action flag should remain set when write fails")
    luaunit.assertFalse(mcp.pending_state_extraction, "pending_state_extraction should still be reset")
    luaunit.assertNotNil(mcp.pending_action_result, "pending_action_result should be kept for retry")
    luaunit.assertEquals(_G.MockMessageManager.write_action_result_calls, 1, "write_action_result should be called once")
    
    tearDown()
end

-- Test no pending action result resets flag safely
local function TestActionProcessingFlagResetWhenNoPendingResult()
    setUp()
    
    -- Load BalatroMCP
    local BalatroMCP = assert(SMODS.load_file("BalatroMCP.lua"))()
    local mcp = BalatroMCP.new()
    
    -- Override the message manager with our mock
    mcp.message_manager = _G.MockMessageManager.new()
    
    -- Initialize with no pending action
    mcp.processing_action = true -- Set as if flag was stuck
    mcp.pending_state_extraction = true
    mcp.pending_action_result = nil -- No pending action
    
    -- Process delayed state extraction 
    mcp:handle_delayed_state_extraction()
    
    -- Verify flag was reset safely
    luaunit.assertFalse(mcp.processing_action, "processing_action flag should be reset when no pending action")
    luaunit.assertFalse(mcp.pending_state_extraction, "pending_state_extraction should be reset")
    luaunit.assertEquals(_G.MockMessageManager.write_action_result_calls, 0, "write_action_result should not be called")
    
    tearDown()
end

-- Test state extraction timing with multiple cycles
local function TestActionProcessingTimingConsistency()
    setUp()
    
    -- Load BalatroMCP
    local BalatroMCP = assert(SMODS.load_file("BalatroMCP.lua"))()
    local mcp = BalatroMCP.new()
    
    -- Override the message manager with our mock
    mcp.message_manager = _G.MockMessageManager.new()
    
    -- Test multiple action processing cycles
    for i = 1, 3 do
        mcp.processing_action = true
        mcp.pending_state_extraction = true
        mcp.pending_action_result = {
            sequence = i,
            action_type = "test_action_" .. i,
            success = true,
            error_message = nil,
            timestamp = os.time()
        }
        
        -- Process state extraction
        mcp:handle_delayed_state_extraction()
        
        -- Verify flag is properly reset each time
        luaunit.assertFalse(mcp.processing_action, "processing_action flag should be reset after cycle " .. i)
        luaunit.assertFalse(mcp.pending_state_extraction, "pending_state_extraction should be reset after cycle " .. i)
        luaunit.assertNil(mcp.pending_action_result, "pending_action_result should be cleared after cycle " .. i)
    end
    
    luaunit.assertEquals(_G.MockMessageManager.write_action_result_calls, 3, "write_action_result should be called for each cycle")
    
    tearDown()
end

-- Test concurrency protection with processing flag
local function TestConcurrencyProtectionWithProcessingFlag()
    setUp()
    
    -- Load BalatroMCP  
    local BalatroMCP = assert(SMODS.load_file("BalatroMCP.lua"))()
    local mcp = BalatroMCP.new()
    
    -- Set up mocks for action polling
    mcp.polling_active = true
    mcp.transport = {
        is_available = function() return true end,
        update = function() end
    }
    mcp.message_manager = _G.MockMessageManager.new()
    
    -- Simulate action in progress
    mcp.processing_action = true
    mcp.last_action_sequence = 0
    
    -- Try to process pending actions while flag is set
    mcp:process_pending_actions()
    
    -- Verify no new action processing occurred
    luaunit.assertEquals(_G.MockMessageManager.write_action_result_calls, 0, "No action result writes should occur when processing_action is true")
    
    -- Reset flag and try again
    mcp.processing_action = false
    mcp:process_pending_actions()
    
    -- Should still be 0 since no actions are available (mocked to return nil)
    luaunit.assertEquals(_G.MockMessageManager.write_action_result_calls, 0, "No action writes when no actions available")
    
    tearDown()
end

-- Run the tests
return {
    TestActionProcessingFlagResetOnSuccess = TestActionProcessingFlagResetOnSuccess,
    TestActionProcessingFlagKeptOnWriteFailure = TestActionProcessingFlagKeptOnWriteFailure, 
    TestActionProcessingFlagResetWhenNoPendingResult = TestActionProcessingFlagResetWhenNoPendingResult,
    TestActionProcessingTimingConsistency = TestActionProcessingTimingConsistency,
    TestConcurrencyProtectionWithProcessingFlag = TestConcurrencyProtectionWithProcessingFlag
}