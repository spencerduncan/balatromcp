-- LuaUnit test suite for API method name fixes validation
-- Tests that BalatroMCP.lua uses the correct FileIO API method names
-- Migrated from custom test framework to LuaUnit

local luaunit = require('libs.luaunit')

-- Test helper functions
local function create_mock_file_io()
    local MockFileIO = {}
    MockFileIO.__index = MockFileIO
    
    function MockFileIO.new()
        local self = setmetatable({}, MockFileIO)
        self.sequence_id = 0
        self.call_log = {}
        return self
    end
    
    function MockFileIO:get_next_sequence_id()
        self.sequence_id = self.sequence_id + 1
        table.insert(self.call_log, "get_next_sequence_id")
        return self.sequence_id
    end
    
    function MockFileIO:read_actions()
        table.insert(self.call_log, "read_actions")
        return nil -- No actions
    end
    
    function MockFileIO:write_action_result(data)
        table.insert(self.call_log, "write_action_result")
        return true
    end
    
    function MockFileIO:write_game_state(data)
        table.insert(self.call_log, "write_game_state")
        return true
    end
    
    return MockFileIO
end

local function create_mock_balatro_mcp(file_io)
    return {
        file_io = file_io,
        last_action_sequence = 0,
        processing_action = false,
        state_extractor = {
            extract_current_state = function() 
                return {
                    game_phase = "test_phase",
                    dollars = 100
                }
            end
        },
        action_executor = {
            execute_action = function(action_data)
                return {
                    success = true,
                    error_message = nil,
                    new_state = {}
                }
            end
        },
        debug_logger = {
            info = function() end,
            error = function() end
        }
    }
end


-- === API METHOD CALLS VALIDATION TESTS ===

function TestAPIMethodCallsValidation()
    local MockFileIO = create_mock_file_io()
    local file_io = MockFileIO.new()
    local balatro_mcp = create_mock_balatro_mcp(file_io)
    
    -- Test 1: Validate get_next_sequence_id is called correctly
    local state_message = {
        message_type = "state_update",
        timestamp = os.time(),
        sequence = balatro_mcp.file_io:get_next_sequence_id(),
        state = {test = "data"}
    }
    
    luaunit.assertEquals(state_message.sequence, 1, "get_next_sequence_id should return 1")
    luaunit.assertStrContains(table.concat(balatro_mcp.file_io.call_log," "), "get_next_sequence_id", "get_next_sequence_id should be called")
    
    -- Test 2: Validate write_game_state is called correctly
    balatro_mcp.file_io:write_game_state(state_message)
    luaunit.assertStrContains(table.concat(balatro_mcp.file_io.call_log," "), "write_game_state", "write_game_state should be called")
    
    -- Test 3: Validate read_actions is called correctly
    balatro_mcp.file_io:read_actions()
    luaunit.assertStrContains(table.concat(balatro_mcp.file_io.call_log," "), "read_actions", "read_actions should be called")
    
    -- Test 4: Validate write_action_result is called correctly
    local response = {
        sequence = 1,
        action_type = "test_action",
        success = true,
        error_message = nil,
        timestamp = os.time(),
        new_state = {}
    }
    balatro_mcp.file_io:write_action_result(response)
    luaunit.assertStrContains(table.concat(balatro_mcp.file_io.call_log," "), "write_action_result", "write_action_result should be called")
end

function TestAPIMethodNameConsistencyValidation()
    local MockFileIO = create_mock_file_io()
    local file_io = MockFileIO.new()
    
    -- Verify deprecated method names are absent
    luaunit.assertNil(file_io.get_next_sequence, "get_next_sequence should not exist")
    luaunit.assertNil(file_io.read_action, "read_action should not exist")
    luaunit.assertNil(file_io.write_response, "write_response should not exist")
    luaunit.assertNil(file_io.write_state, "write_state should not exist")
    
    -- Verify correct method names exist
    luaunit.assertNotNil(file_io.get_next_sequence_id, "get_next_sequence_id should exist")
    luaunit.assertNotNil(file_io.read_actions, "read_actions should exist")
    luaunit.assertNotNil(file_io.write_action_result, "write_action_result should exist")
    luaunit.assertNotNil(file_io.write_game_state, "write_game_state should exist")
end

-- Run tests if executed directly
if arg and arg[0] and string.find(arg[0], "test_api_method_fixes_luaunit") then
    os.exit(luaunit.LuaUnit.run())
end

return {
    TestAPIMethodCallsValidation = TestAPIMethodCallsValidation,
    TestAPIMethodNameConsistencyValidation = TestAPIMethodNameConsistencyValidation
}