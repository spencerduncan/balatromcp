-- Simple test runner for Love2D filesystem diagnostic
-- Can be called from main mod to diagnose filesystem issues

local function run_filesystem_diagnostic()
    -- Load the comprehensive filesystem test
    local success, FileSystemTest = pcall(function()
        return assert(SMODS.load_file("test_love2d_filesystem.lua"))()
    end)
    
    if not success then
        print("BalatroMCP: Failed to load filesystem test: " .. tostring(FileSystemTest))
        return false
    end
    
    -- Run the diagnostic
    local test_success, capabilities = pcall(FileSystemTest.run_comprehensive_test)
    
    if not test_success then
        print("BalatroMCP: Filesystem test failed: " .. tostring(capabilities))
        return false
    end
    
    return capabilities
end

return run_filesystem_diagnostic