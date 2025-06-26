-- LuaUnit tests for SessionExtractor
-- Tests session ID generation and persistence

local luaunit = require('libs.luaunit')
local luaunit_helpers = require('tests.luaunit_helpers')

-- =============================================================================
-- SETUP AND TEARDOWN
-- =============================================================================

local test_state = {}

local function setUp()
    -- Save original globals
    test_state.original_g = G
    
    -- Set up clean environment
    G = nil
end

local function tearDown()
    -- Restore original globals
    G = test_state.original_g
end

-- =============================================================================
-- SESSION EXTRACTOR TESTS
-- =============================================================================

function testSessionExtractorExtractGeneratesSessionId()
    setUp()
    local SessionExtractor = require("state_extractor.extractors.session_extractor")
    local extractor = SessionExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertNotNil(result.session_id, "Should have session_id field")
    luaunit.assertEquals("string", type(result.session_id), "Session ID should be string")
    luaunit.assertStrMatches(result.session_id, "^session_%d+_%d+$", "Should match session ID pattern")
    tearDown()
end

function testSessionExtractorSessionIdPersistence()
    setUp()
    local SessionExtractor = require("state_extractor.extractors.session_extractor")
    local extractor = SessionExtractor.new()
    
    local result1 = extractor:extract()
    local result2 = extractor:extract()
    
    luaunit.assertEquals(result1.session_id, result2.session_id, "Session ID should persist across calls")
    tearDown()
end

function testSessionExtractorGetSessionIdDirectCall()
    setUp()
    local SessionExtractor = require("state_extractor.extractors.session_extractor")
    local extractor = SessionExtractor.new()
    
    local session_id = extractor:get_session_id()
    luaunit.assertEquals("string", type(session_id), "Should return string")
    luaunit.assertStrMatches(session_id, "^session_%d+_%d+$", "Should match session ID pattern")
    tearDown()
end

function testSessionExtractorGetName()
    setUp()
    local SessionExtractor = require("state_extractor.extractors.session_extractor")
    local extractor = SessionExtractor.new()
    
    luaunit.assertEquals("session_extractor", extractor:get_name(), "Should return correct extractor name")
    tearDown()
end

function testSessionExtractorMultipleInstancesGenerateDifferentIds()
    setUp()
    local SessionExtractor = require("state_extractor.extractors.session_extractor")
    local extractor1 = SessionExtractor.new()
    local extractor2 = SessionExtractor.new()
    
    local result1 = extractor1:extract()
    local result2 = extractor2:extract()
    
    luaunit.assertNotEquals(result1.session_id, result2.session_id, "Different instances should generate different session IDs")
    tearDown()
end

-- Return all test functions as a table for LuaUnit runner
return {
    testSessionExtractorExtractGeneratesSessionId = testSessionExtractorExtractGeneratesSessionId,
    testSessionExtractorSessionIdPersistence = testSessionExtractorSessionIdPersistence,
    testSessionExtractorGetSessionIdDirectCall = testSessionExtractorGetSessionIdDirectCall,
    testSessionExtractorGetName = testSessionExtractorGetName,
    testSessionExtractorMultipleInstancesGenerateDifferentIds = testSessionExtractorMultipleInstancesGenerateDifferentIds
}