-- Mod Loading Diagnostics
-- Simple standalone diagnostics to verify if mod files can be loaded at all

print("=== MOD LOADING DIAGNOSTICS START ===")
print("Timestamp: " .. os.date("%Y-%m-%d %H:%M:%S"))

-- Test 1: Verify we can execute Lua code at all
print("TEST 1: Basic Lua execution - SUCCESS")

-- Test 2: Check if SMODS exists
if SMODS then
    print("TEST 2: SMODS framework - AVAILABLE")
    print("SMODS type: " .. type(SMODS))
    
    -- Test 3: Check SMODS.load_file function
    if SMODS.load_file then
        print("TEST 3: SMODS.load_file function - AVAILABLE")
        print("SMODS.load_file type: " .. type(SMODS.load_file))
    else
        print("TEST 3: SMODS.load_file function - MISSING")
    end
else
    print("TEST 2: SMODS framework - NOT AVAILABLE")
    print("This indicates the mod is not being loaded by Steammodded")
end

-- Test 4: Check current working directory and file paths
print("TEST 4: File system diagnostics")
if love and love.filesystem then
    print("Love2D filesystem available")
    local info = love.filesystem.getInfo(".")
    if info then
        print("Current directory accessible: " .. tostring(info.type))
    else
        print("Current directory not accessible via Love2D")
    end
    
    -- Check if our key files exist
    local key_files = {
        "BalatroMCP.lua",
        "crash_diagnostics.lua", 
        "debug_logger.lua",
        "manifest.json"
    }
    
    for _, filename in ipairs(key_files) do
        local file_info = love.filesystem.getInfo(filename)
        if file_info then
            print("File found: " .. filename .. " (size: " .. file_info.size .. ")")
        else
            print("File MISSING: " .. filename)
        end
    end
else
    print("Love2D filesystem not available - cannot check file paths")
end

-- Test 5: Check global environment
print("TEST 5: Global environment check")
print("G exists: " .. tostring(G ~= nil))
if G then
    print("G.STATE exists: " .. tostring(G.STATE ~= nil))
    if G.STATE then
        print("G.STATE value: " .. tostring(G.STATE))
    end
end

-- Test 6: Check if we can write to filesystem (for logging)
print("TEST 6: Filesystem write test")
local test_success, test_error = pcall(function()
    if love and love.filesystem then
        love.filesystem.write("mod_diagnostic_test.txt", "test")
        print("Filesystem write - SUCCESS")
    else
        print("Filesystem write - No Love2D filesystem")
    end
end)

if not test_success then
    print("Filesystem write - FAILED: " .. tostring(test_error))
end

-- Test 7: Create diagnostic confirmation file
print("TEST 7: Creating diagnostic confirmation file")
local file_success, file_error = pcall(function()
    if love and love.filesystem then
        love.filesystem.write("DIAGNOSTIC_CREATED_BY_MOD.txt",
            "MOD LOADING CONFIRMED\n" ..
            "===================\n" ..
            "This file was created by mod_loading_diagnostics.lua\n" ..
            "Timestamp: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n" ..
            "SMODS available: " .. tostring(SMODS ~= nil) .. "\n" ..
            "G object available: " .. tostring(G ~= nil) .. "\n" ..
            "Love2D filesystem available: " .. tostring(love and love.filesystem ~= nil) .. "\n\n" ..
            "If you can see this file, the BalatroMCP mod IS being loaded by Steammodded.\n"
        )
        print("Diagnostic confirmation file created successfully")
    else
        error("Love2D filesystem not available")
    end
end)

if not file_success then
    print("Diagnostic file creation failed: " .. tostring(file_error))
end

print("=== MOD LOADING DIAGNOSTICS END ===")

-- Return empty module to avoid errors
return {}