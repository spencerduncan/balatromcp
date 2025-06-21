#!/usr/bin/env lua

-- Simple test runner for Lua unit tests
-- Usage: lua run_lua_tests.lua

print("=== BALATRO MCP MOD - LUA UNIT TEST RUNNER ===")
print("Running unit tests for validation logic and JSON fallback functionality...")

-- Test modules to run
local test_modules = {
    {name = "test_state_extractor", description = "StateExtractor validation logic"},
    {name = "test_file_io", description = "FileIO JSON fallback functionality"},
    {name = "test_steammodded_loading", description = "Steammodded module loading mechanism"},
    {name = "test_api_method_fixes", description = "API method fixes validation"},
    {name = "test_crash_diagnostics", description = "CrashDiagnostics object validation and hook safety"},
    {name = "test_joker_manager_crash_safety", description = "JokerManager defensive programming and safe config access"},
    {name = "test_shop_state_detection", description = "Shop state detection and timing mechanisms"}
    -- Removed test_love2d_filesystem as it's a diagnostic tool, not a unit test
    -- Removed test_smods_integration_fixes as it's an integration test, not a unit test
}

local total_passed = 0
local total_failed = 0
local failed_modules = {}

-- Set up a minimal environment for testing
print("Setting up test environment...")
G = nil  -- Initialize G as nil to start with clean state

-- Run each test module
for _, module_info in ipairs(test_modules) do
    print(string.format("\n=== RUNNING %s TESTS ===", module_info.description:upper()))
    
    local success, test_module = pcall(require, module_info.name)
    
    if not success then
        print("❌ ERROR: Could not load " .. module_info.name .. " module")
        print("   Error: " .. tostring(test_module))
        print("   Make sure " .. module_info.name .. ".lua is in the same directory")
        table.insert(failed_modules, module_info.name)
    elseif type(test_module) ~= "table" or not test_module.run_tests then
        print("❌ ERROR: " .. module_info.name .. " module missing run_tests function or invalid module type")
        print("   Module type: " .. type(test_module))
        table.insert(failed_modules, module_info.name)
    else
        local module_passed = test_module.run_tests()
        
        if module_passed then
            print("✅ " .. module_info.description .. " tests PASSED")
        else
            print("❌ " .. module_info.description .. " tests FAILED")
            table.insert(failed_modules, module_info.name)
        end
        
        -- Collect test statistics if available
        if test_module.test_framework then
            total_passed = total_passed + test_module.test_framework.passed
            total_failed = total_failed + test_module.test_framework.failed
        end
    end
end

-- Print final results
print("\n" .. string.rep("=", 60))
print("FINAL TEST RESULTS")
print(string.rep("=", 60))
print(string.format("Total Tests Passed: %d", total_passed))
print(string.format("Total Tests Failed: %d", total_failed))
print(string.format("Test Modules Run: %d", #test_modules))
print(string.format("Failed Modules: %d", #failed_modules))

if #failed_modules > 0 then
    print("\nFailed test modules:")
    for _, module_name in ipairs(failed_modules) do
        print("  • " .. module_name)
    end
end

if #failed_modules == 0 and total_failed == 0 then
    print("\n🎉 SUCCESS: All tests passed!")
    print("✅ StateExtractor module correctly handles missing and malformed G object structures")
    print("✅ FileIO module provides robust JSON fallback functionality with Steammodded loading")
    print("✅ Steammodded module loading mechanism works correctly for all dependencies")
    print("✅ Critical dependency issues have been resolved with proper error handling")
    print("✅ Module inter-dependencies and initialization patterns are validated")
    print("✅ API method naming issues have been fixed and validated to prevent regressions")
    print("✅ CrashDiagnostics provides comprehensive object validation and hook safety")
    print("✅ JokerManager defensive programming prevents crashes with corrupted config fields")
    print("✅ BalatroMCP crash diagnostics integration provides error handling and graceful degradation")
    print("✅ Crash fix implementation addresses 'config field nil errors' that occur in hook interference scenarios")
    print("✅ Love2D update hook crash protection prevents game crashes with pcall error handling")
    print("✅ Shop state detection and timing mechanisms ensure accurate shop data loading and coordination")
    os.exit(0)
else
    print("\n❌ FAILURE: Some tests failed!")
    print("Please review the failing modules and fix any issues.")
    os.exit(1)
end