-- Main Balatro MCP mod file
-- Integrates all components and manages communication with MCP server

--- STEAMMODDED HEADER
--- MOD_NAME: BalatroMCP
--- MOD_ID: BalatroMCP
--- MOD_AUTHOR: [MCP Integration]
--- MOD_DESCRIPTION: Enables AI agent interaction with Balatro through MCP protocol

-- Import modules
local DebugLogger = require('debug_logger')
local FileIO = require('file_io')
local StateExtractor = require('state_extractor')
local ActionExecutor = require('action_executor')
local JokerManager = require('joker_manager')

-- Main mod class
local BalatroMCP = {}
BalatroMCP.__index = BalatroMCP

function BalatroMCP.new()
    local self = setmetatable({}, BalatroMCP)
    
    -- Initialize debug logger first
    self.debug_logger = DebugLogger.new()
    self.debug_logger:info("=== BALATRO MCP INITIALIZATION STARTED ===", "INIT")
    
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
        self.debug_logger:info("JokerManager component initialized successfully", "INIT")
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
    
    self.update_timer = self.update_timer + dt
    
    if self.update_timer >= self.update_interval then
        self.update_timer = 0
        
        -- Check for pending actions
        self:process_pending_actions()
        
        -- Send state updates if changed
        self:check_and_send_state_update()
    end
end

function BalatroMCP:setup_game_hooks()
    -- Set up hooks for important game events
    print("BalatroMCP: Setting up game hooks")
    
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
    -- Hook hand evaluation events
    if G.FUNCS then
        local original_play_cards = G.FUNCS.play_cards_from_highlighted
        if original_play_cards then
            G.FUNCS.play_cards_from_highlighted = function(...)
                print("BalatroMCP: Hand played - capturing state")
                local result = original_play_cards(...)
                self:on_hand_played()
                return result
            end
        end
        
        local original_discard_cards = G.FUNCS.discard_cards_from_highlighted
        if original_discard_cards then
            G.FUNCS.discard_cards_from_highlighted = function(...)
                print("BalatroMCP: Cards discarded - capturing state")
                local result = original_discard_cards(...)
                self:on_cards_discarded()
                return result
            end
        end
    end
end

function BalatroMCP:hook_blind_selection()
    -- Hook blind selection events
    if G.FUNCS then
        local original_select_blind = G.FUNCS.select_blind
        if original_select_blind then
            G.FUNCS.select_blind = function(...)
                print("BalatroMCP: Blind selected - capturing state")
                local result = original_select_blind(...)
                self:on_blind_selected()
                return result
            end
        end
    end
end

function BalatroMCP:hook_shop_interactions()
    -- Hook shop interaction events
    if G.FUNCS then
        local original_go_to_shop = G.FUNCS.go_to_shop
        if original_go_to_shop then
            G.FUNCS.go_to_shop = function(...)
                print("BalatroMCP: Entered shop - capturing state")
                local result = original_go_to_shop(...)
                self:on_shop_entered()
                return result
            end
        end
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
    
    local action_data = self.file_io:read_action()
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
    
    -- Execute the action
    local result = self.action_executor:execute_action(action_data)
    
    -- Send response back to MCP server
    local response = {
        sequence = sequence,
        action_type = action_data.action_type,
        success = result.success,
        error_message = result.error_message,
        timestamp = os.time(),
        new_state = result.new_state
    }
    
    self.file_io:write_response(response)
    
    self.processing_action = false
    
    if result.success then
        print("BalatroMCP: Action completed successfully")
    else
        print("BalatroMCP: Action failed: " .. (result.error_message or "Unknown error"))
    end
end

function BalatroMCP:check_and_send_state_update()
    -- Check if game state has changed and send update if needed
    local current_state = self.state_extractor:extract_current_state()
    if not current_state then
        return
    end
    
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
        sequence = self.file_io:get_next_sequence(),
        state = state
    }
    
    self.file_io:write_state(state_message)
    print("BalatroMCP: State update sent")
end

function BalatroMCP:calculate_state_hash(state)
    -- Simple hash calculation for state change detection
    -- This is a basic implementation - could be improved
    local hash_components = {}
    
    if state.game_phase then
        table.insert(hash_components, state.game_phase)
    end
    
    if state.round then
        table.insert(hash_components, tostring(state.round))
    end
    
    if state.ante then
        table.insert(hash_components, tostring(state.ante))
    end
    
    if state.dollars then
        table.insert(hash_components, tostring(state.dollars))
    end
    
    if state.hand and state.hand.cards then
        table.insert(hash_components, tostring(#state.hand.cards))
    end
    
    if state.jokers and state.jokers.cards then
        table.insert(hash_components, tostring(#state.jokers.cards))
    end
    
    return table.concat(hash_components, "|")
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
    self:send_current_state()
end

-- Steammodded integration
local mod_instance = nil

function SMODS.INIT.BalatroMCP()
    -- Initialize the mod when Steammodded loads it
    print("BalatroMCP: Initializing through Steammodded")
    
    mod_instance = BalatroMCP.new()
    
    -- Start the MCP integration
    mod_instance:start()
end

function SMODS.UPDATE.BalatroMCP(dt)
    -- Update function called by Steammodded
    if mod_instance then
        mod_instance:update(dt)
    end
end

function SMODS.QUIT.BalatroMCP()
    -- Cleanup when quitting
    print("BalatroMCP: Cleaning up on quit")
    if mod_instance then
        mod_instance:stop()
    end
end

-- Global access for debugging
_G.BalatroMCP = mod_instance

return BalatroMCP