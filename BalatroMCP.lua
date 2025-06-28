-- Main Balatro MCP mod file
-- Integrates all components and manages communication with MCP server

--- STEAMMODDED HEADER
--- MOD_NAME: BalatroMCP
--- MOD_ID: BalatroMCP
--- MOD_AUTHOR: [MCP Integration]
--- MOD_DESCRIPTION: Enables AI agent interaction with Balatro through MCP protocol

print("BalatroMCP: MAIN FILE LOADING STARTED")

-- Transport Configuration
-- Now using async file transport exclusively for non-blocking I/O
local ASYNC_FILE_TRANSPORT_CONFIG = {
    base_path = "shared",  -- Default file transport path
    enable_async = true    -- Enable async operations when threading available
}

-- Function to allow external configuration override
local function configure_transport(file_config)
    if file_config and type(file_config) == "table" then
        for key, value in pairs(file_config) do
            ASYNC_FILE_TRANSPORT_CONFIG[key] = value
        end
    end
end

-- Export configuration function for external use
_G.BalatroMCP_Configure = configure_transport

local DebugLogger = nil
local debug_success, debug_error = pcall(function()
    DebugLogger = assert(SMODS.load_file("debug_logger.lua"))()
    print("BalatroMCP: DebugLogger loaded successfully")
end)
if not debug_success then
    print("BalatroMCP: DebugLogger load failed: " .. tostring(debug_error))
end

local MessageTransport = nil
local transport_success, transport_error = pcall(function()
    MessageTransport = assert(SMODS.load_file("interfaces/message_transport.lua"))()
    print("BalatroMCP: MessageTransport interface loaded successfully")
end)
if not transport_success then
    print("BalatroMCP: MessageTransport interface load failed: " .. tostring(transport_error))
end

local FileTransport = nil
local file_transport_success, file_transport_error = pcall(function()
    FileTransport = assert(SMODS.load_file("transports/file_transport.lua"))()
    print("BalatroMCP: FileTransport loaded successfully")
end)
if not file_transport_success then
    print("BalatroMCP: FileTransport load failed: " .. tostring(file_transport_error))
end

-- HttpsTransport removed - using async file transport exclusively

local MessageManager = nil
local message_manager_success, message_manager_error = pcall(function()
    MessageManager = assert(SMODS.load_file("message_manager.lua"))()
    print("BalatroMCP: MessageManager loaded successfully")
end)
if not message_manager_success then
    print("BalatroMCP: MessageManager load failed: " .. tostring(message_manager_error))
end

local StateExtractor = nil
local state_success, state_error = pcall(function()
    StateExtractor = assert(SMODS.load_file("state_extractor/state_extractor.lua"))()
    print("BalatroMCP: StateExtractor loaded successfully")
end)
if not state_success then
    print("BalatroMCP: StateExtractor load failed: " .. tostring(state_error))
end

local ActionExecutor = nil
local action_success, action_error = pcall(function()
    ActionExecutor = assert(SMODS.load_file("action_executor.lua"))()
    print("BalatroMCP: ActionExecutor loaded successfully")
end)
if not action_success then
    print("BalatroMCP: ActionExecutor load failed: " .. tostring(action_error))
end

local JokerManager = nil
local joker_success, joker_error = pcall(function()
    JokerManager = assert(SMODS.load_file("joker_manager.lua"))()
    print("BalatroMCP: JokerManager loaded successfully")
end)
if not joker_success then
    print("BalatroMCP: JokerManager load failed: " .. tostring(joker_error))
end

local CrashDiagnostics = nil
local crash_success, crash_error = pcall(function()
    CrashDiagnostics = assert(SMODS.load_file("crash_diagnostics.lua"))()
    print("BalatroMCP: CrashDiagnostics loaded successfully")
end)
if not crash_success then
    print("BalatroMCP: CrashDiagnostics load failed: " .. tostring(crash_error))
end

print("BalatroMCP: MODULE LOADING SUMMARY:")
print("  DebugLogger: " .. (debug_success and "SUCCESS" or "FAILED"))
print("  MessageTransport: " .. (transport_success and "SUCCESS" or "FAILED"))
print("  FileTransport: " .. (file_transport_success and "SUCCESS" or "FAILED"))
print("  MessageManager: " .. (message_manager_success and "SUCCESS" or "FAILED"))
print("  StateExtractor: " .. (state_success and "SUCCESS" or "FAILED"))
print("  ActionExecutor: " .. (action_success and "SUCCESS" or "FAILED"))
print("  JokerManager: " .. (joker_success and "SUCCESS" or "FAILED"))
print("  CrashDiagnostics: " .. (crash_success and "SUCCESS" or "FAILED"))
print("  Transport Selection: ASYNC_FILE")

local BalatroMCP = {}
BalatroMCP.__index = BalatroMCP

function BalatroMCP.new()
    local self = setmetatable({}, BalatroMCP)
    
    self.debug_logger = DebugLogger.new()
    self.debug_logger:info("=== BALATRO MCP INITIALIZATION STARTED ===", "INIT")
    
    self.debug_logger:test_environment()
    
    -- Initialize crash diagnostics
    if CrashDiagnostics then
        self.crash_diagnostics = CrashDiagnostics.new()
        self.debug_logger:info("CrashDiagnostics component initialized successfully", "INIT")
    else
        self.debug_logger:error("CrashDiagnostics module not available", "INIT")
    end
    
    local init_success = true
    
    -- Initialize async file transport exclusively
    if not FileTransport then
        error("FileTransport module not available")
    end
    
    -- Use configurable file transport settings
    local file_config = {}
    for key, value in pairs(ASYNC_FILE_TRANSPORT_CONFIG) do
        file_config[key] = value
    end
    
    self.transport = FileTransport.new(file_config.base_path)
    self.file_transport = self.transport  -- Backward compatibility reference
    self.transport_type = "ASYNC_FILE"
    
    -- Log async capability status
    if self.transport.async_enabled then
        self.debug_logger:info("Async FileTransport initialized with threading support", "INIT")
    else
        self.debug_logger:info("FileTransport initialized with synchronous fallback (no threading)", "INIT")
    end
    
    if not MessageManager then
        error("MessageManager module not available - failed to load during startup")
    end
    
    self.message_manager = MessageManager.new(self.transport, "BALATRO_MCP")
    self.debug_logger:info("MessageManager component initialized successfully", "INIT")
    
    local state_success, state_error = pcall(function()
        if not StateExtractor then
            error("StateExtractor module not available - failed to load during startup")
        end
        
        self.state_extractor = StateExtractor.new()
        
        if self.crash_diagnostics then
            self.crash_diagnostics:create_safe_state_extraction_wrapper(self.state_extractor)
            self.debug_logger:info("StateExtractor wrapped with crash diagnostics", "INIT")
        end
        
        self.debug_logger:info("StateExtractor component initialized successfully", "INIT")
    end)
    
    if not state_success then
        self.debug_logger:error("StateExtractor initialization failed: " .. tostring(state_error), "INIT")
        init_success = false
    end
    
    local joker_success, joker_error = pcall(function()
        if not JokerManager then
            error("JokerManager module not available - failed to load during startup")
        end
        
        self.joker_manager = JokerManager.new()
        self.joker_manager:set_crash_diagnostics(self.crash_diagnostics)
        self.debug_logger:info("JokerManager component initialized successfully with crash diagnostics", "INIT")
    end)
    
    if not joker_success then
        self.debug_logger:error("JokerManager initialization failed: " .. tostring(joker_error), "INIT")
        init_success = false
    end
    
    local action_success, action_error = pcall(function()
        if not ActionExecutor then
            error("ActionExecutor module not available - failed to load during startup")
        end
        
        self.action_executor = ActionExecutor.new(self.state_extractor, self.joker_manager)
        self.debug_logger:info("ActionExecutor component initialized successfully", "INIT")
    end)
    
    if not action_success then
        self.debug_logger:error("ActionExecutor initialization failed: " .. tostring(action_error), "INIT")
        init_success = false
    end
    
    self.last_state_hash = nil
    self.polling_active = false
    self.update_timer = 0
    self.update_interval = 0.5 -- Check for state updates every 0.5 seconds
    
    -- Add separate action polling timer
    self.action_polling_timer = 0
    self.action_polling_interval = 1.5 -- Poll for actions every 1.5 seconds
    
    self.processing_action = false
    self.last_action_sequence = 0
    
    self.pending_state_extraction = false
    self.pending_action_result = nil
    
    -- Hook lifecycle management - store original function references
    self.original_functions = {}
    
    -- Extraction delays for event system timing
    self.extraction_delays = {
        hand_action = 0.1,      -- 100ms delay for hand play/discard
        shop_entry = 0.2,       -- 200ms delay for shop content population
        shop_exit = 0.1,        -- 100ms delay for shop exit
        blind_selection = 0.15, -- 150ms delay for blind selection
        round_completion = 0.25, -- 250ms delay for round end processing
        ante_advancement = 0.3,  -- 300ms delay for ante progression
        hand_dealing = 0.2,     -- 200ms delay for hand dealing completion
        game_over = 0.2         -- 200ms delay for game over state
    }
    
    if init_success then
        self.debug_logger:test_file_communication()
    end
    
    if init_success then
        self.debug_logger:info("BalatroMCP: Mod initialized successfully", "INIT")
        print("BalatroMCP: Mod initialized successfully")
    else
        self.debug_logger:error("BalatroMCP: Mod initialization FAILED - check debug logs", "INIT")
        print("BalatroMCP: Mod initialization FAILED - check debug logs")
    end
    
    return self
end

-- MCP Worker Thread Code
local MCP_WORKER_CODE = [[
local love = require('love')
require('love.filesystem')

-- Worker thread for handling MCP operations
local state_channel = love.thread.getChannel('mcp_state_updates')
local action_channel = love.thread.getChannel('mcp_action_requests') 
local result_channel = love.thread.getChannel('mcp_action_results')

-- Simple state tracking
local last_processed_sequence = 0
local polling_interval = 0.125 -- 8 times per second

print("BalatroMCP Worker: Thread started")

while true do
    -- Check for exit signal
    local exit_signal = love.thread.getChannel('mcp_exit'):pop()
    if exit_signal then
        print("BalatroMCP Worker: Exit signal received")
        break
    end
    
    -- Process state updates from main thread
    local state_data = state_channel:pop()
    if state_data then
        -- Write state to file (synchronous in worker thread is fine)
        local state_json = state_data.json
        if state_json then
            local success, err = pcall(function()
                love.filesystem.write("shared/game_state.json", state_json)
            end)
            if not success then
                print("BalatroMCP Worker: State write error: " .. tostring(err))
            end
        end
    end
    
    -- Check for pending actions
    local action_success, action_content = pcall(function()
        return love.filesystem.read("shared/actions.json")
    end)
    
    if action_success and action_content then
        -- Parse and send action to main thread for execution
        local action_data
        local parse_success, parse_error = pcall(function()
            action_data = love.data and love.data.decode and love.data.decode("data", "base64", action_content) or action_content
            if type(action_data) == "string" then
                -- Try to parse as JSON (simplified parsing)
                -- In a real implementation, you'd use a proper JSON parser
                action_data = {raw = action_content}
            end
        end)
        
        if parse_success and action_data then
            action_channel:push({
                data = action_data,
                timestamp = os.time()
            })
        end
    end
    
    -- Sleep to prevent busy waiting (simple busy wait since love.timer not available in thread)
    local start_time = os.clock()
    while os.clock() - start_time < polling_interval do
        -- Simple busy wait
    end
end

print("BalatroMCP Worker: Thread ending")
]]

function BalatroMCP:start_mcp_worker_thread()
    if not love or not love.thread then
        print("BalatroMCP: Love2D threading not available, falling back to synchronous mode")
        self.threaded_mode = false
        return
    end
    
    print("BalatroMCP: Starting MCP worker thread")
    
    -- Create channels for communication
    self.state_channel = love.thread.getChannel('mcp_state_updates')
    self.action_channel = love.thread.getChannel('mcp_action_requests')
    self.result_channel = love.thread.getChannel('mcp_action_results')
    self.exit_channel = love.thread.getChannel('mcp_exit')
    
    -- Create and start worker thread
    self.mcp_worker = love.thread.newThread(MCP_WORKER_CODE)
    self.mcp_worker:start()
    self.threaded_mode = true
    
    print("BalatroMCP: MCP worker thread started successfully")
end

function BalatroMCP:send_state_to_worker()
    if not self.threaded_mode or not self.state_channel then
        -- Fallback to original method if threading not available
        self:check_and_update_state()
        return
    end
    
    -- Extract current state and send to worker thread
    local current_state = self.state_extractor:extract_current_state()
    if current_state then
        -- Convert state to JSON (simplified)
        local state_json = self:serialize_state_to_json(current_state)
        
        -- Send to worker thread (non-blocking)
        local send_success = self.state_channel:push({
            json = state_json,
            timestamp = love.timer and love.timer.getTime() or os.time(),
            sequence = self.message_manager:get_next_sequence_id()
        })
        
        if not send_success then
            print("BalatroMCP: Warning - Failed to send state to worker thread")
        end
    end
    
    -- Check for action results from worker thread
    self:process_worker_responses()
end

function BalatroMCP:process_worker_responses()
    if not self.threaded_mode or not self.action_channel then
        return
    end
    
    -- Check for pending actions from worker
    local action_request = self.action_channel:pop()
    if action_request then
        print("BalatroMCP: Received action request from worker thread")
        -- Process action in main thread (since it needs access to game state)
        self:process_pending_actions()
    end
end

function BalatroMCP:serialize_state_to_json(state)
    -- Use proper JSON library to serialize ALL state data
    if not self.message_manager or not self.message_manager.json then
        return "{}"
    end
    
    local encode_success, json_string = pcall(self.message_manager.json.encode, state)
    if not encode_success then
        -- Fallback to minimal state if full serialization fails
        return '{"money":' .. (state.money or 0) .. ',"ante":' .. (state.ante or 1) .. ',"error":"serialization_failed"}'
    end
    
    return json_string
end

function BalatroMCP:defer_state_extraction(extraction_type, context_data)
    -- Use Balatro's Event Manager for deferred state extraction
    local delay = self.extraction_delays[extraction_type] or 0.1
    local context = context_data or {}
    
    if not G or not G.E_MANAGER then
        print("BalatroMCP: ERROR - G.E_MANAGER not available, falling back to immediate extraction")
        self:execute_deferred_extraction({type = extraction_type, context = context})
        return
    end
    
    print("BalatroMCP: Scheduling " .. extraction_type .. " extraction via G.E_MANAGER (delay: " .. delay .. "s)")
    
    -- Create event for deferred extraction using Balatro's Event System
    G.E_MANAGER:add_event(Event({
        trigger = "after",
        delay = delay,
        blockable = false,
        blocking = false,
        func = function()
            print("BalatroMCP: Processing event-based " .. extraction_type .. " extraction")
            self:execute_deferred_extraction({
                type = extraction_type,
                context = context
            })
        end
    }))
end


function BalatroMCP:execute_deferred_extraction(extraction)
    local context = extraction.context
    
    -- ADD DIAGNOSTIC LOGGING FOR STATE TRANSMISSION
    print("BalatroMCP: [DEBUG_STALE_STATE] Executing deferred extraction: " .. extraction.type)
    print("BalatroMCP: [DEBUG_STALE_STATE] Transport type: " .. (self.transport_type or "UNKNOWN"))
    print("BalatroMCP: [DEBUG_STALE_STATE] Transport available: " .. tostring(self.transport and self.transport:is_available() or false))
    
    if extraction.type == "hand_action" then
        print("BalatroMCP: [DEBUG_STALE_STATE] Sending current state for hand_action")
        self:send_current_state()
        if context.action_type then
            self:send_status_update(context.action_type .. "_completed", context)
        end
        
    elseif extraction.type == "shop_entry" then
        local current_state = self.state_extractor:extract_current_state()
        local shop_items = current_state and current_state.shop_contents and #current_state.shop_contents or 0
        print("BalatroMCP: Deferred shop entry - shop items: " .. shop_items)
        
        print("BalatroMCP: [DEBUG_STALE_STATE] Sending current state for shop_entry")
        self:send_current_state()
        self:send_status_update("shop_entered", {
            shop_item_count = shop_items,
            money = current_state and current_state.money or 0,
            phase = current_state and current_state.current_phase or "unknown"
        })
        
    elseif extraction.type == "shop_exit" then
        self:send_current_state()
        self:send_status_update("shop_exited", {})
        
    elseif extraction.type == "blind_selection" then
        self:send_current_state()
        
    elseif extraction.type == "round_completion" then
        self:send_current_state()
        self:send_status_update("round_completed", context)
        
    elseif extraction.type == "ante_advancement" then
        self:send_current_state()
        self:send_status_update("ante_advanced", context)
        
    elseif extraction.type == "hand_dealing" then
        local current_state = self.state_extractor:extract_current_state()
        local hand_count = current_state and current_state.hand_cards and #current_state.hand_cards or 0
        print("BalatroMCP: Deferred hand dealing - hand size: " .. hand_count)
        
        self:send_current_state()
        self:send_status_update("hand_dealt", {
            hand_size = hand_count
        })
        
    elseif extraction.type == "game_over" then
        self:send_current_state()
        self:send_status_update("game_over", context)
        
    else
        -- Default: just send current state
        self:send_current_state()
    end
end

function BalatroMCP:start()
    print("BalatroMCP: Starting MCP integration")
    
    self.polling_active = true
    
    -- Initialize threading for MCP operations
    self:start_mcp_worker_thread()
    
    -- Create lightweight event that just passes game state to worker thread
    local event
    event = Event {
        blockable = false,
        blocking = false,
        pause_force = true,
        no_delete = true,
        trigger = "after",
        delay = 0.125,
        timer = "UPTIME",
        func = function()
            self:send_state_to_worker()
            event.start_timer = false
        end
    }
    G.E_MANAGER:add_event(event)
    
    self:send_current_state()
    
    print("BalatroMCP: MCP integration started with threaded state checking")
end

function BalatroMCP:stop()
    print("BalatroMCP: Stopping MCP integration")
    
    self.polling_active = false
    
    -- Stop MCP worker thread
    if self.threaded_mode and self.exit_channel then
        print("BalatroMCP: Sending exit signal to worker thread")
        self.exit_channel:push(true)
        
        -- Wait a bit for thread to exit gracefully
        if self.mcp_worker then
            -- Give thread time to exit (simple wait)
            local wait_start = os.clock()
            while os.clock() - wait_start < 0.1 do
                -- Simple wait
            end
            self.mcp_worker = nil
        end
        
        self.threaded_mode = false
    end
    
    -- Cleanup async file transport resources (threads, channels)
    if self.transport and self.transport.cleanup then
        self.transport:cleanup()
    end
    
    print("BalatroMCP: MCP integration stopped")
end












function BalatroMCP:check_and_update_state()
    if not self.polling_active then
        return
    end
    
    -- Update async file transport to process responses
    if self.transport and self.transport.update then
        self.transport:update()
    end
    
    -- Handle action polling
    if self.transport and self.transport:is_available() and G.STATE ~= -1 then
        print("BalatroMCP: ACTION_POLLING - Checking for pending actions")
        self:process_pending_actions()
    end
    
    -- Handle state updates
    if G.STATE ~= -1 then
        if self.crash_diagnostics then
            self.crash_diagnostics:monitor_joker_operations()
        end
        
        if self.pending_state_extraction then
            print("BalatroMCP: PROCESSING_DELAYED_EXTRACTION")
            self:handle_delayed_state_extraction()
        end
        
        self:check_and_send_state_update()
    end
end

function BalatroMCP:process_pending_actions()
    if self.processing_action then
        -- Safety timeout: reset stuck processing flag after 10 seconds
        -- This prevents indefinite blocking when action processing gets stuck due to game engine issues
        if not self.processing_action_start_time then
            print("BalatroMCP: WARNING - Inconsistent state detected, resetting processing flags")
            self.processing_action = false
            self.pending_state_extraction = false
            self.processing_action_start_time = nil
            return  -- Skip this iteration, retry next time
        elseif os.time() - self.processing_action_start_time > 10 then
            print("BalatroMCP: WARNING - Processing action timeout, resetting stuck flag")
            self.processing_action = false
            self.pending_state_extraction = false
            self.processing_action_start_time = nil
            return  -- Skip this iteration, retry next time
        else
            print("BalatroMCP: ACTION_POLLING - Skipping, already processing action")
            return
        end
    end
    
    print("BalatroMCP: ACTION_POLLING - Calling message_manager:read_actions()")
    local message_data = self.message_manager:read_actions()
    if not message_data then
        print("BalatroMCP: ACTION_POLLING - No actions available")
        return
    end
    
    print("BalatroMCP: ACTION_POLLING - Actions received, processing...")
    
    -- Extract action data from message wrapper
    local action_data = message_data.data
    if not action_data then
        print("BalatroMCP: ERROR - No action data in message")
        return
    end
    
    local sequence = action_data.sequence_id or 0
    if sequence <= self.last_action_sequence then
        return
    end
    
    self.processing_action = true
    self.processing_action_start_time = os.time()  -- Set timeout start time when beginning processing
    self.last_action_sequence = sequence
    
    print("BalatroMCP: Processing action [seq=" .. sequence .. "]: " .. (action_data.action_type or "unknown"))
    
    local state_before = self.state_extractor:extract_current_state()
    local phase_before = state_before and state_before.current_phase or "unknown"
    local money_before = state_before and state_before.money or "unknown"
    print("BalatroMCP: DEBUG - State BEFORE action: phase=" .. phase_before .. ", money=" .. tostring(money_before))
    
    local result = self.action_executor:execute_action(action_data)
    
    local state_after = self.state_extractor:extract_current_state()
    local phase_after = state_after and state_after.current_phase or "unknown"
    local money_after = state_after and state_after.money or "unknown"
    print("BalatroMCP: DEBUG - State IMMEDIATELY after action: phase=" .. phase_after .. ", money=" .. tostring(money_after))
    
    -- Send action result immediately and reset processing flag
    local action_result = {
        sequence = sequence,
        action_type = action_data.action_type,
        success = result.success,
        error_message = result.error_message,
        timestamp = os.time(),
        new_state = state_after
    }
    
    self.message_manager:write_action_result(action_result)
    
    if result.success then
        print("BalatroMCP: Action completed successfully")
    else
        print("BalatroMCP: Action failed: " .. (result.error_message or "Unknown error"))
    end
    
    -- CRITICAL FIX: Reset processing flag immediately in main thread
    -- This ensures cleanup happens regardless of threading mode
    print("BalatroMCP: Resetting processing flag (threading-safe cleanup)")
    self.processing_action = false
    self.processing_action_start_time = nil
    self.pending_state_extraction = false
end

function BalatroMCP:handle_delayed_state_extraction()
    print("BalatroMCP: Processing delayed state extraction")
    
    local current_state = self.state_extractor:extract_current_state()
    local phase = current_state and current_state.current_phase or "unknown"
    local money = current_state and current_state.money or "unknown"
    print("BalatroMCP: DEBUG - State AFTER delay: phase=" .. phase .. ", money=" .. tostring(money))
    
    if self.pending_action_result then
        self.pending_action_result.new_state = current_state
        
        self.message_manager:write_action_result(self.pending_action_result)
        print("BalatroMCP: Delayed action result sent with updated state")
        
        self.pending_action_result = nil
    end
    
    self.pending_state_extraction = false
    self.processing_action = false
    self.processing_action_start_time = nil
end

function BalatroMCP:check_and_send_state_update()
    local current_state = self.state_extractor:extract_current_state()
    
    local g_state = G and G.STATE or "NIL"
    local phase = current_state.current_phase or "NIL"
    local money = current_state.money or "NIL"
    local ante = current_state.ante or "NIL"
    
    -- HACK: Always send state update since async transport should handle it efficiently
    print("BalatroMCP: ALWAYS_SEND_HACK - Sending state update (phase=" .. phase .. ", money=" .. tostring(money) .. ")")
    self:send_state_update(current_state)
end

function BalatroMCP:send_current_state()
    local current_state = self.state_extractor:extract_current_state()
    if current_state then
        self:send_state_update(current_state)
    end
end

function BalatroMCP:send_state_update(state)
    -- ADD COMPREHENSIVE DIAGNOSTIC LOGGING FOR STATE TRANSMISSION
    print("BalatroMCP: [DEBUG_STALE_STATE] === ATTEMPTING STATE TRANSMISSION ===")
    print("BalatroMCP: [DEBUG_STALE_STATE] Transport type: " .. (self.transport_type or "UNKNOWN"))
    print("BalatroMCP: [DEBUG_STALE_STATE] Transport object: " .. tostring(self.transport))
    
    if self.transport then
        local available = self.transport:is_available()
        print("BalatroMCP: [DEBUG_STALE_STATE] Transport availability: " .. tostring(available))
        
        if not available then
            print("BalatroMCP: [DEBUG_STALE_STATE] *** TRANSPORT NOT AVAILABLE - STATE WILL NOT BE SENT ***")
        end
    else
        print("BalatroMCP: [DEBUG_STALE_STATE] *** NO TRANSPORT OBJECT - STATE CANNOT BE SENT ***")
    end
    
    -- Consolidate all game data into a single comprehensive message
    -- to prevent data flow confusion between hand_cards, deck_cards, and remaining_deck
    
    local comprehensive_state = {
        -- Core game state (ante, money, phase, etc.)
        core_state = {
            session_id = state.session_id,
            current_phase = state.current_phase,
            ante = state.ante,
            money = state.money,
            hands_remaining = state.hands_remaining,
            discards_remaining = state.discards_remaining,
            available_actions = state.available_actions,
            current_blind = state.current_blind,
            shop_contents = state.shop_contents,
            jokers = state.jokers,
            consumables = state.consumables,
            post_hand_joker_reorder_available = state.post_hand_joker_reorder_available
        },
        
        -- Card data with clear separation and labeling
        card_data = {
            -- Current hand (cards player is holding and can play/discard right now)
            hand_cards = state.hand_cards or {},
            
            -- Remaining deck (cards still in deck that can be drawn)
            remaining_deck_cards = self.state_extractor:extract_remaining_deck_cards()
        },
        
        -- Voucher and ante information (included in main state for external analysis)
        vouchers_ante = state.vouchers_ante
    }
    
    local state_message = {
        message_type = "comprehensive_state_update",
        timestamp = os.time(),
        sequence = self.message_manager:get_next_sequence_id(),
        state = comprehensive_state
    }
    
    -- DIAGNOSTIC LOGGING BEFORE MESSAGE SEND
    print("BalatroMCP: [DEBUG_STALE_STATE] About to call message_manager:write_game_state")
    print("BalatroMCP: [DEBUG_STALE_STATE] Message manager: " .. tostring(self.message_manager))
    
    local send_result = self.message_manager:write_game_state(state_message)
    
    -- Write deck state to separate file as requested in issue #88
    local extracted_deck_cards = self.state_extractor:extract_deck_cards()
    if extracted_deck_cards and #extracted_deck_cards > 0 then
        local deck_state_message = {
            session_id = state.session_id or "unknown",
            timestamp = os.time(),
            card_count = #extracted_deck_cards,
            deck_cards = extracted_deck_cards
        }
        local deck_state_success = self.message_manager:write_deck_state(deck_state_message)
        if not deck_state_success then
            print("BalatroMCP: WARNING - Failed to write deck state to separate file")
        end
    else
        print("BalatroMCP: WARNING - No deck cards found, skipping deck state export")
    end
    
    -- Write full deck data to separate file as requested in issue #89
    local deck_cards = extracted_deck_cards  -- Use the same data extracted for deck_state.json
    if not deck_cards or #deck_cards == 0 then
        print("BalatroMCP: WARNING - No deck cards found in state, skipping full deck export")
    else
        local full_deck_message = {
            session_id = state.session_id or "unknown",
            timestamp = os.time(),
            card_count = #deck_cards,
            cards = deck_cards
        }
        local full_deck_success = self.message_manager:write_full_deck(full_deck_message)
        if not full_deck_success then
            print("BalatroMCP: WARNING - Failed to write full deck data")
        end
    end
    
    -- Also write hand levels data if available
    if state.hand_levels then
        local hand_levels_data = {
            session_id = state.session_id,
            hand_levels = state.hand_levels
        }
        local hand_levels_result = self.message_manager:write_hand_levels(hand_levels_data)
        print("BalatroMCP: [DEBUG_STALE_STATE] Hand levels write result: " .. tostring(hand_levels_result))
    else
        print("BalatroMCP: [DEBUG_STALE_STATE] No hand levels data available in state")
    end
    
    print("BalatroMCP: [DEBUG_STALE_STATE] Message send result: " .. tostring(send_result))
    
    -- Send vouchers and ante information as separate JSON export (using data already extracted)
    if state.vouchers_ante then
        local voucher_send_result = self.message_manager:write_vouchers_ante(state.vouchers_ante)
        if not voucher_send_result then
            print("BalatroMCP: WARNING - Failed to write vouchers ante data")
        else
            print("BalatroMCP: [DEBUG_STALE_STATE] Vouchers ante send result: " .. tostring(voucher_send_result))
        end
    end
    
    print("BalatroMCP: [DEBUG_STALE_STATE] === STATE TRANSMISSION COMPLETED ===")
    
    local hand_count = #(state.hand_cards or {})
    local full_deck_count = #(extracted_deck_cards or {})
    local remaining_deck_count = #(comprehensive_state.card_data.remaining_deck_cards or {})
    
    print("BalatroMCP: Comprehensive state update sent")
    print("  - Hand cards: " .. hand_count)
    print("  - Full deck cards: " .. full_deck_count)
    print("  - Remaining deck cards: " .. remaining_deck_count)
    print("  - Phase: " .. (state.current_phase or "unknown"))
    print("  - Vouchers ante export: vouchers_ante.json")
    print("  - Deck state export: deck_state.json")
end

function BalatroMCP:calculate_state_hash(state)
    local hash_components = {}
    
    if state.current_phase then
        table.insert(hash_components, tostring(state.current_phase))
    end
    
    if state.ante then
        table.insert(hash_components, tostring(state.ante))
    end
    
    if state.money then
        table.insert(hash_components, tostring(state.money))
    end
    
    if state.hands_remaining then
        table.insert(hash_components, tostring(state.hands_remaining))
    end
    
    if state.hand_cards then
        table.insert(hash_components, tostring(#state.hand_cards))
    end
    
    if state.jokers then
        table.insert(hash_components, tostring(#state.jokers))
    end
    
    local final_hash = table.concat(hash_components, "|")
    
    return final_hash
end

function BalatroMCP:send_status_update(status_type, status_data)
    -- Send status updates for intermediate game actions
    local status_message = {
        message_type = "status_update",
        timestamp = os.time(),
        sequence = self.message_manager:get_next_sequence_id(),
        status_type = status_type,
        status_data = status_data or {}
    }
    
    self.message_manager:write_game_state(status_message)
    print("BalatroMCP: Status update sent - " .. status_type)
end

function BalatroMCP:on_hand_played()
    print("BalatroMCP: Hand played event - deferring state extraction")
    self:defer_state_extraction("hand_action", { action_type = "hand_played" })
end

function BalatroMCP:on_cards_discarded()
    print("BalatroMCP: Cards discarded event - deferring state extraction")
    self:defer_state_extraction("hand_action", { action_type = "cards_discarded" })
end

function BalatroMCP:on_blind_selected()
    print("BalatroMCP: Blind selection transition detected - deferring state extraction")
    self.blind_transition_cooldown = 3.0
    self:defer_state_extraction("blind_selection", { action_type = "blind_selected" })
end

function BalatroMCP:on_shop_entered()
    print("BalatroMCP: Shop entered event - deferring state extraction")
    self:defer_state_extraction("shop_entry", { action_type = "shop_entered" })
end

function BalatroMCP:on_shop_exited()
    print("BalatroMCP: Shop exited event - deferring state extraction")
    self:defer_state_extraction("shop_exit", { action_type = "shop_exited" })
end

function BalatroMCP:on_round_completed()
    print("BalatroMCP: Round completed event - deferring state extraction")
    self:defer_state_extraction("round_completion", { action_type = "round_completed" })
end

function BalatroMCP:on_ante_advanced()
    print("BalatroMCP: Ante advanced event - deferring state extraction")
    self:defer_state_extraction("ante_advancement", { action_type = "ante_advanced" })
end

function BalatroMCP:on_hand_dealt()
    print("BalatroMCP: Hand dealt event - deferring state extraction")
    self:defer_state_extraction("hand_dealing", { action_type = "hand_dealt" })
end

function BalatroMCP:on_game_over()
    print("BalatroMCP: Game over event - deferring state extraction")
    self:defer_state_extraction("game_over", { action_type = "game_over" })
end








function BalatroMCP:extract_shop_item_info(element)
    -- Extract information about shop item from UI element
    local item_info = {
        name = "Unknown",
        type = "unknown",
        cost = 0
    }
    
    if not element then
        return item_info
    end
    
    -- Try to extract from element.config.card if it exists
    if element.config and element.config.card then
        local card = element.config.card
        if card.ability then
            item_info.name = card.ability.name or "Unknown"
            item_info.type = card.ability.set or "unknown"
        end
        item_info.cost = card.cost or 0
    end
    
    return item_info
end

function BalatroMCP:extract_blind_selection_info_from_element(element)
    -- Extract information about blind from UI element
    local blind_info = {
        name = "Unknown",
        type = "small",
        requirement = 0,
        reward = 0
    }
    
    if not element then
        return blind_info
    end
    
    -- Try to extract from element.config.blind if it exists
    if element.config and element.config.blind then
        local blind = element.config.blind
        blind_info.name = blind.name or "Unknown"
        blind_info.requirement = blind.chips or 0
        blind_info.reward = blind.dollars or 0
        
        -- Determine blind type
        if blind.boss then
            blind_info.type = "boss"
        elseif string.find(blind.name or "", "Big") then
            blind_info.type = "big"
        else
            blind_info.type = "small"
        end
    end
    
    -- Try to extract from element.area if it's a blind selection UI element
    if element.area and element.area.config then
        local area_config = element.area.config
        if area_config.type then
            blind_info.type = string.lower(area_config.type)
        end
    end
    
    return blind_info
end

function BalatroMCP:on_game_started()
    print("BalatroMCP: Game started event - capturing initial state")
    
    local current_state = self.state_extractor:extract_current_state()
    local phase = current_state and current_state.current_phase or "unknown"
    local money = current_state and current_state.money or "unknown"
    local ante = current_state and current_state.ante or "unknown"
    
    print("BalatroMCP: DEBUG - Game start state: phase=" .. phase ..
          ", money=" .. tostring(money) ..
          ", ante=" .. tostring(ante))
    
    self.last_state_hash = nil
    
    self:send_current_state()
    
    print("BalatroMCP: Initial game state sent for new run")
end

local mod_instance = nil

-- Check if we're in a test environment - if so, don't auto-initialize
local is_test_environment = _G.BalatroMCP_Test_Environment or false

if SMODS and not is_test_environment then
    print("BalatroMCP: SMODS framework detected, initializing mod...")

    local init_success, init_error = pcall(function()
        mod_instance = BalatroMCP.new()
        if mod_instance then
            mod_instance:start()
            print("BalatroMCP: Mod initialized and started successfully")
        else
            error("Failed to create mod instance")
        end
    end)
    
    if not init_success then
        print("BalatroMCP: CRITICAL ERROR - Mod initialization failed: " .. tostring(init_error))
    end
elseif is_test_environment then
    print("BalatroMCP: Test environment detected, skipping auto-initialization")
    
    _G.BalatroMCP_Instance = mod_instance
    
    if mod_instance and love then
        local original_love_update = love.update
        local last_known_state = nil
        
        if original_love_update then
            love.update = function(dt)
                local update_success, update_error = pcall(function()
                    local state_before = G and G.STATE or "NIL"
                    local direct_state_before = _G.G and _G.G.STATE or "NIL"
                    
                    if original_love_update and type(original_love_update) == "function" then
                        original_love_update(dt)
                    end
                
                    local state_after = G and G.STATE or "NIL"
                    local direct_state_after = _G.G and _G.G.STATE or "NIL"
                    
                    if state_before ~= state_after or direct_state_before ~= direct_state_after then
                        local timestamp = love.timer and love.timer.getTime() or os.clock()
                        print("BalatroMCP: STATE_CHANGE_DETECTED @ " .. tostring(timestamp))
                        print("  Cached G.STATE: " .. tostring(state_before) .. " -> " .. tostring(state_after))
                        print("  Direct _G.G.STATE: " .. tostring(direct_state_before) .. " -> " .. tostring(direct_state_after))
                        print("  State consistency: " .. tostring(state_after == direct_state_after))
                        last_known_state = state_after
                        
                        if _G.G and _G.G.STATES and type(_G.G.STATES) == "table" then
                            local current_state_name = "UNKNOWN"
                            for name, value in pairs(_G.G.STATES) do
                                if value == state_after then
                                    current_state_name = name
                                    break
                                end
                            end
                            print("  New state name: " .. current_state_name)
                        end
                    end
                end)
                
                if not update_success then
                    print("BalatroMCP: ERROR in Love2D update hook: " .. tostring(update_error))
                end
                
                if mod_instance and mod_instance.update then
                    local mod_success, mod_error = pcall(function()
                        mod_instance:update(dt)
                    end)
                    if not mod_success then
                        print("BalatroMCP: ERROR in mod update: " .. tostring(mod_error))
                    end
                end
            end
            print("BalatroMCP: Hooked into love.update with timing diagnostics")
        else
            print("BalatroMCP: WARNING - Could not hook into Love2D update, using timer fallback")
            if mod_instance then
                mod_instance.fallback_timer = 0
                mod_instance.fallback_update = function(self)
                    print("BalatroMCP: Using fallback update mechanism")
                end
            end
        end
    else
        print("BalatroMCP: WARNING - No update mechanism available (Love2D not found)")
    end
    
    if mod_instance then
        _G.BalatroMCP_Cleanup = function()
            print("BalatroMCP: Performing cleanup")
            if mod_instance then
                mod_instance:stop()
            end
        end
        print("BalatroMCP: Cleanup function registered as _G.BalatroMCP_Cleanup")
    end
    
else
    print("BalatroMCP: WARNING - SMODS framework not available, mod cannot initialize")
    print("BalatroMCP: This mod requires Steammodded to function properly")
    
    _G.BalatroMCP_Instance = nil
    _G.BalatroMCP_Error = "SMODS framework not available"
end

_G.BalatroMCP = mod_instance

return BalatroMCP