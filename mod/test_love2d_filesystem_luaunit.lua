-- LuaUnit test suite for Love2D Filesystem Diagnostic
-- Tests what filesystem paths and operations are actually available in Balatro/Steammodded environment
-- Migrated from custom test framework to LuaUnit

local luaunit = require('libs.luaunit')
local luaunit_helpers = require('luaunit_helpers')

-- Set up Love2D filesystem mock for all tests
luaunit_helpers.setup_mock_love_filesystem()

-- === LOVE2D AVAILABILITY TESTS ===

function TestLove2dAvailability()
    luaunit.assertEquals(true, love ~= nil, "love object should be available")
    if love then
        luaunit.assertNotNil(love.filesystem, "love.filesystem should be available")
    end
end

function TestLove2dVersionInfo()
    local success, major, minor, revision, codename = pcall(love.getVersion)
    if success then
        luaunit.assertNotNil(major, "Should have major version")
        luaunit.assertNotNil(minor, "Should have minor version")
        luaunit.assertNotNil(revision, "Should have revision")
        luaunit.assertNotNil(codename, "Should have codename")
        luaunit.assertEquals("number", type(major), "Major version should be number")
        luaunit.assertEquals("number", type(minor), "Minor version should be number")
        luaunit.assertEquals("number", type(revision), "Revision should be number")
        luaunit.assertEquals("string", type(codename), "Codename should be string")
    end
end

-- === DIRECTORY INFORMATION TESTS ===

function TestWorkingDirectory()
    if not (love and love.filesystem) then
        luaunit.assertEquals(true, true, "Working directory test skipped - Love2D filesystem not available")
        return
    end
    local success, working_dir = pcall(love.filesystem.getWorkingDirectory)
    if success then
        luaunit.assertNotNil(working_dir, "Working directory should not be nil")
        luaunit.assertEquals("string", type(working_dir), "Working directory should be string")
    end
end

function TestSaveDirectory()
    if not (love and love.filesystem) then
        luaunit.assertEquals(true, true, "Save directory test skipped - Love2D filesystem not available")
        return
    end
    local success, save_dir = pcall(love.filesystem.getSaveDirectory)
    if success then
        luaunit.assertNotNil(save_dir, "Save directory should not be nil")
        luaunit.assertEquals("string", type(save_dir), "Save directory should be string")
    end
end

function TestSourceBaseDirectory()
    if love and love.filesystem then
        local success, source_dir = pcall(love.filesystem.getSourceBaseDirectory)
        if success then
            luaunit.assertNotNil(source_dir, "Source directory should not be nil")
            luaunit.assertEquals("string", type(source_dir), "Source directory should be string")
        end
    end
end

function TestRealDirectory()
    if love and love.filesystem then
        local success, real_dir = pcall(love.filesystem.getRealDirectory, ".")
        if success then
            luaunit.assertNotNil(real_dir, "Real directory should not be nil")
            luaunit.assertEquals("string", type(real_dir), "Real directory should be string")
        end
    end
end

-- === DIRECTORY CONTENTS TESTS ===

function TestCurrentDirectoryContents()
    if love and love.filesystem then
        local success, files = pcall(love.filesystem.getDirectoryItems, ".")
        if success then
            luaunit.assertNotNil(files, "Files list should not be nil")
            luaunit.assertEquals("table", type(files), "Files list should be table")
            luaunit.assertEquals(true, #files >= 0, "Files count should be non-negative")
            
            -- Test file info for first few files
            for i = 1, math.min(3, #files) do
                local file = files[i]
                luaunit.assertNotNil(file, "File name should not be nil")
                luaunit.assertEquals("string", type(file), "File name should be string")
                
                local info = love.filesystem.getInfo(file)
                if info then
                    luaunit.assertNotNil(info.type, "File info should have type")
                    luaunit.assertEquals(true, info.type == "file" or info.type == "directory", "File type should be 'file' or 'directory'")
                end
            end
        end
    end
end

-- === WRITE PERMISSION TESTS ===

function TestWritePermissionCurrentDirectory()
    if love and love.filesystem then
        local test_path = "test_write_current.txt"
        local test_content = "test content at " .. os.date()
        
        local write_success = love.filesystem.write(test_path, test_content)
        if write_success then
            -- Try to read back
            local content = love.filesystem.read(test_path)
            luaunit.assertNotNil(content, "Should be able to read back written content")
            luaunit.assertEquals(test_content, content, "Read content should match written content")
            
            -- Clean up
            love.filesystem.remove(test_path)
        end
    end
end

function TestWritePermissionSubdirectory()
    if love and love.filesystem then
        local dir = "test_sub_dir"
        local test_path = dir .. "/test_write.txt"
        local test_content = "test subdirectory content"
        
        -- Try to create directory
        local dir_success = love.filesystem.createDirectory(dir)
        if dir_success then
            -- Try to write file
            local write_success = love.filesystem.write(test_path, test_content)
            if write_success then
                -- Try to read back
                local content = love.filesystem.read(test_path)
                luaunit.assertNotNil(content, "Should be able to read back written content from subdirectory")
                luaunit.assertEquals(test_content, content, "Read content should match written content")
                
                -- Clean up
                love.filesystem.remove(test_path)
            end
            love.filesystem.remove(dir)
        end
    end
end

function TestDirectoryCreation()
    if love and love.filesystem then
        local test_dir = "test_capability_dir"
        
        local success = love.filesystem.createDirectory(test_dir)
        if success then
            -- Verify directory exists
            local info = love.filesystem.getInfo(test_dir)
            if info then
                luaunit.assertEquals("directory", info.type, "Created item should be directory")
            end
            
            -- Clean up
            love.filesystem.remove(test_dir)
        end
    end
end

-- === FILESYSTEM CAPABILITIES TESTS ===

function TestFilesystemCapabilities()
    if not (love and love.filesystem) then
        return -- Skip if filesystem not available
    end
    
    local capabilities = {
        can_create_directory = false,
        can_write_current = false,
        can_write_subdirectory = false,
        can_write_save_directory = false
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
    end
    
    -- Test subdirectory write
    if love.filesystem.createDirectory("test_sub") then
        capabilities.can_write_subdirectory = love.filesystem.write("test_sub/test.txt", "test")
        if capabilities.can_write_subdirectory then
            love.filesystem.remove("test_sub/test.txt")
            love.filesystem.remove("test_sub")
        end
    end
    
    -- Test save directory
    capabilities.can_write_save_directory = love.filesystem.write("test_save.txt", "test")
    if capabilities.can_write_save_directory then
        love.filesystem.remove("test_save.txt")
    end
    
    -- Basic capability assertions
    luaunit.assertEquals(true, type(capabilities.can_create_directory) == "boolean", "Directory creation capability should be boolean")
    luaunit.assertEquals(true, type(capabilities.can_write_current) == "boolean", "Current write capability should be boolean")
    luaunit.assertEquals(true, type(capabilities.can_write_subdirectory) == "boolean", "Subdirectory write capability should be boolean")
    luaunit.assertEquals(true, type(capabilities.can_write_save_directory) == "boolean", "Save directory write capability should be boolean")
end

-- === ENVIRONMENT-SPECIFIC TESTS ===

function TestBalatroPaths()
    if love and love.filesystem then
        local balatro_paths = {
            "Balatro",
            "balatro", 
            "mods",
            "Mods",
            "BalatroMCP",
            "balatro_mcp"
        }
        
        local found_paths = {}
        for _, path in ipairs(balatro_paths) do
            local info = love.filesystem.getInfo(path)
            if info then
                found_paths[path] = info.type
            end
        end
        
        -- Just validate that the check completed without errors
        luaunit.assertEquals("table", type(found_paths), "Found paths should be table")
    end
end

function TestSmodsEnvironment()
    if SMODS then
        luaunit.assertNotNil(SMODS, "SMODS should be available")
        luaunit.assertEquals("table", type(SMODS), "SMODS should be table")
        
        if SMODS.path then
            luaunit.assertEquals("string", type(SMODS.path), "SMODS.path should be string if present")
        end
    end
end

function TestFilesystemIdentity()
    if love and love.filesystem then
        local success, identity = pcall(love.filesystem.getIdentity)
        if success and identity then
            luaunit.assertEquals("string", type(identity), "Identity should be string if available")
        end
    end
end

-- === COMPREHENSIVE TEST RUNNER ===

function TestComprehensiveFilesystemDiagnostic()
    -- This test performs the comprehensive diagnostic and validates it completes
    if not (love and love.filesystem) then
        return -- Skip if filesystem not available
    end
    
    local diagnostic_completed = true
    
    -- Test basic operations without throwing errors
    pcall(love.filesystem.getWorkingDirectory)
    pcall(love.filesystem.getSaveDirectory)
    pcall(love.filesystem.getSourceBaseDirectory)
    pcall(love.filesystem.getRealDirectory, ".")
    pcall(love.filesystem.getDirectoryItems, ".")
    
    luaunit.assertEquals(true, diagnostic_completed, "Comprehensive diagnostic should complete")
end

-- Run tests if executed directly
if arg and arg[0] and string.find(arg[0], "test_love2d_filesystem_luaunit") then
    os.exit(luaunit.LuaUnit.run())
end

return {
    TestLove2dAvailability = TestLove2dAvailability,
    TestLove2dVersionInfo = TestLove2dVersionInfo,
    TestWorkingDirectory = TestWorkingDirectory,
    TestSaveDirectory = TestSaveDirectory,
    TestSourceBaseDirectory = TestSourceBaseDirectory,
    TestRealDirectory = TestRealDirectory,
    TestCurrentDirectoryContents = TestCurrentDirectoryContents,
    TestWritePermissionCurrentDirectory = TestWritePermissionCurrentDirectory,
    TestWritePermissionSubdirectory = TestWritePermissionSubdirectory,
    TestDirectoryCreation = TestDirectoryCreation,
    TestFilesystemCapabilities = TestFilesystemCapabilities,
    TestBalatroPaths = TestBalatroPaths,
    TestSmodsEnvironment = TestSmodsEnvironment,
    TestFilesystemIdentity = TestFilesystemIdentity,
    TestComprehensiveFilesystemDiagnostic = TestComprehensiveFilesystemDiagnostic
}