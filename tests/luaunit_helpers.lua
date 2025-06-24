-- LuaUnit Mock System Helpers for Balatro MCP Mod
-- Preserves all current mock generators and environment setup patterns
-- Provides luaunit-compatible setUp/tearDown integration

local luaunit_helpers = {}

-- =============================================================================
-- MOCK GENERATORS (preserved from current framework)
-- =============================================================================

-- Comprehensive state constants generator for testing enhanced get_current_phase() method
function luaunit_helpers.create_mock_states()
    -- Sequential integers starting from 1 for all game states
    -- Organized by functional categories as defined in enhanced get_current_phase() method
    return {
        -- Hand/Card Selection States
        SELECTING_HAND = 1,
        DRAW_TO_HAND = 2,
        HAND_PLAYED = 3,
        
        -- Shop and Purchase States
        SHOP = 4,
        
        -- Blind Selection and Round States
        BLIND_SELECT = 5,
        NEW_ROUND = 6,
        ROUND_EVAL = 7,
        
        -- Pack Opening States
        STANDARD_PACK = 8,
        BUFFOON_PACK = 9,
        TAROT_PACK = 10,
        PLANET_PACK = 11,
        SPECTRAL_PACK = 12,
        SMODS_BOOSTER_OPENED = 13,
        
        -- Consumable Usage States
        PLAY_TAROT = 14,
        
        -- Menu and Navigation States
        MENU = 15,
        SPLASH = 16,
        TUTORIAL = 17,
        DEMO_CTA = 18,
        
        -- Game End States
        GAME_OVER = 19,
        
        -- Special Game Modes
        SANDBOX = 20
    }
end

-- Mock G object generator (preserves exact functionality from test_state_extractor.lua)
function luaunit_helpers.create_mock_g(options)
    options = options or {}
    
    local mock_g = {}
    
    -- Add STATE and STATES if requested
    if options.has_state then
        mock_g.STATE = options.state_value or 1
        -- Use comprehensive state constants by default, maintain backward compatibility
        mock_g.STATES = options.states or luaunit_helpers.create_mock_states()
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
    if options.has_funcs or options.funcs then
        mock_g.FUNCS = options.funcs or {}
    end
    
    -- Add blind_select_opts if requested
    if options.blind_select_opts then
        mock_g.blind_select_opts = options.blind_select_opts
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
        end,
        
        isFused = function()
            return false -- Mock always returns false (development mode)
        end
    }
    
    return love.filesystem
end

-- Setup Love2D graphics constants for joker positioning
function luaunit_helpers.setup_mock_love_graphics()
    if not love then
        love = {}
    end
    
    -- Add graphics constants that joker_manager needs
    love.graphics = love.graphics or {}
    
    -- Set up global graphics constants that Balatro uses
    _G.CARD_W = 71  -- Standard card width in Balatro
    _G.CARD_H = 95  -- Standard card height in Balatro
    
    return love.graphics
end

-- Mock SMODS environment setup (preserves exact functionality from test_file_io.lua)
function luaunit_helpers.setup_mock_smods()
    if not _G.SMODS then
        -- Create mock SMODS object that uses the actual JSON library
        _G.SMODS = {
            load_file = function(filename)
                -- Mock implementation that mimics SMODS.load_file behavior
                if filename == "libs/json.lua" then
                    -- Return a function that when called returns the actual JSON library
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

-- Clean up Love2D filesystem mock
function luaunit_helpers.cleanup_mock_love_filesystem()
    if love then
        love.filesystem = nil
    end
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
    luaunit_helpers.setup_mock_love_graphics()
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
                local luaunit = require('lib.luaunit')
                luaunit.assertEquals(actual, expected, message)
            end,
            assert_true = function(_, condition, message)
                local luaunit = require('lib.luaunit')
                luaunit.assertEquals(true, condition, message)
            end,
            assert_false = function(_, condition, message)
                local luaunit = require('lib.luaunit')
                luaunit.assertEquals(false, condition, message)
            end,
            assert_nil = function(_, value, message)
                local luaunit = require('lib.luaunit')
                luaunit.assertNil(value, message)
            end,
            assert_not_nil = function(_, value, message)
                local luaunit = require('lib.luaunit')
                luaunit.assertNotNil(value, message)
            end,
            assert_type = function(_, expected_type, value, message)
                local luaunit = require('lib.luaunit')
                luaunit.assertType(value, expected_type, message)
            end,
            assert_contains = function(_, haystack, needle, message)
                local luaunit = require('lib.luaunit')
                if type(haystack) == "string" then
                    luaunit.assertNotNil(string.find(haystack,  needle),  message)
                else
                    error("assert_contains only supports string search")
                end
            end,
            assert_match = function(_, text, pattern, message)
                local luaunit = require('lib.luaunit')
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