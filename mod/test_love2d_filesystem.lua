-- Love2D Filesystem Diagnostic Test
-- Tests what filesystem paths and operations are actually available in Balatro/Steammodded environment

local FileSystemTest = {}

function FileSystemTest.run_comprehensive_test()
    print("=== LOVE2D FILESYSTEM COMPREHENSIVE DIAGNOSTIC ===")
    
    -- Test 1: Basic Love2D availability
    print("\n1. TESTING LOVE2D AVAILABILITY:")
    if love then
        print("   ✓ love object available")
        if love.filesystem then
            print("   ✓ love.filesystem available")
        else
            print("   ✗ love.filesystem NOT available")
            return false
        end
    else
        print("   ✗ love object NOT available")
        return false
    end
    
    -- Test 2: Love2D version and info
    print("\n2. LOVE2D VERSION INFO:")
    local success, major, minor, revision, codename = pcall(love.getVersion)
    if success then
        print("   Love2D Version: " .. major .. "." .. minor .. "." .. revision .. " (" .. codename .. ")")
    else
        print("   Could not get Love2D version")
    end
    
    -- Test 3: Directory information
    print("\n3. DIRECTORY INFORMATION:")
    
    -- Working directory
    local success, working_dir = pcall(love.filesystem.getWorkingDirectory)
    if success then
        print("   Working Directory: " .. tostring(working_dir))
    else
        print("   Could not get working directory: " .. tostring(working_dir))
    end
    
    -- Save directory
    local success, save_dir = pcall(love.filesystem.getSaveDirectory)
    if success then
        print("   Save Directory: " .. tostring(save_dir))
    else
        print("   Could not get save directory: " .. tostring(save_dir))
    end
    
    -- Source directory
    local success, source_dir = pcall(love.filesystem.getSourceBaseDirectory)
    if success then
        print("   Source Base Directory: " .. tostring(source_dir))
    else
        print("   Could not get source directory: " .. tostring(source_dir))
    end
    
    -- Real directory (user directory)
    local success, real_dir = pcall(love.filesystem.getRealDirectory, ".")
    if success then
        print("   Real Directory for '.': " .. tostring(real_dir))
    else
        print("   Could not get real directory: " .. tostring(real_dir))
    end
    
    -- Test 4: Current directory contents
    print("\n4. CURRENT DIRECTORY CONTENTS:")
    local success, files = pcall(love.filesystem.getDirectoryItems, ".")
    if success then
        print("   Files in current directory (" .. #files .. " items):")
        for i, file in ipairs(files) do
            if i <= 10 then -- Show first 10 files
                local info = love.filesystem.getInfo(file)
                local type_str = info and info.type or "unknown"
                print("     - " .. file .. " (" .. type_str .. ")")
            end
        end
        if #files > 10 then
            print("     ... and " .. (#files - 10) .. " more files")
        end
    else
        print("   Could not list current directory: " .. tostring(files))
    end
    
    -- Test 5: Write permission tests
    print("\n5. WRITE PERMISSION TESTS:")
    
    local test_paths = {
        "test_write.txt",                    -- Current directory
        "shared/test_write.txt",             -- Current attempt
        "temp/test_write.txt",               -- Alternative subdirectory
        "debug/test_write.txt",              -- Debug subdirectory
        "logs/test_write.txt",               -- Logs subdirectory
    }
    
    for _, path in ipairs(test_paths) do
        print("   Testing write to: " .. path)
        
        -- Try to create directory if needed
        local dir = path:match("^(.+)/[^/]+$")
        if dir then
            local dir_success = love.filesystem.createDirectory(dir)
            print("     Directory creation (" .. dir .. "): " .. (dir_success and "SUCCESS" or "FAILED"))
        end
        
        -- Try to write file
        local write_success = love.filesystem.write(path, "test content at " .. os.date())
        print("     File write: " .. (write_success and "SUCCESS" or "FAILED"))
        
        if write_success then
            -- Try to read back
            local content = love.filesystem.read(path)
            if content then
                print("     File read back: SUCCESS")
                
                -- Try to delete
                local delete_success = love.filesystem.remove(path)
                print("     File deletion: " .. (delete_success and "SUCCESS" or "FAILED"))
            else
                print("     File read back: FAILED")
            end
        end
    end
    
    -- Test 6: Alternative directory approaches
    print("\n6. ALTERNATIVE DIRECTORY TESTS:")
    
    -- Test using identity
    local success, identity = pcall(love.filesystem.getIdentity)
    if success then
        print("   Current identity: " .. tostring(identity))
    end
    
    -- Test mounting save directory
    local save_dir_success, save_dir = pcall(love.filesystem.getSaveDirectory)
    if save_dir_success then
        print("   Attempting to use save directory: " .. save_dir)
        local save_path = "balatro_mcp_test.txt"
        local save_write_success = love.filesystem.write(save_path, "save directory test at " .. os.date())
        print("   Save directory write: " .. (save_write_success and "SUCCESS" or "FAILED"))
        
        if save_write_success then
            local save_content = love.filesystem.read(save_path)
            if save_content then
                print("   Save directory read: SUCCESS")
                love.filesystem.remove(save_path)
            end
        end
    end
    
    -- Test 7: Filesystem capability summary
    print("\n7. FILESYSTEM CAPABILITY SUMMARY:")
    
    local capabilities = {
        can_create_directory = false,
        can_write_current = false,
        can_write_subdirectory = false,
        can_write_save_directory = false,
        recommended_path = nil
    }
    
    -- Test directory creation
    capabilities.can_create_directory = love.filesystem.createDirectory("test_capability")
    if capabilities.can_create_directory then
        love.filesystem.remove("test_capability")
    end
    
    -- Test current directory write
    capabilities.can_write_current = love.filesystem.write("test_current.txt", "test")
    if capabilities.can_write_current then
        love.filesystem.remove("test_current.txt")
        capabilities.recommended_path = "." -- Current directory works
    end
    
    -- Test subdirectory write
    if love.filesystem.createDirectory("test_sub") then
        capabilities.can_write_subdirectory = love.filesystem.write("test_sub/test.txt", "test")
        if capabilities.can_write_subdirectory then
            love.filesystem.remove("test_sub/test.txt")
            love.filesystem.remove("test_sub")
            if not capabilities.recommended_path then
                capabilities.recommended_path = "balatro_mcp" -- Subdirectory works
            end
        end
    end
    
    -- Test save directory
    local save_success = love.filesystem.write("test_save.txt", "test")
    if save_success then
        capabilities.can_write_save_directory = true
        love.filesystem.remove("test_save.txt")
        if not capabilities.recommended_path then
            capabilities.recommended_path = "" -- Save directory works (empty string = save dir)
        end
    end
    
    print("   Can create directories: " .. (capabilities.can_create_directory and "YES" or "NO"))
    print("   Can write to current directory: " .. (capabilities.can_write_current and "YES" or "NO"))
    print("   Can write to subdirectories: " .. (capabilities.can_write_subdirectory and "YES" or "NO"))
    print("   Can write to save directory: " .. (capabilities.can_write_save_directory and "YES" or "NO"))
    print("   Recommended base path: " .. (capabilities.recommended_path or "NONE FOUND"))
    
    -- Test 8: Environment-specific checks
    print("\n8. ENVIRONMENT-SPECIFIC CHECKS:")
    
    -- Check for Balatro-specific paths
    local balatro_paths = {
        "Balatro",
        "balatro", 
        "mods",
        "Mods",
        "BalatroMCP",
        "balatro_mcp"
    }
    
    for _, path in ipairs(balatro_paths) do
        local info = love.filesystem.getInfo(path)
        if info then
            print("   Found path: " .. path .. " (type: " .. info.type .. ")")
        end
    end
    
    -- Check for Steammodded
    if SMODS then
        print("   SMODS detected - running in Steammodded environment")
        if SMODS.path then
            print("   SMODS path: " .. tostring(SMODS.path))
        end
    else
        print("   SMODS not detected")
    end
    
    print("\n=== FILESYSTEM DIAGNOSTIC COMPLETE ===")
    return capabilities
end

-- Export the test function
return FileSystemTest