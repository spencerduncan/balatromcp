-- LuaUnit tests for BalatroMCP transport initialization
-- Tests HTTP and File transport integration, configuration, and error handling

local luaunit_helpers = require('tests.luaunit_helpers')
local luaunit = require('libs.luaunit')

-- Helper function to set up before each test
local function setUp()
    luaunit_helpers.setup_mock_love_filesystem()
    luaunit_helpers.setup_mock_smods()
    
    -- Mock the required components
    _G.DebugLogger = {
        new = function(...)
            return {
                info = function(self, msg, component) print("INFO: " .. msg) end,
                error = function(self, msg, component) print("ERROR: " .. msg) end,
                warn = function(self, msg, component) print("WARN: " .. msg) end,
                test_environment = function(self) end,
                test_file_communication = function(self) end,
                test_transport_communication = function(self, transport) end
            }
        end
    }
    
    _G.MessageManager = {
        new = function(transport, prefix)
            return {
                transport = transport,
                prefix = prefix
            }
        end
    }
    
    _G.StateExtractor = {
        new = function()
            return {}
        end
    }
    
    _G.ActionExecutor = {
        new = function(state_extractor, joker_manager)
            return {}
        end
    }
    
    _G.JokerManager = {
        new = function()
            return {
                set_crash_diagnostics = function(self, diagnostics) end
            }
        end
    }
    
    _G.CrashDiagnostics = {
        new = function()
            return {
                create_safe_state_extraction_wrapper = function(self, extractor) end
            }
        end
    }
    
    -- Mock transport classes
    _G.FileTransport = {
        new = function(base_path)
            return {
                is_available = function() return true end,
                write_message = function(self, data, type) return true end,
                read_message = function(self, type) return nil end,
                verify_message = function(self, data, type) return true end,
                cleanup_old_messages = function(self, max_age) return true end
            }
        end
    }
    
    _G.HttpsTransport = {
        new = function(config)
            return {
                base_url = config.base_url,
                is_available = function() return true end,
                write_message = function(self, data, type) return true end,
                read_message = function(self, type) return nil end,
                verify_message = function(self, data, type) return true end,
                cleanup_old_messages = function(self, max_age) return true end
            }
        end
    }
end

-- Helper function to tear down after each test
local function tearDown()
    luaunit_helpers.cleanup_mock_love_filesystem()
    luaunit_helpers.cleanup_mock_smods()
    
    -- Clear globals
    _G.DebugLogger = nil
    _G.MessageManager = nil
    _G.StateExtractor = nil
    _G.ActionExecutor = nil
    _G.JokerManager = nil
    _G.CrashDiagnostics = nil
    _G.FileTransport = nil
    _G.HttpsTransport = nil
    _G.BalatroMCP_Configure = nil
    _G.BalatroMCP_Test_Environment = nil
end

-- Load BalatroMCP with mocked dependencies
local function load_balatromcp()
    -- Clear any existing BalatroMCP module
    package.loaded["BalatroMCP"] = nil
    
    -- Set test environment flag to prevent auto-initialization
    _G.BalatroMCP_Test_Environment = true
    
    -- Mock SMODS.load_file for component loading
    local original_load_file = SMODS.load_file
    SMODS.load_file = function(path)
        if path:match("debug_logger") then
            return function() return _G.DebugLogger end
        elseif path:match("interfaces/message_transport") then
            return function() return {} end
        elseif path:match("transports/file_transport") then
            return function() return _G.FileTransport end
        elseif path:match("transports/https_transport") then
            return function() return _G.HttpsTransport end
        elseif path:match("message_manager") then
            return function() return _G.MessageManager end
        elseif path:match("state_extractor") then
            return function() return _G.StateExtractor end
        elseif path:match("action_executor") then
            return function() return _G.ActionExecutor end
        elseif path:match("joker_manager") then
            return function() return _G.JokerManager end
        elseif path:match("crash_diagnostics") then
            return function() return _G.CrashDiagnostics end
        else
            return original_load_file(path)
        end
    end
    
    return require('BalatroMCP')
end

-- =============================================================================
-- FILE TRANSPORT INITIALIZATION TESTS
-- =============================================================================

local function TestBalatroMCPInitializationWithFileTransport()
    setUp()
    
    local BalatroMCP = load_balatromcp()
    local mcp = BalatroMCP.new()
    
    luaunit.assertNotNil(mcp, "BalatroMCP should initialize with file transport")
    luaunit.assertEquals("FILE", mcp.transport_type, "Should set transport type to FILE")
    luaunit.assertNotNil(mcp.transport, "Should have transport instance")
    luaunit.assertNotNil(mcp.file_transport, "Should maintain backward compatibility reference")
    luaunit.assertEquals(mcp.transport, mcp.file_transport, "file_transport should reference the same transport")
    
    tearDown()
end

-- =============================================================================
-- HTTP TRANSPORT INITIALIZATION TESTS
-- =============================================================================

local function TestBalatroMCPInitializationWithHttpTransport()
    setUp()
    
    local BalatroMCP = load_balatromcp()
    
    -- Configure for HTTP transport
    _G.BalatroMCP_Configure(true, {
        base_url = "http://localhost:8000",
        game_data_endpoint = "/game-data",
        actions_endpoint = "/actions",
        timeout = 10
    })
    
    local mcp = BalatroMCP.new()
    
    luaunit.assertNotNil(mcp, "BalatroMCP should initialize with HTTP transport")
    luaunit.assertEquals("HTTP", mcp.transport_type, "Should set transport type to HTTP")
    luaunit.assertNotNil(mcp.transport, "Should have transport instance")
    luaunit.assertEquals("http://localhost:8000", mcp.transport.base_url, "Should use configured base URL")
    luaunit.assertNil(mcp.file_transport, "Should not have file_transport reference for HTTP")
    
    tearDown()
end

local function TestBalatroMCPHttpTransportConfigurationOverride()
    setUp()
    
    local BalatroMCP = load_balatromcp()
    
    -- Test configuration override
    _G.BalatroMCP_Configure(true, {
        base_url = "https://custom-server.com:8443",
        game_data_endpoint = "/custom-data",
        timeout = 30
    })
    
    local mcp = BalatroMCP.new()
    
    luaunit.assertEquals("HTTP", mcp.transport_type, "Should use HTTP transport")
    luaunit.assertEquals("https://custom-server.com:8443", mcp.transport.base_url, "Should use custom base URL")
    
    tearDown()
end

local function TestBalatroMCPHttpTransportUnavailableServer()
    setUp()
    
    -- Mock HTTP transport to report unavailable
    _G.HttpsTransport = {
        new = function(config)
            return {
                base_url = config.base_url,
                is_available = function() return false end,
                write_message = function(self, data, type) return true end,
                read_message = function(self, type) return nil end,
                verify_message = function(self, data, type) return true end,
                cleanup_old_messages = function(self, max_age) return true end
            }
        end
    }
    
    local BalatroMCP = load_balatromcp()
    
    -- Configure for HTTP transport
    _G.BalatroMCP_Configure(true, {
        base_url = "http://unreachable-server:8000"
    })
    
    -- Should not fail hard - should initialize with warning
    local mcp = BalatroMCP.new()
    
    luaunit.assertNotNil(mcp, "Should initialize even with unavailable server")
    luaunit.assertEquals("HTTP", mcp.transport_type, "Should still use HTTP transport type")
    
    tearDown()
end

local function TestBalatroMCPHttpTransportInitializationFailure()
    setUp()
    
    -- Mock HTTP transport to fail initialization
    _G.HttpsTransport = {
        new = function(config)
            error("Network initialization failed")
        end
    }
    
    local BalatroMCP = load_balatromcp()
    
    -- Configure for HTTP transport
    _G.BalatroMCP_Configure(true, {
        base_url = "http://localhost:8000"
    })
    
    -- Should handle initialization failure gracefully
    local success, result = pcall(function()
        return BalatroMCP.new()
    end)
    
    -- In this case it should fail because HTTP transport can't be created
    luaunit.assertFalse(success, "Should fail when HTTP transport can't be initialized")
    luaunit.assertStrContains(tostring(result), "Network initialization failed", "Should show HTTP transport error")
    
    tearDown()
end

-- =============================================================================
-- COMMUNICATION TEST SELECTION TESTS
-- =============================================================================

local function TestBalatroMCPFileTransportCommunicationTest()
    setUp()
    
    local test_file_communication_called = false
    local test_transport_communication_called = false
    
    -- Mock debug logger to track which test is called
    _G.DebugLogger = {
        new = function(...)
            return {
                info = function(self, msg, component) end,
                error = function(self, msg, component) end,
                warn = function(self, msg, component) end,
                test_environment = function(self) end,
                test_file_communication = function(self) 
                    test_file_communication_called = true
                end,
                test_transport_communication = function(self, transport) 
                    test_transport_communication_called = true
                end
            }
        end
    }
    
    local BalatroMCP = load_balatromcp()
    local mcp = BalatroMCP.new()
    
    luaunit.assertTrue(test_file_communication_called, "Should call file communication test for file transport")
    luaunit.assertFalse(test_transport_communication_called, "Should not call transport communication test for file transport")
    
    tearDown()
end

local function TestBalatroMCPHttpTransportCommunicationTest()
    setUp()
    
    local test_file_communication_called = false
    local test_transport_communication_called = false
    local transport_passed = nil
    
    -- Mock debug logger to track which test is called
    _G.DebugLogger = {
        new = function(...)
            return {
                info = function(self, msg, component) end,
                error = function(self, msg, component) end,
                warn = function(self, msg, component) end,
                test_environment = function(self) end,
                test_file_communication = function(self) 
                    test_file_communication_called = true
                end,
                test_transport_communication = function(self, transport) 
                    test_transport_communication_called = true
                    transport_passed = transport
                end
            }
        end
    }
    
    local BalatroMCP = load_balatromcp()
    
    -- Configure for HTTP transport
    _G.BalatroMCP_Configure(true, {
        base_url = "http://localhost:8000"
    })
    
    local mcp = BalatroMCP.new()
    
    luaunit.assertFalse(test_file_communication_called, "Should not call file communication test for HTTP transport")
    luaunit.assertTrue(test_transport_communication_called, "Should call transport communication test for HTTP transport")
    luaunit.assertEquals(mcp.transport, transport_passed, "Should pass the transport instance to the test")
    
    tearDown()
end

-- =============================================================================
-- BACKWARD COMPATIBILITY TESTS
-- =============================================================================

local function TestBalatroMCPFileTransportBackwardCompatibility()
    setUp()
    
    local BalatroMCP = load_balatromcp()
    local mcp = BalatroMCP.new()
    
    -- Test backward compatibility reference exists and works
    luaunit.assertNotNil(mcp.file_transport, "Should maintain file_transport reference for backward compatibility")
    luaunit.assertEquals(mcp.transport, mcp.file_transport, "file_transport should reference the same transport instance")
    
    -- Test that we can use the backward compatibility reference
    local available = mcp.file_transport:is_available()
    luaunit.assertTrue(available, "Should be able to call methods through backward compatibility reference")
    
    tearDown()
end

local function TestBalatroMCPHttpTransportNoFileTransportReference()
    setUp()
    
    local BalatroMCP = load_balatromcp()
    
    -- Configure for HTTP transport
    _G.BalatroMCP_Configure(true, {
        base_url = "http://localhost:8000"
    })
    
    local mcp = BalatroMCP.new()
    
    luaunit.assertNil(mcp.file_transport, "Should not have file_transport reference when using HTTP transport")
    luaunit.assertNotNil(mcp.transport, "Should still have main transport reference")
    
    tearDown()
end

-- =============================================================================
-- CONFIGURATION TESTS
-- =============================================================================

local function TestBalatroMCPConfigurationFunction()
    setUp()
    
    local BalatroMCP = load_balatromcp()
    
    -- Test that configuration function is available
    luaunit.assertNotNil(_G.BalatroMCP_Configure, "Should export configuration function globally")
    luaunit.assertEquals("function", type(_G.BalatroMCP_Configure), "Configuration should be a function")
    
    -- Test configuration with partial settings
    _G.BalatroMCP_Configure(true, {
        base_url = "https://example.com"
        -- Other settings should use defaults
    })
    
    local mcp = BalatroMCP.new()
    luaunit.assertEquals("HTTP", mcp.transport_type, "Should enable HTTP transport")
    luaunit.assertEquals("https://example.com", mcp.transport.base_url, "Should use configured base URL")
    
    tearDown()
end

local function TestBalatroMCPConfigurationDefaults()
    setUp()
    
    local BalatroMCP = load_balatromcp()
    
    -- Test defaults without configuration
    local mcp = BalatroMCP.new()
    luaunit.assertEquals("FILE", mcp.transport_type, "Should default to file transport")
    
    tearDown()
end

-- Export all test functions for LuaUnit registration
return {
    TestBalatroMCPInitializationWithFileTransport = TestBalatroMCPInitializationWithFileTransport,
    TestBalatroMCPInitializationWithHttpTransport = TestBalatroMCPInitializationWithHttpTransport,
    TestBalatroMCPHttpTransportConfigurationOverride = TestBalatroMCPHttpTransportConfigurationOverride,
    TestBalatroMCPHttpTransportUnavailableServer = TestBalatroMCPHttpTransportUnavailableServer,
    TestBalatroMCPHttpTransportInitializationFailure = TestBalatroMCPHttpTransportInitializationFailure,
    TestBalatroMCPFileTransportCommunicationTest = TestBalatroMCPFileTransportCommunicationTest,
    TestBalatroMCPHttpTransportCommunicationTest = TestBalatroMCPHttpTransportCommunicationTest,
    TestBalatroMCPFileTransportBackwardCompatibility = TestBalatroMCPFileTransportBackwardCompatibility,
    TestBalatroMCPHttpTransportNoFileTransportReference = TestBalatroMCPHttpTransportNoFileTransportReference,
    TestBalatroMCPConfigurationFunction = TestBalatroMCPConfigurationFunction,
    TestBalatroMCPConfigurationDefaults = TestBalatroMCPConfigurationDefaults
}