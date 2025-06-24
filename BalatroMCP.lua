-- Main Balatro MCP mod file
-- Integrates all components and manages communication with MCP server

--- STEAMMODDED HEADER
--- MOD_NAME: BalatroMCP
--- MOD_ID: BalatroMCP
--- MOD_AUTHOR: [MCP Integration]
--- MOD_DESCRIPTION: Enables AI agent interaction with Balatro through MCP protocol

print("BalatroMCP: MAIN FILE LOADING STARTED")

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

print("BalatroMCP: MODULE LOADING SUMMARY:")
print("  DebugLogger: " .. (debug_success and "SUCCESS" or "FAILED"))
print("  MessageTransport: " .. (transport_success and "SUCCESS" or "FAILED"))
print("  FileTransport: " .. (file_transport_success and "SUCCESS" or "FAILED"))
print("  MessageManager: " .. (message_manager_success and "SUCCESS" or "FAILED"))
print("  StateExtractor: " .. (state_success and "SUCCESS" or "FAILED"))
print("  ActionExecutor: " .. (action_success and "SUCCESS" or "FAILED"))
print("  JokerManager: " .. (joker_success and "SUCCESS" or "FAILED"))
print("  CrashDiagnostics: " .. (crash_success and "SUCCESS" or "FAILED"))

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
    
    local message_manager_success, message_manager_error = pcall(function()
        self.file_transport = FileTransport.new()
        self.message_manager = MessageManager.new(self.file_transport, "BALATRO_MCP")
        self.debug_logger:info("MessageManager and FileTransport components initialized successfully", "INIT")
    end)
    
    if not message_manager_success then
        self.debug_logger:error("MessageManager initialization failed: " .. tostring(message_manager_error), "INIT")
        init_success = false
    end
    
    local state_success, state_error = pcall(function()
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
        self.joker_manager = JokerManager.new()
        self.joker_manager:set_crash_diagnostics(self.crash_diagnostics)
        self.debug_logger:info("JokerManager component initialized successfully with crash diagnostics", "INIT")
    end)
    
    if not joker_success then
        self.debug_logger:error("JokerManager initialization failed: " .. tostring(joker_error), "INIT")
        init_success = false
    end
    
    local action_success, action_error = pcall(function()
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
    self.update_interval = 0.5 -- Check for actions every 0.5 seconds
    
    self.processing_action = false
    self.last_action_sequence = 0
    
    self.pending_state_extraction = false
    self.pending_action_result = nil
    
    self.delayed_shop_state_capture = false
    self.delayed_shop_capture_timer = 0
    
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
    print("BalatroMCP: Starting MCP integration")
    
    self:setup_game_hooks()
    
    self.polling_active = true
    
    self:send_current_state()
    
    print("BalatroMCP: MCP integration started")
end

function BalatroMCP:stop()
    print("BalatroMCP: Stopping MCP integration")
    
    self.polling_active = false
    
    self:cleanup_hooks()
    
    print("BalatroMCP: MCP integration stopped")
end

function BalatroMCP:update(dt)
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
        
        if self.crash_diagnostics then
            self.crash_diagnostics:monitor_joker_operations()
        end
        
        if self.pending_state_extraction then
            print("BalatroMCP: PROCESSING_DELAYED_EXTRACTION")
            self:handle_delayed_state_extraction()
        end
        
        self:process_pending_actions()
        
        self:check_and_send_state_update()
    end
    
end

function BalatroMCP:setup_game_hooks()
    print("BalatroMCP: Setting up game hooks")
    
    self:hook_game_start()
    
    self:hook_hand_evaluation()
    
    self:hook_blind_selection()
    
    self:hook_shop_interactions()
    
    self:hook_joker_interactions()
end

function BalatroMCP:hook_hand_evaluation()
    if G.FUNCS then
        local original_play_cards = G.FUNCS.play_cards_from_highlighted
        if original_play_cards then
            if self.crash_diagnostics then
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
            else
                G.FUNCS.play_cards_from_highlighted = function(...)
                    print("BalatroMCP: Hand played - capturing state")
                    local result = original_play_cards(...)
                    self:on_hand_played()
                    return result
                end
            end
        end
        
        local original_discard_cards = G.FUNCS.discard_cards_from_highlighted
        if original_discard_cards then
            if self.crash_diagnostics then
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
            else
                G.FUNCS.discard_cards_from_highlighted = function(...)
                    print("BalatroMCP: Cards discarded - capturing state")
                    local result = original_discard_cards(...)
                    self:on_cards_discarded()
                    return result
                end
            end
        end
    end
end

function BalatroMCP:hook_blind_selection()
    print("BalatroMCP: Using non-intrusive blind selection detection (no direct hooks)")
    
    self.last_blind_state = G and G.STATE or nil
    self.blind_transition_detected = false
    self.blind_transition_cooldown = 0
end

function BalatroMCP:hook_shop_interactions()
    if G.FUNCS then
        local original_cash_out = G.FUNCS.cash_out
        if original_cash_out then
            if self.crash_diagnostics then
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
                G.FUNCS.cash_out = function(...)
                    print("BalatroMCP: Cash out triggered - capturing state")
                    local result = original_cash_out(...)
                    self:on_shop_entered()
                    return result
                end
            end
        else
            print("BalatroMCP: WARNING - G.FUNCS.cash_out not available for shop hooks")
        end
        
        self:setup_shop_state_detection()
    end
end

function BalatroMCP:hook_game_start()
    print("BalatroMCP: Setting up game start hooks")
    
    if G.FUNCS then
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
    print("BalatroMCP: Joker interaction hooks set up")
end

function BalatroMCP:cleanup_hooks()
    print("BalatroMCP: Cleaning up game hooks")
end

function BalatroMCP:process_pending_actions()
    if self.processing_action then
        return
    end
    
    local message_data = self.message_manager:read_actions()
    if not message_data then
        return
    end
    
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
    
    print("BalatroMCP: Deferring state extraction to next update cycle")
    self.pending_state_extraction = true
    self.pending_action_result = {
        sequence = sequence,
        action_type = action_data.action_type,
        success = result.success,
        error_message = result.error_message,
        timestamp = os.time()
        }
    
    
    if result.success then
        print("BalatroMCP: Action completed successfully")
    else
        print("BalatroMCP: Action failed: " .. (result.error_message or "Unknown error"))
    end
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
end

function BalatroMCP:check_and_send_state_update()
    local current_state = self.state_extractor:extract_current_state()
    
    local g_state = G and G.STATE or "NIL"
    local phase = current_state.current_phase or "NIL"
    local money = current_state.money or "NIL"
    local ante = current_state.ante or "NIL"
    
    local state_hash = self:calculate_state_hash(current_state)
    
    
    if state_hash ~= self.last_state_hash then
        self.last_state_hash = state_hash
        self:send_state_update(current_state)
    end
end

function BalatroMCP:send_current_state()
    local current_state = self.state_extractor:extract_current_state()
    if current_state then
        self:send_state_update(current_state)
    end
end

function BalatroMCP:send_state_update(state)
    local state_message = {
        message_type = "state_update",
        timestamp = os.time(),
        sequence = self.message_manager:get_next_sequence_id(),
        state = state
    }
    
    self.message_manager:write_game_state(state_message)
    print("BalatroMCP: State update sent")
    
    -- Extract and send deck state alongside game state
    local deck_cards = self.state_extractor:extract_deck_cards()
    local deck_message = {
        message_type = "deck_update",
        timestamp = os.time(),
        sequence = self.message_manager:get_next_sequence_id(),
        deck_cards = deck_cards
    }
    
    self.message_manager:write_deck_state(deck_message)
    print("BalatroMCP: Deck state sent with " .. #deck_cards .. " cards")
    
    -- Extract and send remaining deck state alongside game state
    local remaining_deck_cards = self.state_extractor:extract_remaining_deck_cards()
    local remaining_deck_message = {
        message_type = "remaining_deck_update",
        timestamp = os.time(),
        sequence = self.message_manager:get_next_sequence_id(),
        remaining_deck_cards = remaining_deck_cards
    }
    
    self.message_manager:write_remaining_deck(remaining_deck_message)
    print("BalatroMCP: Remaining deck state sent with " .. #remaining_deck_cards .. " cards")
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

function BalatroMCP:on_hand_played()
    print("BalatroMCP: Hand played event")
    self:send_current_state()
end

function BalatroMCP:on_cards_discarded()
    print("BalatroMCP: Cards discarded event")
    self:send_current_state()
end

function BalatroMCP:on_blind_selected()
    print("BalatroMCP: Blind selection transition detected")
    
    self.blind_transition_cooldown = 3.0
    
    self.delayed_blind_state_capture = true
    self.delayed_blind_capture_timer = 1.0  -- Wait 1 second for transition to complete
end

function BalatroMCP:on_shop_entered()
    print("BalatroMCP: Shop entered event - delaying state capture for shop population")
    
    local current_state = self.state_extractor:extract_current_state()
    local phase = current_state and current_state.current_phase or "unknown"
    local money = current_state and current_state.money or "unknown"
    local shop_items = current_state and current_state.shop_contents and #current_state.shop_contents or 0
    print("BalatroMCP: DEBUG - Hook fired with state: phase=" .. phase .. ", money=" .. tostring(money) .. ", shop_items=" .. tostring(shop_items))
    
    self.delayed_shop_state_capture = true
    self.delayed_shop_capture_timer = 1.0  -- Wait 1.0 seconds for shop to populate
end

function BalatroMCP:setup_shop_state_detection()
    print("BalatroMCP: Setting up shop state detection")
    
    self.last_shop_state = nil
    self.shop_state_initialized = false
end

function BalatroMCP:detect_blind_selection_transition()
    if not G or not G.STATE or not G.STATES then
        return
    end
    
    local current_state = G.STATE
    
    if not self.last_blind_state then
        self.last_blind_state = current_state
        return
    end
    
    if self.blind_transition_cooldown > 0 then
        return
    end
    
    local was_blind_select = (self.last_blind_state == G.STATES.BLIND_SELECT)
    local is_hand_select = (current_state == G.STATES.SELECTING_HAND or current_state == G.STATES.DRAW_TO_HAND)
    
    if was_blind_select and is_hand_select then
        print("BalatroMCP: NON_INTRUSIVE_DETECTION - Blind selection completed: " .. 
              tostring(self.last_blind_state) .. " -> " .. tostring(current_state))
        self:on_blind_selected()
    end
    
    self.last_blind_state = current_state
end

function BalatroMCP:detect_shop_state_transition()
    if not G or not G.STATE or not G.STATES then
        return
    end
    
    local current_state = G.STATE
    
    if not self.last_shop_state then
        self.last_shop_state = current_state
        self.shop_state_initialized = false
        return
    end
    
    if self.delayed_shop_state_capture then
        return
    end
    
    local was_not_shop = (self.last_shop_state ~= G.STATES.SHOP)
    local is_shop = (current_state == G.STATES.SHOP)
    
    if was_not_shop and is_shop and not self.shop_state_initialized then
        print("BalatroMCP: NON_INTRUSIVE_DETECTION - Shop state entered: " ..
              tostring(self.last_shop_state) .. " -> " .. tostring(current_state))
        
        self.shop_state_initialized = true
        self:on_shop_entered()
    end
    
    if current_state ~= G.STATES.SHOP then
        self.shop_state_initialized = false
    end
    
    self.last_shop_state = current_state
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

if SMODS then
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