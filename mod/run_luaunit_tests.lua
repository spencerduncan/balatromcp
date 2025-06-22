#!/usr/bin/env lua

-- Unified LuaUnit test runner for Balatro MCP Mod
-- Usage: lua run_luaunit_tests.lua
-- Uses standard LuaUnit execution with all test modules registered globally

print("=== BALATRO MCP MOD - LUAUNIT TEST RUNNER ===")
print("Running comprehensive LuaUnit test coverage...")
print("")

-- Import luaunit
local luaunit = require('luaunit')

-- Test modules to run (all migrated test suites)
local luaunit_test_modules = {
    -- Core modules (120 tests total)
    {name = "test_debug_logger_path_handling_luaunit", description = "DebugLogger path handling functionality"},
    {name = "test_file_io_luaunit", description = "FileIO JSON handling and file operations"},
    {name = "test_joker_manager_crash_safety_luaunit", description = "JokerManager crash safety and defensive programming"},
    {name = "test_shop_state_detection_luaunit", description = "ShopStateDetection shop state transition detection and timing mechanisms"},
    {name = "test_state_extractor_luaunit", description = "StateExtractor comprehensive state extraction functionality and validation logic"},
    
    -- Diagnostic modules (85 tests total)
    {name = "test_api_method_fixes_luaunit", description = "API method fixes and validation"},
    {name = "test_blind_diagnostics_luaunit", description = "Blind activation and progression diagnostics"},
    {name = "test_crash_diagnostics_luaunit", description = "Crash diagnostics and hook safety validation"},
    {name = "test_love2d_filesystem_luaunit", description = "Love2D filesystem capabilities and environment detection"},
    {name = "test_sequence_id_processing_luaunit", description = "Sequence ID processing bug fixes and validation"},
    {name = "test_blind_selection_diagnostics_luaunit", description = "Blind selection diagnostics and SMODS integration"},
}

-- Set up a minimal environment for testing
print("Setting up test environment...")
G = nil  -- Initialize G as nil to start with clean state

-- Load all test modules and register their test functions globally
local loaded_modules = {}
local total_tests = 0

for _, module_info in ipairs(luaunit_test_modules) do
    print(string.format("Loading %s (%s)...", module_info.name, module_info.description))
    
    local success, test_module = pcall(require, module_info.name)
    
    if success and test_module then
        loaded_modules[module_info.name] = test_module
        
        -- Register all test functions from the module globally
        if type(test_module) == "table" then
            local test_count = 0
            for test_name, test_func in pairs(test_module) do
                if type(test_func) == "function" and string.match(test_name, "^Test") then
                    _G[test_name] = test_func
                    test_count = test_count + 1
                end
            end
            total_tests = total_tests + test_count
            print(string.format("  ✓ Registered %d tests from %s", test_count, module_info.name))
        end
    else
        print(string.format("  ❌ Failed to load %s: %s", module_info.name, tostring(test_module)))
    end
end

print(string.format("\nTotal test functions registered: %d", total_tests))
print(string.format("Total test modules loaded: %d/%d", #loaded_modules, #luaunit_test_modules))

if total_tests == 0 then
    print("\n" .. string.rep("=", 60))
    print("NO TESTS REGISTERED")
    print(string.rep("=", 60))
    print("No test functions were successfully registered.")
    print("Please check that test modules are properly structured.")
    os.exit(1)
end

print("\n" .. string.rep("=", 60))
print("RUNNING LUAUNIT TESTS")
print(string.rep("=", 60))

-- Run all registered tests using standard LuaUnit
os.exit(luaunit.LuaUnit.run())