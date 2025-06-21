-- Main Balatro MCP mod file
-- Integrates all components and manages communication with MCP server

--- STEAMMODDED HEADER
--- MOD_NAME: BalatroMCP
--- MOD_ID: BalatroMCP
--- MOD_AUTHOR: [MCP Integration]
--- MOD_DESCRIPTION: Enables AI agent interaction with Balatro through MCP protocol

-- CRITICAL DIAGNOSTIC: Load diagnostics FIRST before anything else
print("BalatroMCP: MAIN FILE LOADING STARTED")
print("BalatroMCP: Timestamp: " .. os.date("%Y-%m-%d %H:%M:%S"))

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

-- Report module loading status
print("BalatroMCP: MODULE LOADING SUMMARY:")
print("  Diagnostics: " .. (diag_success and "SUCCESS" or "FAILED"))
print("  DebugLogger: " .. (debug_success and "SUCCESS" or "FAILED"))
print("  FileIO: " .. (fileio_success and "SUCCESS" or "FAILED"))
print("  StateExtractor: " .. (state_success and "SUCCESS" or "FAILED"))
print("  ActionExecutor: " .. (action_success and "SUCCESS" or "FAILED"))
print("  JokerManager: " .. (joker_success and "SUCCESS" or "FAILED"))
print("  CrashDiagnostics: " .. (crash_success and "SUCCESS" or "FAILED"))

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
    
    -- Test state extractor component
    local state_success, state_error = pcall(function()
        self.state_extractor = StateExtractor.new()
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
    
    -- DIAGNOSTIC: Track update cycle timing and state changes
    local update_start_time = love.timer and love.timer.getTime() or os.clock()
    local state_at_update_start = G and G.STATE or "NIL"
    
    self.update_timer = self.update_timer + dt
    
    if (self.update_timer >= self.update_interval) and G.STATE ~= -1 then
        self.update_timer = 0
        
        -- CRASH DIAGNOSTICS: Monitor joker objects before any operations
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
    
    -- DIAGNOSTIC: Track state changes during update
    local state_at_update_end = G and G.STATE or "NIL"
    if state_at_update_start ~= state_at_update_end then
        print("BalatroMCP: STATE_CHANGE_DETECTED - From: " .. tostring(state_at_update_start) .. " To: " .. tostring(state_at_update_end))
    end
end

function BalatroMCP:setup_game_hooks()
    -- Set up hooks for important game events
    print("BalatroMCP: Setting up game hooks")
    
    -- DIAGNOSTIC: List available G.FUNCS to identify game start functions
    print("BalatroMCP: DEBUG_HOOKS - Scanning available G.FUNCS for game start functions...")
    if G and G.FUNCS then
        local game_start_candidates = {}
        for func_name, func_value in pairs(G.FUNCS) do
            -- Look for functions that might be related to game start
            local name_lower = string.lower(func_name)
            if string.find(name_lower, "start") or
               string.find(name_lower, "new") or
               string.find(name_lower, "run") or
               string.find(name_lower, "begin") or
               string.find(name_lower, "init") then
                table.insert(game_start_candidates, func_name)
            end
        end
        
        if #game_start_candidates > 0 then
            print("BalatroMCP: DEBUG_HOOKS - Found potential game start functions: " .. table.concat(game_start_candidates, ", "))
        else
            print("BalatroMCP: DEBUG_HOOKS - No obvious game start functions found in G.FUNCS")
        end
    else
        print("BalatroMCP: DEBUG_HOOKS - G.FUNCS not available for scanning")
    end
    
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
    -- Hook blind selection events with crash diagnostics protection
    if G.FUNCS then
        local original_select_blind = G.FUNCS.select_blind
        if original_select_blind then
            G.FUNCS.select_blind = self.crash_diagnostics:create_safe_hook(
                function(...)
                    self.crash_diagnostics:track_hook_chain("select_blind")
                    self.crash_diagnostics:validate_game_state("select_blind")
                    print("BalatroMCP: Blind selected - capturing state")
                    local result = original_select_blind(...)
                    self:on_blind_selected()
                    return result
                end,
                "select_blind"
            )
            print("BalatroMCP: DEBUG_HOOKS - Applied crash diagnostics protection to select_blind")
        else
            print("BalatroMCP: DEBUG_HOOKS - G.FUNCS.select_blind not found for protection")
        end
    end
end

function BalatroMCP:hook_shop_interactions()
    -- Hook shop interaction events with enhanced crash diagnostics
    if G.FUNCS then
        local original_go_to_shop = G.FUNCS.go_to_shop
        if original_go_to_shop then
            G.FUNCS.go_to_shop = self.crash_diagnostics:create_safe_hook(
                function(...)
                    self.crash_diagnostics:track_hook_chain("go_to_shop")
                    self.crash_diagnostics:validate_game_state("go_to_shop")
                    print("BalatroMCP: Entered shop - capturing state")
                    local result = original_go_to_shop(...)
                    self:on_shop_entered()
                    return result
                end,
                "go_to_shop"
            )
        end
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
                print("BalatroMCP: DEBUG_HOOKS - Found and hooking " .. func_name)
                
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
    -- Check for and process pending actions from MCP server
    if self.processing_action then
        return -- Already processing an action
    end
    
    local action_data = self.file_io:read_actions()
    if not action_data then
        return -- No pending actions
    end
    
    -- Check sequence number to avoid duplicate processing
    local sequence = action_data.sequence or 0
    if sequence <= self.last_action_sequence then
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
    if not current_state then
        print("BalatroMCP: DEBUG_STATE_UPDATE - No current state extracted")
        return
    end
    
    -- DIAGNOSTIC: Log detailed state during transitions
    local g_state = G and G.STATE or "NIL"
    local phase = current_state.current_phase or "NIL"
    local money = current_state.money or "NIL"
    local ante = current_state.ante or "NIL"
    
    print("BalatroMCP: DEBUG_STATE_UPDATE - G.STATE=" .. tostring(g_state) ..
          ", phase=" .. tostring(phase) ..
          ", money=" .. tostring(money) ..
          ", ante=" .. tostring(ante))
    
    -- Calculate state hash for change detection
    local state_hash = self:calculate_state_hash(current_state)
    
    print("BalatroMCP: DEBUG_STATE_UPDATE - Current hash=" .. tostring(state_hash) ..
          ", Last hash=" .. tostring(self.last_state_hash))
    
    if state_hash ~= self.last_state_hash then
        print("BalatroMCP: DEBUG_STATE_UPDATE - State change detected, sending update")
        self.last_state_hash = state_hash
        self:send_state_update(current_state)
    else
        print("BalatroMCP: DEBUG_STATE_UPDATE - No state change detected")
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
    print("BalatroMCP: DEBUG_HASH - Starting hash calculation")
    
    if state.current_phase then
        table.insert(hash_components, tostring(state.current_phase))
        print("BalatroMCP: DEBUG_HASH - Added current_phase: " .. tostring(state.current_phase))
    else
        print("BalatroMCP: DEBUG_HASH - Missing current_phase")
    end
    
    if state.ante then
        table.insert(hash_components, tostring(state.ante))
        print("BalatroMCP: DEBUG_HASH - Added ante: " .. tostring(state.ante))
    else
        print("BalatroMCP: DEBUG_HASH - Missing ante")
    end
    
    if state.money then
        table.insert(hash_components, tostring(state.money))
        print("BalatroMCP: DEBUG_HASH - Added money: " .. tostring(state.money))
    else
        print("BalatroMCP: DEBUG_HASH - Missing money")
    end
    
    if state.hands_remaining then
        table.insert(hash_components, tostring(state.hands_remaining))
        print("BalatroMCP: DEBUG_HASH - Added hands_remaining: " .. tostring(state.hands_remaining))
    else
        print("BalatroMCP: DEBUG_HASH - Missing hands_remaining")
    end
    
    if state.hand_cards then
        table.insert(hash_components, tostring(#state.hand_cards))
        print("BalatroMCP: DEBUG_HASH - Added hand_cards count: " .. tostring(#state.hand_cards))
    else
        print("BalatroMCP: DEBUG_HASH - Missing hand_cards")
    end
    
    if state.jokers then
        table.insert(hash_components, tostring(#state.jokers))
        print("BalatroMCP: DEBUG_HASH - Added jokers count: " .. tostring(#state.jokers))
    else
        print("BalatroMCP: DEBUG_HASH - Missing jokers")
    end
    
    local final_hash = table.concat(hash_components, "|")
    print("BalatroMCP: DEBUG_HASH - Final hash: " .. tostring(final_hash))
    
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
    -- Called when a blind is selected
    print("BalatroMCP: Blind selected event")
    self:send_current_state()
end

function BalatroMCP:on_shop_entered()
    -- Called when entering the shop
    print("BalatroMCP: Shop entered event")
    
    -- DIAGNOSTIC: Check state when hook fires
    local current_state = self.state_extractor:extract_current_state()
    local phase = current_state and current_state.current_phase or "unknown"
    local money = current_state and current_state.money or "unknown"
    print("BalatroMCP: DEBUG - Hook fired with state: phase=" .. phase .. ", money=" .. tostring(money))
    
    self:send_current_state()
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