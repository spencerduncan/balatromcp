-- LuaUnit Mock System Helpers for Balatro MCP Mod
-- Preserves all current mock generators and environment setup patterns
-- Provides luaunit-compatible setUp/tearDown integration

local luaunit_helpers = {}

-- =============================================================================
-- MOCK GENERATORS (preserved from current framework)
-- =============================================================================

-- Mock G object generator (preserves exact functionality from test_state_extractor.lua)
function luaunit_helpers.create_mock_g(options)
    options = options or {}
    
    local mock_g = {}
    
    -- Add STATE and STATES if requested
    if options.has_state then
        mock_g.STATE = options.state_value or 1
        mock_g.STATES = options.states or {
            SELECTING_HAND = 1,
            SHOP = 2,
            BLIND_SELECT = 3,
            DRAW_TO_HAND = 4
        }
    end
    
    -- Add GAME object if requested
    if options.has_game then
        mock_g.GAME = {
            dollars = options.dollars or 100,
            current_round = options.current_round or {
                hands_left = 3,
                discards_left = 3
            },
            round_resets = options.round_resets or {
                ante = 1
            },
            blind = options.blind or {
                name = "Small Blind",
                chips = 300,
                dollars = 3,
                boss = false,
                config = {}
            }
        }
    end
    
    -- Add card areas if requested
    if options.has_hand then
        mock_g.hand = {
            cards = options.hand_cards or {}
        }
    end
    
    if options.has_jokers then
        mock_g.jokers = {
            cards = options.joker_cards or {}
        }
    end
    
    if options.has_consumables then
        mock_g.consumeables = {
            cards = options.consumable_cards or {}
        }
    end
    
    if options.has_shop then
        mock_g.shop_jokers = {
            cards = options.shop_cards or {}
        }
    end
    
    -- Add FUNCS if requested
    if options.has_funcs then
        mock_g.FUNCS = options.funcs or {}
    end
    
    return mock_g
end

-- Mock card generator (preserves exact functionality from test_state_extractor.lua)
function luaunit_helpers.create_mock_card(options)
    options = options or {}
    
    return {
        unique_val = options.id or "test_card_1",
        base = {
            value = options.rank or "A",
            suit = options.suit or "Spades"
        },
        ability = {
            name = options.ability_name or "base",
            extra = options.extra or {},
            mult = options.mult or 0,
            t_chips = options.chips or 0
        },
        edition = options.edition or nil,
        seal = options.seal or nil,
        config = options.config or {}
    }
end

-- Mock joker generator (preserves exact functionality from test_state_extractor.lua)
function luaunit_helpers.create_mock_joker(options)
    options = options or {}
    
    return {
        unique_val = options.id or "test_joker_1",
        ability = {
            name = options.name or "Joker",
            extra = options.extra or {},
            mult = options.mult or 4,
            t_chips = options.chips or 0
        },
        config = options.config or {}
    }
end

-- =============================================================================
-- ENVIRONMENT SETUP PATTERNS (preserved from current framework)
-- =============================================================================

-- Mock Love2D filesystem setup (preserves exact functionality from test_file_io.lua)
function luaunit_helpers.setup_mock_love_filesystem()
    if not love then
        love = {}
    end
    
    love.filesystem = {
        files = {},
        directories = {},
        
        createDirectory = function(path)
            love.filesystem.directories[path] = true
            return true
        end,
        
        getInfo = function(path)
            if love.filesystem.directories[path] then
                return {type = "directory"}
            elseif love.filesystem.files[path] then
                return {type = "file", size = #love.filesystem.files[path]}
            else
                return nil
            end
        end,
        
        write = function(path, content)
            love.filesystem.files[path] = content
            return true
        end,
        
        read = function(path)
            local content = love.filesystem.files[path]
            if content then
                return content, #content
            else
                return nil
            end
        end,
        
        remove = function(path)
            if love.filesystem.files[path] then
                love.filesystem.files[path] = nil
                return true
            end
            return false
        end
    }
    
    return love.filesystem
end

-- Mock SMODS environment setup (preserves exact functionality from test_file_io.lua)
function luaunit_helpers.setup_mock_smods()
    if not _G.SMODS then
        -- Create mock SMODS object
        _G.SMODS = {
            load_file = function(filename)
                -- Mock implementation that mimics SMODS.load_file behavior
                if filename == "libs/json.lua" then
                    -- Return a function that when called returns the JSON library
                    return function()
                        return require("libs.json")
                    end
                else
                    error("Mock SMODS: File not found: " .. filename)
                end
            end
        }
    end
    
    return _G.SMODS
end

-- Clean up SMODS mock (preserves exact functionality from test_file_io.lua)
function luaunit_helpers.cleanup_mock_smods()
    _G.SMODS = nil
end

-- Clean up Love2D mock
function luaunit_helpers.cleanup_mock_love()
    love = nil
end

-- =============================================================================
-- LUAUNIT SETUP/TEARDOWN INTEGRATION
-- =============================================================================

-- Base test class with common setUp/tearDown patterns
local LuaUnitTestBase = {}
LuaUnitTestBase.__index = LuaUnitTestBase

function LuaUnitTestBase:new()
    local self = setmetatable({}, LuaUnitTestBase)
    self.original_g = nil
    self.original_love = nil
    self.original_smods = nil
    return self
end

-- Standard setUp that most tests need
function LuaUnitTestBase:setUp()
    -- Save original globals
    self.original_g = G
    self.original_love = love
    self.original_smods = _G.SMODS
    
    -- Set up clean environment
    G = nil
end

-- Standard tearDown that restores environment
function LuaUnitTestBase:tearDown()
    -- Restore original globals
    G = self.original_g
    love = self.original_love
    _G.SMODS = self.original_smods
end

-- FileIO-specific test base (includes Love2D and SMODS setup)
local FileIOTestBase = {}
FileIOTestBase.__index = FileIOTestBase
setmetatable(FileIOTestBase, {__index = LuaUnitTestBase})

function FileIOTestBase:new()
    local self = LuaUnitTestBase:new()
    setmetatable(self, FileIOTestBase)
    return self
end

function FileIOTestBase:setUp()
    LuaUnitTestBase.setUp(self)
    luaunit_helpers.setup_mock_love_filesystem()
    luaunit_helpers.setup_mock_smods()
end

function FileIOTestBase:tearDown()
    luaunit_helpers.cleanup_mock_smods()
    luaunit_helpers.cleanup_mock_love()
    LuaUnitTestBase.tearDown(self)
end

-- StateExtractor-specific test base (includes G object mocking)
local StateExtractorTestBase = {}
StateExtractorTestBase.__index = StateExtractorTestBase
setmetatable(StateExtractorTestBase, {__index = LuaUnitTestBase})

function StateExtractorTestBase:new()
    local self = LuaUnitTestBase:new()
    setmetatable(self, StateExtractorTestBase)
    return self
end

function StateExtractorTestBase:setUp()
    LuaUnitTestBase.setUp(self)
    -- StateExtractor tests often need different G setups, so we don't set a default
end

-- =============================================================================
-- CONVENIENCE FUNCTIONS FOR TEST MIGRATION
-- =============================================================================

-- Convert a TestFramework test function to work with these helpers
function luaunit_helpers.wrap_test_function(test_func, setup_func, teardown_func)
    return function(self)
        if setup_func then
            setup_func()
        end
        
        -- Create a mock test framework object for compatibility
        local mock_t = {
            assert_equal = function(_, expected, actual, message)
                local luaunit = require('luaunit')
                luaunit.assertEquals(actual, expected, message)
            end,
            assert_true = function(_, condition, message)
                local luaunit = require('luaunit')
                luaunit.assertTrue(condition, message)
            end,
            assert_false = function(_, condition, message)
                local luaunit = require('luaunit')
                luaunit.assertFalse(condition, message)
            end,
            assert_nil = function(_, value, message)
                local luaunit = require('luaunit')
                luaunit.assertNil(value, message)
            end,
            assert_not_nil = function(_, value, message)
                local luaunit = require('luaunit')
                luaunit.assertNotNil(value, message)
            end,
            assert_type = function(_, expected_type, value, message)
                local luaunit = require('luaunit')
                luaunit.assertType(value, expected_type, message)
            end,
            assert_contains = function(_, haystack, needle, message)
                local luaunit = require('luaunit')
                if type(haystack) == "string" then
                    luaunit.assertStrContains(haystack, needle, message)
                else
                    error("assert_contains only supports string search")
                end
            end,
            assert_match = function(_, text, pattern, message)
                local luaunit = require('luaunit')
                luaunit.assertStrMatches(text, pattern, message)
            end
        }
        
        test_func(mock_t)
        
        if teardown_func then
            teardown_func()
        end
    end
end

-- Export all helpers and base classes
luaunit_helpers.LuaUnitTestBase = LuaUnitTestBase
luaunit_helpers.FileIOTestBase = FileIOTestBase
luaunit_helpers.StateExtractorTestBase = StateExtractorTestBase

return luaunit_helpers