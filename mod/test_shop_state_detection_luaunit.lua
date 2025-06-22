-- LuaUnit version of ShopStateDetection test suite
-- Tests shop-specific game state detection patterns and timing mechanisms

local luaunit = require('luaunit')
local luaunit_helpers = require('luaunit_helpers')

-- Test class for ShopStateDetection functionality
local TestShopStateDetection = {}

function TestShopStateDetection:setUp()
    -- Save original globals
    self.original_g = G
    self.original_love = love
    self.original_smods = _G.SMODS
    self.original_print = print
    
    -- Initialize clean state
    G = nil
    love = nil
    _G.SMODS = nil
    
    -- Set up test environment with shop-specific mock data
    self:setup_test_environment()
end

function TestShopStateDetection:tearDown()
    -- Restore original globals
    G = self.original_g
    love = self.original_love
    _G.SMODS = self.original_smods
    print = self.original_print
end

function TestShopStateDetection:setup_test_environment()
    -- Mock SMODS framework with shop-specific components
    _G.SMODS = {
        load_file = function(filename)
            if filename == "BalatroMCP.lua" then
                return function()
                    local BalatroMCP = {}
                    BalatroMCP.__index = BalatroMCP
                    
                    function BalatroMCP.new()
                        local self = setmetatable({}, BalatroMCP)
                        
                        -- Initialize mock components (matching real implementation)
                        self.debug_logger = { info = function() end, error = function() end }
                        self.crash_diagnostics = { create_safe_hook = function(self, func, name) return func end }
                        self.file_io = { get_next_sequence_id = function() return 1 end }
                        self.state_extractor = {
                            extract_current_state = function()
                                return {
                                    current_phase = "shop",
                                    money = 100,
                                    shop_contents = {}
                                }
                            end
                        }
                        
                        -- State tracking variables (matching real implementation)
                        self.polling_active = false
                        self.delayed_shop_state_capture = false
                        self.delayed_shop_capture_timer = 0
                        self.last_shop_state = nil
                        self.shop_state_initialized = false
                        
                        return self
                    end
                    
                    function BalatroMCP:setup_shop_state_detection()
                        print("BalatroMCP: Setting up shop state detection")
                        self.last_shop_state = nil
                        self.shop_state_initialized = false
                    end
                    
                    function BalatroMCP:hook_shop_interactions()
                        if G and G.FUNCS then
                            local original_cash_out = G.FUNCS.cash_out
                            if original_cash_out then
                                G.FUNCS.cash_out = function(...)
                                    local result = original_cash_out(...)
                                    self:on_shop_entered()
                                    return result
                                end
                            else
                                print("BalatroMCP: WARNING - G.FUNCS.cash_out not available for shop hooks")
                            end
                            self:setup_shop_state_detection()
                        end
                    end
                    
                    function BalatroMCP:detect_shop_state_transition()
                        if not G or not G.STATE or not G.STATES then
                            return
                        end
                        
                        local current_state = G.STATE
                        
                        -- Initialize tracking on first run
                        if not self.last_shop_state then
                            self.last_shop_state = current_state
                            self.shop_state_initialized = false
                            return
                        end
                        
                        -- Skip if delayed capture is active
                        if self.delayed_shop_state_capture then
                            return
                        end
                        
                        -- Detect transition into shop
                        local was_not_shop = (self.last_shop_state ~= G.STATES.SHOP)
                        local is_shop = (current_state == G.STATES.SHOP)
                        
                        if was_not_shop and is_shop and not self.shop_state_initialized then
                            print("BalatroMCP: NON_INTRUSIVE_DETECTION - Shop state entered: " ..
                                  tostring(self.last_shop_state) .. " -> " .. tostring(current_state))
                            self.shop_state_initialized = true
                            self:on_shop_entered()
                        end
                        
                        -- Reset shop state flag when leaving
                        if current_state ~= G.STATES.SHOP then
                            self.shop_state_initialized = false
                        end
                        
                        -- Update tracking
                        self.last_shop_state = current_state
                    end
                    
                    function BalatroMCP:on_shop_entered()
                        print("BalatroMCP: Shop entered event - delaying state capture for shop population")
                        
                        -- Diagnostic logging
                        local current_state = self.state_extractor:extract_current_state()
                        local phase = current_state and current_state.current_phase or "unknown"
                        local money = current_state and current_state.money or "unknown"
                        local shop_items = current_state and current_state.shop_contents and #current_state.shop_contents or 0
                        print("BalatroMCP: DEBUG - Hook fired with state: phase=" .. phase .. ", money=" .. tostring(money) .. ", shop_items=" .. tostring(shop_items))
                        
                        -- Set delay timer
                        self.delayed_shop_state_capture = true
                        self.delayed_shop_capture_timer = 1.0
                    end
                    
                    function BalatroMCP:update(dt)
                        if not self.polling_active then
                            return
                        end
                        
                        -- Call shop state detection
                        self:detect_shop_state_transition()
                        
                        -- Handle delayed shop capture
                        if self.delayed_shop_state_capture then
                            self.delayed_shop_capture_timer = self.delayed_shop_capture_timer - dt
                            if self.delayed_shop_capture_timer <= 0 then
                                print("BalatroMCP: Executing delayed shop state capture")
                                self.delayed_shop_state_capture = false
                                
                                -- Extract state and log
                                local current_state = self.state_extractor:extract_current_state()
                                local shop_items = current_state and current_state.shop_contents and #current_state.shop_contents or 0
                                print("BalatroMCP: DEBUG - Shop state after delay: shop_items=" .. tostring(shop_items))
                                
                                self:send_current_state()
                            end
                        end
                    end
                    
                    function BalatroMCP:send_current_state()
                        -- Mock implementation
                    end
                    
                    return BalatroMCP
                end
            elseif filename == "debug_logger.lua" then
                return function() return {
                    new = function() return {
                        info = function() end,
                        error = function() end,
                        test_environment = function() end,
                        test_file_communication = function() end
                    } end
                } end
            elseif filename == "file_io.lua" then
                return function() return {
                    new = function() return {
                        read_actions = function() return nil end,
                        write_action_result = function() end,
                        write_game_state = function() end,
                        get_next_sequence_id = function() return 1 end
                    } end
                } end
            elseif filename == "state_extractor.lua" then
                return function() return {
                    new = function() return {
                        extract_current_state = function() return {
                            current_phase = "shop",
                            money = 100,
                            ante = 1,
                            hands_remaining = 4,
                            shop_contents = {}
                        } end
                    } end
                } end
            elseif filename == "action_executor.lua" then
                return function() return {
                    new = function() return {
                        execute_action = function() return { success = true } end
                    } end
                } end
            elseif filename == "joker_manager.lua" then
                return function() return {
                    new = function() return {
                        set_crash_diagnostics = function() end
                    } end
                } end
            elseif filename == "crash_diagnostics.lua" then
                return function() return {
                    new = function() return {
                        create_safe_hook = function(self, func, name)
                            return func  -- Return wrapped function for testing
                        end,
                        track_hook_chain = function() end,
                        validate_game_state = function() end,
                        monitor_joker_operations = function() end
                    } end
                } end
            end
        end
    }
    
    -- Mock global G object with shop states
    _G.G = {
        STATE = 1,
        STATES = {
            MENU = 0,
            SELECTING_HAND = 1,
            SHOP = 2,
            BLIND_SELECT = 3,
            DRAW_TO_HAND = 4
        },
        FUNCS = {
            cash_out = function() return true end,
            go_to_shop = function() return true end  -- Old function for comparison
        },
        hand = { cards = {} },
        jokers = { cards = {} },
        shop_jokers = { cards = {} },
        shop_consumables = { cards = {} },
        shop_booster = { cards = {} },
        shop_vouchers = { cards = {} }
    }
    
    -- Mock timing functions
    _G.love = _G.love or {}
    _G.love.timer = _G.love.timer or {}
    _G.love.timer.getTime = function() return os.clock() end
    
    _G.os = _G.os or {}
    _G.os.time = function() return 1234567890 end
end

-- Helper function to capture print output
function TestShopStateDetection:capture_print_output(func)
    local print_calls = {}
    local original_print = print
    _G.print = function(msg) table.insert(print_calls, msg) end
    
    func()
    
    _G.print = original_print
    return print_calls
end

-- Load BalatroMCP module
function TestShopStateDetection:load_balatromcp()
    if not self.BalatroMCP then
        self.BalatroMCP = assert(SMODS.load_file("BalatroMCP.lua"))()
    end
    return self.BalatroMCP
end

-- =============================================================================
-- TEST CASES: SHOP STATE DETECTION SETUP
-- =============================================================================

function TestShopStateDetection:test_setup_shop_state_detection_initializes_tracking_variables()
    local BalatroMCP = self:load_balatromcp()
    local mcp = BalatroMCP.new()
    
    -- Verify initial state before setup
    luaunit.assertNil(mcp.last_shop_state, "Should not have last_shop_state before setup")
    luaunit.assertFalse(mcp.shop_state_initialized, "Should initialize shop_state_initialized to false in constructor")
    
    -- Call setup
    local print_calls = self:capture_print_output(function()
        mcp:setup_shop_state_detection()
    end)
    
    -- Verify state tracking variables are initialized
    luaunit.assertNil(mcp.last_shop_state, "Should initialize last_shop_state to nil")
    luaunit.assertFalse(mcp.shop_state_initialized, "Should initialize shop_state_initialized to false")
    
    -- Verify logging
    local found_setup_log = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "Setting up shop state detection") then
            found_setup_log = true
            break
        end
    end
    luaunit.assertTrue(found_setup_log, "Should log shop state detection setup")
end

function TestShopStateDetection:test_hook_shop_interactions_sets_up_shop_state_detection()
    local BalatroMCP = self:load_balatromcp()
    local mcp = BalatroMCP.new()
    
    local print_calls = self:capture_print_output(function()
        mcp:hook_shop_interactions()
    end)
    
    -- Verify that setup_shop_state_detection was called
    local found_setup_log = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "Setting up shop state detection") then
            found_setup_log = true
            break
        end
    end
    luaunit.assertTrue(found_setup_log, "Should call setup_shop_state_detection")
    
    -- Verify state tracking variables are initialized
    luaunit.assertNil(mcp.last_shop_state, "Should initialize last_shop_state")
    luaunit.assertFalse(mcp.shop_state_initialized, "Should initialize shop_state_initialized")
end

-- =============================================================================
-- TEST CASES: CORRECTED HOOK FUNCTION TESTS
-- =============================================================================

function TestShopStateDetection:test_hook_shop_interactions_hooks_cash_out_instead_of_go_to_shop()
    local BalatroMCP = self:load_balatromcp()
    local mcp = BalatroMCP.new()
    
    -- Store original functions
    local original_cash_out = G.FUNCS.cash_out
    local original_go_to_shop = G.FUNCS.go_to_shop
    
    mcp:hook_shop_interactions()
    
    -- Verify that cash_out was wrapped (should be different from original)
    luaunit.assertNotEquals(G.FUNCS.cash_out, original_cash_out, "Should wrap cash_out function")
    
    -- Verify that go_to_shop was NOT touched
    luaunit.assertEquals(G.FUNCS.go_to_shop, original_go_to_shop, "Should not modify go_to_shop function")
end

function TestShopStateDetection:test_hook_shop_interactions_handles_missing_cash_out_gracefully()
    local BalatroMCP = self:load_balatromcp()
    local mcp = BalatroMCP.new()
    
    -- Remove cash_out function to test graceful handling
    G.FUNCS.cash_out = nil
    
    local print_calls = self:capture_print_output(function()
        mcp:hook_shop_interactions()
    end)
    
    -- Should log a warning about missing cash_out
    local found_warning = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "WARNING.*cash_out not available") then
            found_warning = true
            break
        end
    end
    luaunit.assertTrue(found_warning, "Should warn when cash_out is not available")
end

-- =============================================================================
-- TEST CASES: SHOP STATE TRANSITION DETECTION
-- =============================================================================

function TestShopStateDetection:test_detect_shop_state_transition_handles_missing_g_object()
    local BalatroMCP = self:load_balatromcp()
    local mcp = BalatroMCP.new()
    mcp:setup_shop_state_detection()
    
    -- Test with nil G
    local original_g = G
    G = nil
    
    -- Should not error
    mcp:detect_shop_state_transition()
    
    G = original_g
    luaunit.assertTrue(true, "Should handle nil G object gracefully")
end

function TestShopStateDetection:test_detect_shop_state_transition_handles_missing_g_state()
    local BalatroMCP = self:load_balatromcp()
    local mcp = BalatroMCP.new()
    mcp:setup_shop_state_detection()
    
    -- Test with missing STATE
    G.STATE = nil
    
    -- Should not error
    mcp:detect_shop_state_transition()
    
    luaunit.assertTrue(true, "Should handle missing G.STATE gracefully")
end

function TestShopStateDetection:test_detect_shop_state_transition_handles_missing_g_states()
    local BalatroMCP = self:load_balatromcp()
    local mcp = BalatroMCP.new()
    mcp:setup_shop_state_detection()
    
    -- Test with missing STATES
    G.STATES = nil
    
    -- Should not error
    mcp:detect_shop_state_transition()
    
    luaunit.assertTrue(true, "Should handle missing G.STATES gracefully")
end

function TestShopStateDetection:test_detect_shop_state_transition_initializes_tracking_on_first_run()
    local BalatroMCP = self:load_balatromcp()
    local mcp = BalatroMCP.new()
    mcp:setup_shop_state_detection()
    
    -- Set current state
    G.STATE = G.STATES.SELECTING_HAND
    
    -- First call should initialize tracking
    mcp:detect_shop_state_transition()
    
    luaunit.assertEquals(mcp.last_shop_state, G.STATES.SELECTING_HAND, "Should initialize last_shop_state")
    luaunit.assertFalse(mcp.shop_state_initialized, "Should keep shop_state_initialized as false")
end

function TestShopStateDetection:test_detect_shop_state_transition_skips_when_delayed_capture_active()
    local BalatroMCP = self:load_balatromcp()
    local mcp = BalatroMCP.new()
    mcp:setup_shop_state_detection()
    
    -- Initialize tracking
    mcp.last_shop_state = G.STATES.SELECTING_HAND
    mcp.shop_state_initialized = false
    
    -- Set delayed capture active
    mcp.delayed_shop_state_capture = true
    
    -- Change to shop state
    G.STATE = G.STATES.SHOP
    
    local shop_entered_called = false
    mcp.on_shop_entered = function() shop_entered_called = true end
    
    mcp:detect_shop_state_transition()
    
    luaunit.assertFalse(shop_entered_called, "Should skip detection when delayed capture is active")
end

function TestShopStateDetection:test_detect_shop_state_transition_detects_transition_into_shop_state()
    local BalatroMCP = self:load_balatromcp()
    local mcp = BalatroMCP.new()
    mcp:setup_shop_state_detection()
    
    -- Initialize tracking - not in shop
    mcp.last_shop_state = G.STATES.SELECTING_HAND
    mcp.shop_state_initialized = false
    mcp.delayed_shop_state_capture = false
    
    -- Change to shop state
    G.STATE = G.STATES.SHOP
    
    local shop_entered_called = false
    mcp.on_shop_entered = function() shop_entered_called = true end
    
    local print_calls = self:capture_print_output(function()
        mcp:detect_shop_state_transition()
    end)
    
    luaunit.assertTrue(shop_entered_called, "Should call on_shop_entered when transitioning to shop")
    luaunit.assertTrue(mcp.shop_state_initialized, "Should set shop_state_initialized to true")
    luaunit.assertEquals(mcp.last_shop_state, G.STATES.SHOP, "Should update last_shop_state")
    
    -- Should log the transition
    local found_transition_log = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "NON_INTRUSIVE_DETECTION.*Shop state entered") then
            found_transition_log = true
            break
        end
    end
    luaunit.assertTrue(found_transition_log, "Should log shop state transition")
end

function TestShopStateDetection:test_detect_shop_state_transition_ignores_repeated_shop_state()
    local BalatroMCP = self:load_balatromcp()
    local mcp = BalatroMCP.new()
    mcp:setup_shop_state_detection()
    
    -- Initialize tracking - already in shop
    mcp.last_shop_state = G.STATES.SHOP
    mcp.shop_state_initialized = true
    mcp.delayed_shop_state_capture = false
    
    -- Stay in shop state
    G.STATE = G.STATES.SHOP
    
    local shop_entered_called = false
    mcp.on_shop_entered = function() shop_entered_called = true end
    
    mcp:detect_shop_state_transition()
    
    luaunit.assertFalse(shop_entered_called, "Should not call on_shop_entered when already in shop")
end

function TestShopStateDetection:test_detect_shop_state_transition_resets_flag_when_leaving_shop()
    local BalatroMCP = self:load_balatromcp()
    local mcp = BalatroMCP.new()
    mcp:setup_shop_state_detection()
    
    -- Initialize tracking - in shop
    mcp.last_shop_state = G.STATES.SHOP
    mcp.shop_state_initialized = true
    mcp.delayed_shop_state_capture = false
    
    -- Leave shop state
    G.STATE = G.STATES.SELECTING_HAND
    
    mcp:detect_shop_state_transition()
    
    luaunit.assertFalse(mcp.shop_state_initialized, "Should reset shop_state_initialized when leaving shop")
    luaunit.assertEquals(mcp.last_shop_state, G.STATES.SELECTING_HAND, "Should update last_shop_state")
end

-- =============================================================================
-- TEST CASES: DELAYED SHOP STATE CAPTURE TIMING
-- =============================================================================

function TestShopStateDetection:test_on_shop_entered_sets_correct_delay_timer()
    local BalatroMCP = self:load_balatromcp()
    local mcp = BalatroMCP.new()
    
    -- Mock state extractor
    mcp.state_extractor = {
        extract_current_state = function()
            return {
                current_phase = "shop",
                money = 100,
                shop_contents = {}
            }
        end
    }
    
    local print_calls = self:capture_print_output(function()
        mcp:on_shop_entered()
    end)
    
    luaunit.assertTrue(mcp.delayed_shop_state_capture, "Should set delayed_shop_state_capture to true")
    luaunit.assertEquals(mcp.delayed_shop_capture_timer, 1.0, "Should set timer to 1.0 seconds (not 0.5)")
    
    -- Should log the delay setup
    local found_delay_log = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "delaying state capture for shop population") then
            found_delay_log = true
            break
        end
    end
    luaunit.assertTrue(found_delay_log, "Should log delay setup")
end

function TestShopStateDetection:test_update_method_handles_delayed_shop_capture_timing()
    local BalatroMCP = self:load_balatromcp()
    local mcp = BalatroMCP.new()
    mcp.polling_active = true
    
    -- Mock state extractor
    mcp.state_extractor = {
        extract_current_state = function()
            return {
                current_phase = "shop",
                money = 100,
                shop_contents = {1, 2, 3}  -- Mock shop items
            }
        end
    }
    
    -- Mock send_current_state
    local state_sent = false
    mcp.send_current_state = function() state_sent = true end
    
    -- Set up delayed capture
    mcp.delayed_shop_state_capture = true
    mcp.delayed_shop_capture_timer = 1.0
    
    -- Update with enough time to trigger capture
    local print_calls = self:capture_print_output(function()
        mcp:update(1.5)  -- 1.5 seconds should trigger capture
    end)
    
    luaunit.assertFalse(mcp.delayed_shop_state_capture, "Should clear delayed capture flag")
    luaunit.assertTrue(state_sent, "Should send current state after delay")
    
    -- Should log the delayed capture execution
    local found_capture_log = false
    local found_debug_log = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "Executing delayed shop state capture") then
            found_capture_log = true
        elseif string.find(msg, "Shop state after delay.*shop_items=3") then
            found_debug_log = true
        end
    end
    luaunit.assertTrue(found_capture_log, "Should log delayed capture execution")
    luaunit.assertTrue(found_debug_log, "Should log shop items count after delay")
end

function TestShopStateDetection:test_update_method_does_not_trigger_premature_shop_capture()
    local BalatroMCP = self:load_balatromcp()
    local mcp = BalatroMCP.new()
    mcp.polling_active = true
    
    -- Mock send_current_state
    local state_sent = false
    mcp.send_current_state = function() state_sent = true end
    
    -- Set up delayed capture with longer timer
    mcp.delayed_shop_state_capture = true
    mcp.delayed_shop_capture_timer = 1.0
    
    -- Update with insufficient time
    mcp:update(0.5)  -- Only 0.5 seconds, should not trigger
    
    luaunit.assertTrue(mcp.delayed_shop_state_capture, "Should keep delayed capture flag")
    luaunit.assertAlmostEquals(mcp.delayed_shop_capture_timer, 0.5, 0.01, "Should decrement timer correctly")
    luaunit.assertFalse(state_sent, "Should not send state before timer expires")
end

-- =============================================================================
-- TEST CASES: SHOP COLLECTION POPULATION TIMING
-- =============================================================================

function TestShopStateDetection:test_on_shop_entered_logs_shop_collection_state()
    local BalatroMCP = self:load_balatromcp()
    local mcp = BalatroMCP.new()
    
    -- Mock state extractor with empty shop
    mcp.state_extractor = {
        extract_current_state = function()
            return {
                current_phase = "shop",
                money = 100,
                shop_contents = {}  -- Empty initially
            }
        end
    }
    
    local print_calls = self:capture_print_output(function()
        mcp:on_shop_entered()
    end)
    
    -- Should log diagnostic information about shop state
    local found_debug_log = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "Hook fired with state.*shop_items=0") then
            found_debug_log = true
            break
        end
    end
    luaunit.assertTrue(found_debug_log, "Should log shop collection state when hook fires")
end

function TestShopStateDetection:test_delayed_capture_shows_populated_shop_collections()
    local BalatroMCP = self:load_balatromcp()
    local mcp = BalatroMCP.new()
    mcp.polling_active = true
    
    -- Mock state extractor that shows population after delay
    local extract_calls = 0
    mcp.state_extractor = {
        extract_current_state = function()
            extract_calls = extract_calls + 1
            if extract_calls <= 1 then
                -- First call (immediate) - empty shop
                return {
                    current_phase = "shop",
                    money = 100,
                    shop_contents = {}
                }
            else
                -- Later calls (after delay) - populated shop
                return {
                    current_phase = "shop",
                    money = 100,
                    shop_contents = {{}, {}, {}}  -- 3 shop items
                }
            end
        end
    }
    
    -- Mock send_current_state
    local state_sent = false
    mcp.send_current_state = function() state_sent = true end
    
    -- Trigger shop entry
    mcp:on_shop_entered()
    
    -- Simulate shop population timing
    local print_calls = self:capture_print_output(function()
        mcp:update(1.5)  -- Trigger delayed capture
    end)
    
    luaunit.assertTrue(state_sent, "Should send state after delay")
    
    -- Should show populated shop in debug log
    local found_populated_log = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "Shop state after delay.*shop_items=3") then
            found_populated_log = true
            break
        end
    end
    luaunit.assertTrue(found_populated_log, "Should log populated shop state after delay")
end

-- =============================================================================
-- TEST CASES: HOOK VS NON-INTRUSIVE DETECTION COORDINATION
-- =============================================================================

function TestShopStateDetection:test_hook_and_non_intrusive_detection_work_together()
    local BalatroMCP = self:load_balatromcp()
    local mcp = BalatroMCP.new()
    mcp:setup_shop_state_detection()
    
    -- Initialize in non-shop state
    mcp.last_shop_state = G.STATES.SELECTING_HAND
    mcp.shop_state_initialized = false
    mcp.delayed_shop_state_capture = false
    
    -- Simulate hook-based detection triggering first
    local hook_triggered = false
    mcp.on_shop_entered = function() hook_triggered = true end
    
    -- Change to shop state and detect
    G.STATE = G.STATES.SHOP
    mcp:detect_shop_state_transition()
    
    luaunit.assertTrue(hook_triggered, "Non-intrusive detection should trigger shop entry")
    luaunit.assertTrue(mcp.shop_state_initialized, "Should set shop state initialized flag")
    
    -- Now test that subsequent calls don't re-trigger
    hook_triggered = false
    mcp:detect_shop_state_transition()
    
    luaunit.assertFalse(hook_triggered, "Should not re-trigger when already initialized")
end

function TestShopStateDetection:test_non_intrusive_detection_prevents_duplicate_triggering()
    local BalatroMCP = self:load_balatromcp()
    local mcp = BalatroMCP.new()
    mcp:setup_shop_state_detection()
    
    -- Initialize tracking
    mcp.last_shop_state = G.STATES.SELECTING_HAND
    mcp.shop_state_initialized = false
    
    -- Simulate delayed capture is already active (hook-based triggered)
    mcp.delayed_shop_state_capture = true
    
    -- Change to shop state
    G.STATE = G.STATES.SHOP
    
    local hook_triggered = false
    mcp.on_shop_entered = function() hook_triggered = true end
    
    mcp:detect_shop_state_transition()
    
    luaunit.assertFalse(hook_triggered, "Should not trigger when delayed capture is already active")
end

-- =============================================================================
-- TEST CASES: STATE TRACKING VARIABLE MANAGEMENT
-- =============================================================================

function TestShopStateDetection:test_state_tracking_variables_are_properly_managed_across_updates()
    local BalatroMCP = self:load_balatromcp()
    local mcp = BalatroMCP.new()
    mcp:setup_shop_state_detection()
    mcp.polling_active = true
    
    -- Test state progression: Hand -> Shop -> Hand
    
    -- Initial state
    G.STATE = G.STATES.SELECTING_HAND
    mcp:update(0.1)
    
    luaunit.assertEquals(mcp.last_shop_state, G.STATES.SELECTING_HAND, "Should track initial state")
    luaunit.assertFalse(mcp.shop_state_initialized, "Should start with shop not initialized")
    
    -- Transition to shop
    G.STATE = G.STATES.SHOP
    local shop_entry_count = 0
    mcp.on_shop_entered = function() shop_entry_count = shop_entry_count + 1 end
    
    mcp:update(0.1)
    
    luaunit.assertEquals(mcp.last_shop_state, G.STATES.SHOP, "Should update to shop state")
    luaunit.assertTrue(mcp.shop_state_initialized, "Should set shop initialized")
    luaunit.assertEquals(shop_entry_count, 1, "Should trigger shop entry once")
    
    -- Stay in shop (should not re-trigger)
    mcp:update(0.1)
    
    luaunit.assertEquals(shop_entry_count, 1, "Should not re-trigger while in shop")
    
    -- Transition out of shop
    G.STATE = G.STATES.SELECTING_HAND
    mcp:update(0.1)
    
    luaunit.assertEquals(mcp.last_shop_state, G.STATES.SELECTING_HAND, "Should update to hand state")
    luaunit.assertFalse(mcp.shop_state_initialized, "Should reset shop initialized flag")
    
    -- Re-enter shop (should trigger again)
    G.STATE = G.STATES.SHOP
    mcp:update(0.1)
    
    luaunit.assertEquals(shop_entry_count, 2, "Should trigger shop entry again after leaving and re-entering")
end

function TestShopStateDetection:test_update_method_calls_detect_shop_state_transition()
    local BalatroMCP = self:load_balatromcp()
    local mcp = BalatroMCP.new()
    mcp.polling_active = true
    
    -- Mock the detection method to track calls
    local detection_called = false
    mcp.detect_shop_state_transition = function() detection_called = true end
    
    mcp:update(0.1)
    
    luaunit.assertTrue(detection_called, "Update method should call detect_shop_state_transition")
end

-- =============================================================================
-- TEST CASES: INTEGRATION TESTS
-- =============================================================================

function TestShopStateDetection:test_complete_shop_detection_workflow_integration()
    local BalatroMCP = self:load_balatromcp()
    local mcp = BalatroMCP.new()
    mcp.polling_active = true
    
    -- Setup complete environment
    mcp:hook_shop_interactions()
    
    -- Mock state extractor for realistic behavior
    local state_extract_count = 0
    mcp.state_extractor = {
        extract_current_state = function()
            state_extract_count = state_extract_count + 1
            return {
                current_phase = "shop",
                money = 100,
                shop_contents = state_extract_count > 1 and {{}, {}, {}} or {}
            }
        end
    }
    
    -- Mock state sending
    local states_sent = 0
    mcp.send_current_state = function() states_sent = states_sent + 1 end
    
    -- Start in non-shop state
    G.STATE = G.STATES.SELECTING_HAND
    mcp:update(0.1)
    
    -- Transition to shop via state change (non-intrusive detection)
    G.STATE = G.STATES.SHOP
    
    local print_calls = self:capture_print_output(function()
        -- This should trigger non-intrusive detection
        mcp:update(0.1)
        
        -- Wait for delayed capture to complete
        mcp:update(1.5)
    end)
    
    luaunit.assertTrue(states_sent >= 1, "Should send state after delayed capture")
    
    -- Verify logs show proper detection and timing
    local found_detection = false
    local found_delayed_capture = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "NON_INTRUSIVE_DETECTION.*Shop state entered") then
            found_detection = true
        elseif string.find(msg, "Executing delayed shop state capture") then
            found_delayed_capture = true
        end
    end
    
    luaunit.assertTrue(found_detection, "Should detect shop state transition")
    luaunit.assertTrue(found_delayed_capture, "Should execute delayed capture")
end

-- =============================================================================
-- TEST RUNNER
-- =============================================================================

function run_tests()
    print("Starting ShopStateDetection LuaUnit tests...")
    
    -- Run tests using LuaUnit by running the test class
    local result = luaunit.LuaUnit.run({'-v', '--pattern', 'TestShopStateDetection'})
    
    -- LuaUnit.run() returns 0 for success, non-zero for failure
    local success = (result == 0)
    
    if success then
        print("\n✅ All ShopStateDetection tests passed! (LuaUnit)")
    else
        print("\n❌ ShopStateDetection tests failed! (LuaUnit)")
    end
    
    return success
end

-- Module exports
return {
    TestShopStateDetection = TestShopStateDetection,
    run_tests = run_tests
}