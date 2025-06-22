-- LuaUnit test suite for sequence_id field processing bug fix in BalatroMCP.lua
-- Tests the critical fix where action_data.sequence was changed to action_data.sequence_id
-- This prevents actions from being skipped due to incorrect sequence field reading
-- Migrated from custom test framework to LuaUnit

local luaunit = require('libs.luaunit')

-- Mock components for testing
local function create_mock_file_io()
    return {
        action_data_to_return = nil,
        read_actions = function(self)
            return self.action_data_to_return
        end,
        write_action_result = function(self, data)
            self.last_action_result = data
            return true
        end,
        get_next_sequence_id = function(self)
            return 1
        end,
        write_game_state = function(self, data)
            return true
        end
    }
end

local function create_mock_state_extractor()
    return {
        extract_current_state = function(self)
            return {
                current_phase = "playing",
                money = 100,
                ante = 1
            }
        end
    }
end

local function create_mock_action_executor()
    return {
        execute_action = function(self, action_data)
            self.last_executed_action = action_data
            return {
                success = true,
                error_message = nil
            }
        end
    }
end

-- Create a minimal BalatroMCP instance for testing
local function create_test_balatro_mcp()
    local mcp = {
        file_io = create_mock_file_io(),
        state_extractor = create_mock_state_extractor(),
        action_executor = create_mock_action_executor(),
        processing_action = false,
        last_action_sequence = 0,
        pending_state_extraction = false,
        pending_action_result = nil
    }
    
    -- Copy the process_pending_actions method from BalatroMCP
    mcp.process_pending_actions = function(self)
        -- Check for and process pending actions from MCP server
        if self.processing_action then
            return -- Already processing an action
        end
        
        local action_data = self.file_io:read_actions()
        if not action_data then
            return -- No pending actions
        end
        
        -- CRITICAL FIX: Check sequence_id field (not sequence field)
        local sequence = tonumber(action_data.sequence_id) or 0
        if sequence <= self.last_action_sequence then
            return -- Already processed this action
        end
        
        self.processing_action = true
        self.last_action_sequence = sequence
        
        -- Execute the action
        local result = self.action_executor:execute_action(action_data)
        
        -- Set up delayed state extraction
        self.pending_state_extraction = true
        self.pending_action_result = {
            sequence = sequence,
            action_type = action_data.action_type,
            success = result.success,
            error_message = result.error_message,
            timestamp = os.time()
        }
        
        return true -- Action was processed
    end
    
    return mcp
end

-- === SEQUENCE_ID FIELD PROCESSING TESTS ===

function TestProcessPendingActionsReadsSequenceIdFieldCorrectly()
    local mcp = create_test_balatro_mcp()
    
    -- Set up action data with sequence_id field (not sequence field)
    mcp.file_io.action_data_to_return = {
        action_type = "play_hand",
        sequence_id = 5,  -- This is the correct field name
        data = { cards = {"card1", "card2"} }
    }
    
    local result = mcp:process_pending_actions()
    
    luaunit.assertEquals(true, result, "Should process action with sequence_id field")
    luaunit.assertEquals(5, mcp.last_action_sequence, "Should correctly read sequence_id value")
    luaunit.assertEquals(true, mcp.processing_action, "Should mark action as processing")
    luaunit.assertNotNil(mcp.action_executor.last_executed_action, "Should execute the action")
end

function TestProcessPendingActionsHandlesMissingSequenceIdField()
    local mcp = create_test_balatro_mcp()
    mcp.last_action_sequence = -1  -- Set to -1 so that 0 will be processed
    
    -- Set up action data without sequence_id field
    mcp.file_io.action_data_to_return = {
        action_type = "play_hand",
        -- No sequence_id field - should default to 0
        data = { cards = {"card1", "card2"} }
    }
    
    local result = mcp:process_pending_actions()
    
    luaunit.assertEquals(true, result, "Should process action with missing sequence_id when last_action_sequence < 0")
    luaunit.assertEquals(0, mcp.last_action_sequence, "Should update to 0 for missing sequence_id")
end

function TestDuplicateDetectionWorksWithSequenceIdValues()
    local mcp = create_test_balatro_mcp()
    mcp.last_action_sequence = 10  -- Already processed sequence 10
    
    -- Try to process action with same sequence_id
    mcp.file_io.action_data_to_return = {
        action_type = "play_hand",
        sequence_id = 10,  -- Same as last processed
        data = { cards = {"card1", "card2"} }
    }
    
    local result = mcp:process_pending_actions()
    
    luaunit.assertNil(result, "Should not process duplicate sequence_id")
    luaunit.assertEquals(false, mcp.processing_action, "Should not mark as processing")
    luaunit.assertNil(mcp.action_executor.last_executed_action, "Should not execute duplicate action")
end

function TestDuplicateDetectionWorksWithLowerSequenceIdValues()
    local mcp = create_test_balatro_mcp()
    mcp.last_action_sequence = 15  -- Already processed sequence 15
    
    -- Try to process action with lower sequence_id
    mcp.file_io.action_data_to_return = {
        action_type = "play_hand",
        sequence_id = 12,  -- Lower than last processed
        data = { cards = {"card1", "card2"} }
    }
    
    local result = mcp:process_pending_actions()
    
    luaunit.assertNil(result, "Should not process lower sequence_id")
    luaunit.assertEquals(false, mcp.processing_action, "Should not mark as processing")
    luaunit.assertEquals(15, mcp.last_action_sequence, "Should not update last_action_sequence")
end

function TestProcessesActionsWithHigherSequenceIdValues()
    local mcp = create_test_balatro_mcp()
    mcp.last_action_sequence = 5  -- Already processed sequence 5
    
    -- Process action with higher sequence_id
    mcp.file_io.action_data_to_return = {
        action_type = "reorder_jokers",
        sequence_id = 8,  -- Higher than last processed
        data = { new_order = {1, 0} }
    }
    
    local result = mcp:process_pending_actions()
    
    luaunit.assertEquals(true, result, "Should process higher sequence_id")
    luaunit.assertEquals(8, mcp.last_action_sequence, "Should update last_action_sequence")
    luaunit.assertEquals(true, mcp.processing_action, "Should mark as processing")
    luaunit.assertEquals("reorder_jokers", mcp.action_executor.last_executed_action.action_type, "Should execute correct action")
end

function TestSequenceIdIsPreservedInPendingActionResult()
    local mcp = create_test_balatro_mcp()
    
    -- Process action with specific sequence_id
    mcp.file_io.action_data_to_return = {
        action_type = "buy_joker",
        sequence_id = 42,
        data = { joker_index = 1 }
    }
    
    mcp:process_pending_actions()
    
    luaunit.assertNotNil(mcp.pending_action_result, "Should create pending action result")
    luaunit.assertEquals(42, mcp.pending_action_result.sequence, "Should preserve sequence_id in result")
    luaunit.assertEquals("buy_joker", mcp.pending_action_result.action_type, "Should preserve action type")
end

-- === REGRESSION TESTS FOR OLD BUG ===

function TestOldBugActionDataSequenceFieldWouldFail()
    local mcp = create_test_balatro_mcp()
    
    -- Simulate old bug scenario: action data has 'sequence' field instead of 'sequence_id'
    mcp.file_io.action_data_to_return = {
        action_type = "play_hand",
        sequence = 7,  -- Old field name that should NOT be read
        sequence_id = 7,  -- Correct field name that should be read
        data = { cards = {"card1", "card2"} }
    }
    
    -- With the fix, it should read sequence_id, not sequence
    mcp:process_pending_actions()
    
    luaunit.assertEquals(7, mcp.last_action_sequence, "Should read sequence_id field, not sequence field")
    luaunit.assertEquals(true, mcp.processing_action, "Should process action correctly")
end

function TestOldBugReproductionSequenceFieldIgnoredSequenceIdUsed()
    local mcp = create_test_balatro_mcp()
    mcp.last_action_sequence = 5
    
    -- Action has both fields with different values
    mcp.file_io.action_data_to_return = {
        action_type = "discard_cards", 
        sequence = 3,      -- Lower value in wrong field (would cause skip with old bug)
        sequence_id = 10,  -- Higher value in correct field (should be processed)
        data = { cards = {"card1"} }
    }
    
    local result = mcp:process_pending_actions()
    
    luaunit.assertEquals(true, result, "Should process action using sequence_id field")
    luaunit.assertEquals(10, mcp.last_action_sequence, "Should use sequence_id value, not sequence value")
end

function TestEdgeCaseBothSequenceAndSequenceIdMissing()
    local mcp = create_test_balatro_mcp()
    mcp.last_action_sequence = 1
    
    -- Action has neither sequence nor sequence_id field
    mcp.file_io.action_data_to_return = {
        action_type = "select_blind",
        -- No sequence fields at all
        data = { blind_type = "small" }
    }
    
    local result = mcp:process_pending_actions()
    
    -- Should default to 0, which is <= 1, so should not process
    luaunit.assertNil(result, "Should not process action when sequence_id defaults to 0")
    luaunit.assertEquals(1, mcp.last_action_sequence, "Should not change last_action_sequence")
end

-- === ADDITIONAL EDGE CASE TESTS ===

function TestSequenceIdZeroIsProcessedCorrectly()
    local mcp = create_test_balatro_mcp()
    mcp.last_action_sequence = -1  -- Set to -1 so 0 will be processed
    
    mcp.file_io.action_data_to_return = {
        action_type = "test_action",
        sequence_id = 0,
        data = {}
    }
    
    local result = mcp:process_pending_actions()
    
    luaunit.assertEquals(true, result, "Should process action with sequence_id = 0")
    luaunit.assertEquals(0, mcp.last_action_sequence, "Should update to sequence_id = 0")
end

function TestSequenceIdAsStringIsHandledCorrectly()
    local mcp = create_test_balatro_mcp()
    
    mcp.file_io.action_data_to_return = {
        action_type = "test_action",
        sequence_id = "5",  -- String instead of number
        data = {}
    }
    
    local result = mcp:process_pending_actions()
    
    -- tonumber() should convert string to number for consistent storage
    luaunit.assertEquals(true, result, "Should process action with string sequence_id")
    luaunit.assertEquals(5, mcp.last_action_sequence, "Should convert string sequence_id to number")
end

function TestNoActionDataReturnsNil()
    local mcp = create_test_balatro_mcp()
    
    -- No action data available
    mcp.file_io.action_data_to_return = nil
    
    local result = mcp:process_pending_actions()
    
    luaunit.assertNil(result, "Should return nil when no action data available")
    luaunit.assertEquals(false, mcp.processing_action, "Should not mark as processing")
end

function TestAlreadyProcessingActionSkipsNewAction()
    local mcp = create_test_balatro_mcp()
    mcp.processing_action = true  -- Already processing
    
    mcp.file_io.action_data_to_return = {
        action_type = "test_action",
        sequence_id = 999,
        data = {}
    }
    
    local result = mcp:process_pending_actions()
    
    luaunit.assertNil(result, "Should return nil when already processing an action")
    luaunit.assertEquals(0, mcp.last_action_sequence, "Should not update last_action_sequence")
end

-- Run tests if executed directly
if arg and arg[0] and string.find(arg[0], "test_sequence_id_processing_luaunit") then
    os.exit(luaunit.LuaUnit.run())
end

return {
    TestProcessPendingActionsReadsSequenceIdFieldCorrectly = TestProcessPendingActionsReadsSequenceIdFieldCorrectly,
    TestProcessPendingActionsHandlesMissingSequenceIdField = TestProcessPendingActionsHandlesMissingSequenceIdField,
    TestDuplicateDetectionWorksWithSequenceIdValues = TestDuplicateDetectionWorksWithSequenceIdValues,
    TestDuplicateDetectionWorksWithLowerSequenceIdValues = TestDuplicateDetectionWorksWithLowerSequenceIdValues,
    TestProcessesActionsWithHigherSequenceIdValues = TestProcessesActionsWithHigherSequenceIdValues,
    TestSequenceIdIsPreservedInPendingActionResult = TestSequenceIdIsPreservedInPendingActionResult,
    TestOldBugActionDataSequenceFieldWouldFail = TestOldBugActionDataSequenceFieldWouldFail,
    TestOldBugReproductionSequenceFieldIgnoredSequenceIdUsed = TestOldBugReproductionSequenceFieldIgnoredSequenceIdUsed,
    TestEdgeCaseBothSequenceAndSequenceIdMissing = TestEdgeCaseBothSequenceAndSequenceIdMissing,
    TestSequenceIdZeroIsProcessedCorrectly = TestSequenceIdZeroIsProcessedCorrectly,
    TestSequenceIdAsStringIsHandledCorrectly = TestSequenceIdAsStringIsHandledCorrectly,
    TestNoActionDataReturnsNil = TestNoActionDataReturnsNil,
    TestAlreadyProcessingActionSkipsNewAction = TestAlreadyProcessingActionSkipsNewAction
}