-- Main Balatro MCP mod file
-- Integrates all components and manages communication with MCP server

--- STEAMMODDED HEADER
--- MOD_NAME: BalatroMCP
--- MOD_ID: BalatroMCP
--- MOD_AUTHOR: [MCP Integration]
--- MOD_DESCRIPTION: Enables AI agent interaction with Balatro through MCP protocol

-- Load diagnostics first before anything else
print("BalatroMCP: MAIN FILE LOADING STARTED")

-- Test if we can load ANY file through SMODS
local ModLoadingDiagnostics = nil
local diag_success, diag_error = pcall(function()
    if SMODS and SMODS.load_file then
        print("BalatroMCP: SMODS available, attempting to load diagnostics")
        ModLoadingDiagnostics = assert(SMODS.load_file("mod_loading_diagnostics.lua"))()
        print("BalatroMCP: Diagnostics loaded successfully")
    else
        print("BalatroMCP: CRITICAL - SMODS or SMODS.load_file not available")
        print("BalatroMCP: SMODS exists: " .. tostring(SMODS ~= nil))
        if SMODS then
            print("BalatroMCP: SMODS.load_file exists: " .. tostring(SMODS.load_file ~= nil))
        end
    end
end)

if not diag_success then
    print("BalatroMCP: CRITICAL - Diagnostics loading failed: " .. tostring(diag_error))
    print("BalatroMCP: This indicates fundamental mod loading issues")
end

-- Import modules using Steammodded loading (with error handling)
print("BalatroMCP: Attempting to load core modules...")

local DebugLogger = nil
local debug_success, debug_error = pcall(function()
    DebugLogger = assert(SMODS.load_file("debug_logger.lua"))()
    print("BalatroMCP: DebugLogger loaded successfully")
end)
if not debug_success then
    print("BalatroMCP: DebugLogger load failed: " .. tostring(debug_error))
end

local FileIO = nil
local fileio_success, fileio_error = pcall(function()
    FileIO = assert(SMODS.load_file("file_io.lua"))()
    print("BalatroMCP: FileIO loaded successfully")
end)
if not fileio_success then
    print("BalatroMCP: FileIO load failed: " .. tostring(fileio_error))
end

local StateExtractor = nil
local state_success, state_error = pcall(function()
    StateExtractor = assert(SMODS.load_file("state_extractor.lua"))()
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

local NilConfigDiagnostics = nil
local nil_config_success, nil_config_error = pcall(function()
    NilConfigDiagnostics = assert(SMODS.load_file("nil_config_diagnostics.lua"))()
    print("BalatroMCP: NilConfigDiagnostics loaded successfully")
end)
if not nil_config_success then
    print("BalatroMCP: NilConfigDiagnostics load failed: " .. tostring(nil_config_error))
end

-- Report module loading status
print("BalatroMCP: MODULE LOADING SUMMARY:")
print("  Diagnostics: " .. (diag_success and "SUCCESS" or "FAILED"))
print("  DebugLogger: " .. (debug_success and "SUCCESS" or "FAILED"))
print("  FileIO: " .. (fileio_success and "SUCCESS" or "FAILED"))
print("  StateExtractor: " .. (state_success and "SUCCESS" or "FAILED"))
print("  ActionExecutor: " .. (action_success and "SUCCESS" or "FAILED"))
print("  JokerManager: " .. (joker_success and "SUCCESS" or "FAILED"))
print("  CrashDiagnostics: " .. (crash_success and "SUCCESS" or "FAILED"))
print("  NilConfigDiagnostics: " .. (nil_config_success and "SUCCESS" or "FAILED"))

-- Main mod class
local BalatroMCP = {}
BalatroMCP.__index = BalatroMCP

function BalatroMCP.new()
    local self = setmetatable({}, BalatroMCP)
    
    -- Initialize debug logger first
    self.debug_logger = DebugLogger.new()
    self.debug_logger:info("=== BALATRO MCP INITIALIZATION STARTED ===", "INIT")
    
    -- Initialize crash diagnostics
    self.crash_diagnostics = CrashDiagnostics.new()
    self.debug_logger:info("Crash diagnostics initialized", "INIT")
    
    -- Initialize nil config diagnostics
    if NilConfigDiagnostics then
        --self.nil_config_diagnostics = NilConfigDiagnostics.new()
        -- Store globally for access from wrappers
        --_G.BalatroMCP_NilConfigDiagnostics = self.nil_config_diagnostics
        self.debug_logger:info("Nil config diagnostics initialized", "INIT")
    else
        self.debug_logger:error("NilConfigDiagnostics not available", "INIT")
    end
    
    -- Test environment immediately
    self.debug_logger:test_environment()
    
    -- Initialize components with error handling
    local init_success = true
    
    -- Test file I/O component
    local file_io_success, file_io_error = pcall(function()
        self.file_io = FileIO.new()
        self.debug_logger:info("FileIO component initialized successfully", "INIT")
    end)
    
    if not file_io_success then
        self.debug_logger:error("FileIO initialization failed: " .. tostring(file_io_error), "INIT")
        init_success = false
    end
    
    -- Test state extractor component with nil config diagnostics
    local state_success, state_error = pcall(function()
        self.state_extractor = StateExtractor.new()
        
        -- Wrap state extractor with nil config diagnostics
        if self.nil_config_diagnostics then
            self.nil_config_diagnostics:create_safe_state_extraction_wrapper(self.state_extractor)
            self.debug_logger:info("StateExtractor wrapped with nil config diagnostics", "INIT")
        end
        
        self.debug_logger:info("StateExtractor component initialized successfully", "INIT")
    end)
    
    if not state_success then
        self.debug_logger:error("StateExtractor initialization failed: " .. tostring(state_error), "INIT")
        init_success = false
    end
    
    -- Test joker manager component
    local joker_success, joker_error = pcall(function()
        self.joker_manager = JokerManager.new()
        -- CRASH FIX: Inject crash diagnostics into joker manager
        self.joker_manager:set_crash_diagnostics(self.crash_diagnostics)
        self.debug_logger:info("JokerManager component initialized successfully with crash diagnostics", "INIT")
    end)
    
    if not joker_success then
        self.debug_logger:error("JokerManager initialization failed: " .. tostring(joker_error), "INIT")
        init_success = false
    end
    
    -- Test action executor component
    local action_success, action_error = pcall(function()
        self.action_executor = ActionExecutor.new(self.state_extractor, self.joker_manager)
        self.debug_logger:info("ActionExecutor component initialized successfully", "INIT")
    end)
    
    if not action_success then
        self.debug_logger:error("ActionExecutor initialization failed: " .. tostring(action_error), "INIT")
        init_success = false
    end
    
    -- State tracking
    self.last_state_hash = nil
    self.polling_active = false
    self.update_timer = 0
    self.update_interval = 0.5 -- Check for actions every 0.5 seconds
    
    -- Action processing
    self.processing_action = false
    self.last_action_sequence = 0
    
    -- Delayed state extraction fix
    self.pending_state_extraction = false
    self.pending_action_result = nil
    
    -- Delayed shop state capture
    self.delayed_shop_state_capture = false
    self.delayed_shop_capture_timer = 0
    
    -- Test file communication system
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

function BalatroMCP:start()
    -- Start the MCP integration
    print("BalatroMCP: Starting MCP integration")
    
    -- Set up game hooks
    self:setup_game_hooks()
    
    -- Start polling for actions
    self.polling_active = true
    
    -- Send initial state
    self:send_current_state()
    
    print("BalatroMCP: MCP integration started")
end

function BalatroMCP:stop()
    -- Stop the MCP integration
    print("BalatroMCP: Stopping MCP integration")
    
    self.polling_active = false
    
    -- Clean up hooks
    self:cleanup_hooks()
    
    print("BalatroMCP: MCP integration stopped")
end

function BalatroMCP:update(dt)
    -- Main update loop called by Steammodded
    if not self.polling_active then
        return
    end
    
    
    -- NON-INTRUSIVE BLIND SELECTION DETECTION
    self:detect_blind_selection_transition()
    
    -- NON-INTRUSIVE SHOP STATE DETECTION
    self:detect_shop_state_transition()
    
    -- Handle delayed blind state capture
    if self.delayed_blind_state_capture then
        self.delayed_blind_capture_timer = self.delayed_blind_capture_timer - dt
        if self.delayed_blind_capture_timer <= 0 then
            print("BalatroMCP: Executing delayed blind selection state capture")
            self.delayed_blind_state_capture = false
            self:send_current_state()
        end
    end
    
    -- Handle delayed shop state capture
    if self.delayed_shop_state_capture then
        self.delayed_shop_capture_timer = self.delayed_shop_capture_timer - dt
        if self.delayed_shop_capture_timer <= 0 then
            print("BalatroMCP: Executing delayed shop state capture")
            self.delayed_shop_state_capture = false
            
            -- Extract and log shop state after delay
            local current_state = self.state_extractor:extract_current_state()
            local shop_items = current_state and current_state.shop_contents and #current_state.shop_contents or 0
            print("BalatroMCP: DEBUG - Shop state after delay: shop_items=" .. tostring(shop_items))
            
            self:send_current_state()
        end
    end
    
    -- Update blind transition cooldown
    if self.blind_transition_cooldown > 0 then
        self.blind_transition_cooldown = self.blind_transition_cooldown - dt
    end
    
    self.update_timer = self.update_timer + dt
    
    if (self.update_timer >= self.update_interval) and G.STATE ~= -1 then
        self.update_timer = 0
        
        -- Monitor joker objects before any operations
        if self.crash_diagnostics then
            self.crash_diagnostics:monitor_joker_operations()
        end
        
        -- Handle pending delayed state extraction first
        if self.pending_state_extraction then
            print("BalatroMCP: PROCESSING_DELAYED_EXTRACTION")
            self:handle_delayed_state_extraction()
        end
        
        -- Check for pending actions (only log if action found)
        self:process_pending_actions()
        
        -- Send state updates if changed (only logs if state changed)
        self:check_and_send_state_update()
    end
    
end

function BalatroMCP:setup_game_hooks()
    -- Set up hooks for important game events
    print("BalatroMCP: Setting up game hooks")
    
    
    -- Hook into game start events (MISSING - this is the problem!)
    self:hook_game_start()
    
    -- Hook into hand evaluation
    self:hook_hand_evaluation()
    
    -- Hook into blind selection
    self:hook_blind_selection()
    
    -- Hook into shop interactions
    self:hook_shop_interactions()
    
    -- Hook into joker interactions
    self:hook_joker_interactions()
end

function BalatroMCP:hook_hand_evaluation()
    -- Hook hand evaluation events with enhanced crash diagnostics
    if G.FUNCS then
        local original_play_cards = G.FUNCS.play_cards_from_highlighted
        if original_play_cards then
            G.FUNCS.play_cards_from_highlighted = self.crash_diagnostics:create_safe_hook(
                function(...)
                    self.crash_diagnostics:track_hook_chain("play_cards_from_highlighted")
                    self.crash_diagnostics:validate_game_state("play_cards_from_highlighted")
                    print("BalatroMCP: Hand played - capturing state")
                    local result = original_play_cards(...)
                    self:on_hand_played()
                    return result
                end,
                "play_cards_from_highlighted"
            )
        end
        
        local original_discard_cards = G.FUNCS.discard_cards_from_highlighted
        if original_discard_cards then
            G.FUNCS.discard_cards_from_highlighted = self.crash_diagnostics:create_safe_hook(
                function(...)
                    self.crash_diagnostics:track_hook_chain("discard_cards_from_highlighted")
                    self.crash_diagnostics:validate_game_state("discard_cards_from_highlighted")
                    print("BalatroMCP: Cards discarded - capturing state")
                    local result = original_discard_cards(...)
                    self:on_cards_discarded()
                    return result
                end,
                "discard_cards_from_highlighted"
            )
        end
    end
end

function BalatroMCP:hook_blind_selection()
    -- CRITICAL FIX: DO NOT hook G.FUNCS.select_blind directly as it interferes with object lifecycle
    -- Instead, use non-intrusive state change detection in the update loop
    print("BalatroMCP: Using non-intrusive blind selection detection (no direct hooks)")
    
    -- Initialize blind selection state tracking
    self.last_blind_state = G and G.STATE or nil
    self.blind_transition_detected = false
    self.blind_transition_cooldown = 0
end

function BalatroMCP:hook_shop_interactions()
    -- Hook shop interaction events with enhanced crash diagnostics
    if G.FUNCS then
        -- CORRECTED: Hook cash_out function since go_to_shop doesn't exist
        local original_cash_out = G.FUNCS.cash_out
        if original_cash_out then
            G.FUNCS.cash_out = self.crash_diagnostics:create_safe_hook(
                function(...)
                    self.crash_diagnostics:track_hook_chain("cash_out")
                    self.crash_diagnostics:validate_game_state("cash_out")
                    print("BalatroMCP: Cash out triggered - capturing state")
                    local result = original_cash_out(...)
                    self:on_shop_entered()
                    return result
                end,
                "cash_out"
            )
        else
            print("BalatroMCP: WARNING - G.FUNCS.cash_out not available for shop hooks")
        end
        
        -- Also add a state detection hook for when we enter shop state directly
        self:setup_shop_state_detection()
    end
end

function BalatroMCP:hook_game_start()
    -- Hook game start/new run events - THIS WAS THE MISSING PIECE!
    print("BalatroMCP: Setting up game start hooks")
    
    if G.FUNCS then
        -- Common Balatro game start function candidates to hook
        local game_start_functions = {
            "start_run",      -- Most likely candidate
            "new_run",
            "begin_run",
            "start_game",
            "new_game",
            "init_run",
            "setup_run"
        }
        
        local hooks_applied = 0
        
        for _, func_name in ipairs(game_start_functions) do
            local original_func = G.FUNCS[func_name]
            if original_func then
                
                G.FUNCS[func_name] = function(...)
                    print("BalatroMCP: Game start detected via " .. func_name .. " - capturing state")
                    local result = original_func(...)
                    self:on_game_started()
                    return result
                end
                
                hooks_applied = hooks_applied + 1
            end
        end
        
        if hooks_applied == 0 then
            print("BalatroMCP: DEBUG_HOOKS - No standard game start functions found, using fallback detection")
            -- Fallback: Hook into any function that might start a game
            -- This will be discovered through the diagnostic logging above
        else
            print("BalatroMCP: DEBUG_HOOKS - Applied " .. hooks_applied .. " game start hooks")
        end
    else
        print("BalatroMCP: ERROR - G.FUNCS not available for game start hooks")
    end
end

function BalatroMCP:hook_joker_interactions()
    -- Hook joker-related events
    -- This will be extended as we discover more about Balatro's internal structure
    print("BalatroMCP: Joker interaction hooks set up")
end

function BalatroMCP:cleanup_hooks()
    -- Clean up any hooks when stopping
    print("BalatroMCP: Cleaning up game hooks")
    -- Implementation depends on how we want to restore original functions
end

function BalatroMCP:process_pending_actions()
    print("procing")
    -- Check for and process pending actions from MCP server
    if self.processing_action then
        print("already procing")
        return -- Already processing an action
    end
    
    local action_data = self.file_io:read_actions()
    if not action_data then
        print("no action")
        return -- No pending actions
    end
    
    -- Check sequence number to avoid duplicate processing
    local sequence = action_data.sequence_id or 0
    if sequence <= self.last_action_sequence then
        print("already procced")
        return -- Already processed this action
    end
    
    self.processing_action = true
    self.last_action_sequence = sequence
    
    print("BalatroMCP: Processing action: " .. (action_data.action_type or "unknown"))
    
    -- DIAGNOSTIC: Extract state BEFORE action execution
    local state_before = self.state_extractor:extract_current_state()
    local phase_before = state_before and state_before.current_phase or "unknown"
    local money_before = state_before and state_before.money or "unknown"
    print("BalatroMCP: DEBUG - State BEFORE action: phase=" .. phase_before .. ", money=" .. tostring(money_before))
    
    -- Execute the action
    local result = self.action_executor:execute_action(action_data)
    
    -- DIAGNOSTIC: Extract state IMMEDIATELY after action execution
    local state_after = self.state_extractor:extract_current_state()
    local phase_after = state_after and state_after.current_phase or "unknown"
    local money_after = state_after and state_after.money or "unknown"
    print("BalatroMCP: DEBUG - State IMMEDIATELY after action: phase=" .. phase_after .. ", money=" .. tostring(money_after))
    
    -- CALLBACK FIX: Defer state extraction and response to next update cycle
    print("BalatroMCP: Deferring state extraction to next update cycle")
    self.pending_state_extraction = true
    self.pending_action_result = {
        sequence = sequence,
        action_type = action_data.action_type,
        success = result.success,
        error_message = result.error_message,
        timestamp = os.time()
        -- Note: new_state will be extracted on next update
    }
    
    -- Don't set processing_action = false yet - wait for delayed extraction
    
    if result.success then
        print("BalatroMCP: Action completed successfully")
    else
        print("BalatroMCP: Action failed: " .. (result.error_message or "Unknown error"))
    end
end

function BalatroMCP:handle_delayed_state_extraction()
    -- Handle delayed state extraction on next update cycle
    print("BalatroMCP: Processing delayed state extraction")
    
    -- Extract state after Balatro has had time to update
    local current_state = self.state_extractor:extract_current_state()
    local phase = current_state and current_state.current_phase or "unknown"
    local money = current_state and current_state.money or "unknown"
    print("BalatroMCP: DEBUG - State AFTER delay: phase=" .. phase .. ", money=" .. tostring(money))
    
    -- Complete the action result with fresh state
    if self.pending_action_result then
        self.pending_action_result.new_state = current_state
        
        -- Send response back to MCP server
        self.file_io:write_action_result(self.pending_action_result)
        print("BalatroMCP: Delayed action result sent with updated state")
        
        -- Clean up
        self.pending_action_result = nil
    end
    
    -- Reset processing flags
    self.pending_state_extraction = false
    self.processing_action = false
end

function BalatroMCP:check_and_send_state_update()
    -- Check if game state has changed and send update if needed
    local current_state = self.state_extractor:extract_current_state()
    
    -- DIAGNOSTIC: Log detailed state during transitions
    local g_state = G and G.STATE or "NIL"
    local phase = current_state.current_phase or "NIL"
    local money = current_state.money or "NIL"
    local ante = current_state.ante or "NIL"
    
    -- Calculate state hash for change detection
    local state_hash = self:calculate_state_hash(current_state)
    
    
    if state_hash ~= self.last_state_hash then
        self.last_state_hash = state_hash
        self:send_state_update(current_state)
    end
end

function BalatroMCP:send_current_state()
    -- Send current game state to MCP server
    local current_state = self.state_extractor:extract_current_state()
    if current_state then
        self:send_state_update(current_state)
    end
end

function BalatroMCP:send_state_update(state)
    -- Send state update to MCP server
    local state_message = {
        message_type = "state_update",
        timestamp = os.time(),
        sequence = self.file_io:get_next_sequence_id(),
        state = state
    }
    
    self.file_io:write_game_state(state_message)
    print("BalatroMCP: State update sent")
end

function BalatroMCP:calculate_state_hash(state)
    -- Simple hash calculation for state change detection
    -- This is a basic implementation - could be improved
    local hash_components = {}
    
    -- DIAGNOSTIC: Log each component for debugging
  --  print("BalatroMCP: DEBUG_HASH - Starting hash calculation")
    
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

-- Event handlers
function BalatroMCP:on_hand_played()
    -- Called when a hand is played
    print("BalatroMCP: Hand played event")
    self:send_current_state()
end

function BalatroMCP:on_cards_discarded()
    -- Called when cards are discarded
    print("BalatroMCP: Cards discarded event")
    self:send_current_state()
end

function BalatroMCP:on_blind_selected()
    -- Called when a blind selection transition is detected (non-intrusively)
    print("BalatroMCP: Blind selection transition detected")
    
    -- Set a cooldown to prevent rapid-fire detection
    self.blind_transition_cooldown = 3.0  -- 3 second cooldown
    
    -- Delay state capture to allow transition to complete
    self.delayed_blind_state_capture = true
    self.delayed_blind_capture_timer = 1.0  -- Wait 1 second for transition to complete
end

function BalatroMCP:on_shop_entered()
    -- Called when entering the shop
    print("BalatroMCP: Shop entered event - delaying state capture for shop population")
    
    -- DIAGNOSTIC: Check state when hook fires
    local current_state = self.state_extractor:extract_current_state()
    local phase = current_state and current_state.current_phase or "unknown"
    local money = current_state and current_state.money or "unknown"
    local shop_items = current_state and current_state.shop_contents and #current_state.shop_contents or 0
    print("BalatroMCP: DEBUG - Hook fired with state: phase=" .. phase .. ", money=" .. tostring(money) .. ", shop_items=" .. tostring(shop_items))
    
    -- Delay state capture to allow shop contents to populate - increased delay
    self.delayed_shop_state_capture = true
    self.delayed_shop_capture_timer = 1.0  -- Wait 1.0 seconds for shop to populate
end

function BalatroMCP:setup_shop_state_detection()
    -- Set up additional shop state detection for cases where cash_out hook doesn't fire
    print("BalatroMCP: Setting up shop state detection")
    
    -- Initialize shop state tracking
    self.last_shop_state = nil
    self.shop_state_initialized = false
end

function BalatroMCP:detect_blind_selection_transition()
    -- NON-INTRUSIVE detection of blind selection transitions
    -- This detects state changes without hooking into the transition functions
    
    if not G or not G.STATE or not G.STATES then
        return
    end
    
    local current_state = G.STATE
    
    -- Initialize tracking on first run
    if not self.last_blind_state then
        self.last_blind_state = current_state
        return
    end
    
    -- Skip detection during cooldown to prevent rapid-fire triggers
    if self.blind_transition_cooldown > 0 then
        return
    end
    
    -- Detect transition FROM blind selection TO hand selection (this is the critical transition)
    local was_blind_select = (self.last_blind_state == G.STATES.BLIND_SELECT)
    local is_hand_select = (current_state == G.STATES.SELECTING_HAND or current_state == G.STATES.DRAW_TO_HAND)
    
    if was_blind_select and is_hand_select then
        print("BalatroMCP: NON_INTRUSIVE_DETECTION - Blind selection completed: " .. 
              tostring(self.last_blind_state) .. " -> " .. tostring(current_state))
        self:on_blind_selected()
    end
    
    -- Update state tracking
    self.last_blind_state = current_state
end

function BalatroMCP:detect_shop_state_transition()
    -- NON-INTRUSIVE detection of shop state transitions
    -- This catches cases where the cash_out hook doesn't fire
    
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
    
    -- Skip if we're already processing a delayed shop capture
    if self.delayed_shop_state_capture then
        return
    end
    
    -- Detect transition INTO shop state
    local was_not_shop = (self.last_shop_state ~= G.STATES.SHOP)
    local is_shop = (current_state == G.STATES.SHOP)
    
    if was_not_shop and is_shop and not self.shop_state_initialized then
        print("BalatroMCP: NON_INTRUSIVE_DETECTION - Shop state entered: " ..
              tostring(self.last_shop_state) .. " -> " .. tostring(current_state))
        
        self.shop_state_initialized = true
        self:on_shop_entered()
    end
    
    -- Reset shop state flag when leaving shop
    if current_state ~= G.STATES.SHOP then
        self.shop_state_initialized = false
    end
    
    -- Update state tracking
    self.last_shop_state = current_state
end

function BalatroMCP:on_game_started()
    -- Called when a new game/run is started - THIS WAS THE MISSING EVENT HANDLER!
    print("BalatroMCP: Game started event - capturing initial state")
    
    -- DIAGNOSTIC: Check state when game starts
    local current_state = self.state_extractor:extract_current_state()
    local phase = current_state and current_state.current_phase or "unknown"
    local money = current_state and current_state.money or "unknown"
    local ante = current_state and current_state.ante or "unknown"
    
    print("BalatroMCP: DEBUG - Game start state: phase=" .. phase ..
          ", money=" .. tostring(money) ..
          ", ante=" .. tostring(ante))
    
    -- Force a fresh state hash to ensure the new game state is captured
    self.last_state_hash = nil
    
    -- Send the initial game state immediately
    self:send_current_state()
    
    print("BalatroMCP: Initial game state sent for new run")
end

-- Steammodded integration with defensive programming
local mod_instance = nil

-- CRITICAL FIX: Check for SMODS table existence before attempting to access
-- Replace the failing SMODS.INIT/UPDATE/QUIT pattern with self-initializing module
if SMODS then
    print("BalatroMCP: SMODS framework detected, initializing mod...")

    -- Initialize mod directly when loaded (Pattern A: Self-initializing module)
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
    
    -- Store globally for access and debugging
    _G.BalatroMCP_Instance = mod_instance
    
    -- Hook into update loop using Love2D callback pattern
    -- Since SMODS.UPDATE table doesn't exist and G.STATE is a number, not a table
    if mod_instance and love then
        -- Try to hook into Love2D's update callback
        local original_love_update = love.update
        local last_known_state = nil
        
        if original_love_update then
            love.update = function(dt)
                -- CRASH FIX: Wrap everything in pcall to prevent crashes
                local update_success, update_error = pcall(function()
                    -- SELECTIVE DIAGNOSTIC: Only log when states actually change
                    local state_before = G and G.STATE or "NIL"
                    local direct_state_before = _G.G and _G.G.STATE or "NIL"
                    
                    -- Call original Love2D update first with error handling
                    if original_love_update and type(original_love_update) == "function" then
                        original_love_update(dt)
                    end
                
                    -- Check for state changes AFTER game update
                    local state_after = G and G.STATE or "NIL"
                    local direct_state_after = _G.G and _G.G.STATE or "NIL"
                    
                    -- ONLY LOG WHEN STATE CHANGES (not every frame)
                    if state_before ~= state_after or direct_state_before ~= direct_state_after then
                        local timestamp = love.timer and love.timer.getTime() or os.clock()
                        print("BalatroMCP: STATE_CHANGE_DETECTED @ " .. tostring(timestamp))
                        print("  Cached G.STATE: " .. tostring(state_before) .. " -> " .. tostring(state_after))
                        print("  Direct _G.G.STATE: " .. tostring(direct_state_before) .. " -> " .. tostring(direct_state_after))
                        print("  State consistency: " .. tostring(state_after == direct_state_after))
                        last_known_state = state_after
                        
                        -- Log available state names for context
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
                
                -- Always call our mod update (with separate error handling)
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
            -- Fallback: Use a timer-based approach
            if mod_instance then
                mod_instance.fallback_timer = 0
                mod_instance.fallback_update = function(self)
                    -- This would need to be called manually or via another hook
                    print("BalatroMCP: Using fallback update mechanism")
                end
            end
        end
    else
        print("BalatroMCP: WARNING - No update mechanism available (Love2D not found)")
    end
    
    -- Cleanup mechanism - hook into game exit if possible
    if mod_instance then
        -- Since SMODS.QUIT doesn't exist, we can't rely on it for cleanup
        -- Store cleanup function globally for manual cleanup if needed
        _G.BalatroMCP_Cleanup = function()
            print("BalatroMCP: Performing cleanup")
            if mod_instance then
                mod_instance:stop()
            end
        end
        print("BalatroMCP: Cleanup function registered as _G.BalatroMCP_Cleanup")
    end
    
else
    -- Fallback handling when SMODS is not available
    print("BalatroMCP: WARNING - SMODS framework not available, mod cannot initialize")
    print("BalatroMCP: This mod requires Steammodded to function properly")
    
    -- Create a minimal fallback instance for debugging
    _G.BalatroMCP_Instance = nil
    _G.BalatroMCP_Error = "SMODS framework not available"
end

-- Global access for debugging (compatible with both success and failure cases)
_G.BalatroMCP = mod_instance

return BalatroMCP