-- Example usage of the refactored file I/O architecture
-- Demonstrates both direct usage and backward compatibility

-- Method 1: Direct usage of new architecture (recommended for new code)
local MessageManager = require("message_manager")
local FileTransport = require("transports.file_transport")

local function example_direct_usage()
    print("=== Direct Usage Example ===")
    
    -- Create transport and message manager
    local transport = FileTransport.new("shared")
    local manager = MessageManager.new(transport, "EXAMPLE")
    
    -- Write game state
    local game_state = {
        health = 100,
        score = 1500,
        level = 3
    }
    
    local success = manager:write_game_state(game_state)
    print("Game state write success:", success)
    
    -- Write deck state
    local deck_state = {
        cards = {"ace", "king", "queen"},
        deck_size = 52
    }
    
    success = manager:write_deck_state(deck_state)
    print("Deck state write success:", success)
    
    -- Cleanup old messages
    success = manager:cleanup_old_messages(300)
    print("Cleanup success:", success)
end

-- Method 2: Backward compatibility usage (for existing code)
local FileIO = require("compatibility.file_io_wrapper")

local function example_compatibility_usage()
    print("=== Backward Compatibility Example ===")
    
    -- Use exactly like the old FileIO
    local file_io = FileIO.new("shared")
    
    -- All existing methods work the same
    local game_state = {
        health = 100,
        score = 1500,
        level = 3
    }
    
    local success = file_io:write_game_state(game_state)
    print("Game state write success:", success)
    
    local deck_state = {
        cards = {"ace", "king", "queen"},
        deck_size = 52
    }
    
    success = file_io:write_deck_state(deck_state)
    print("Deck state write success:", success)
    
    -- Read actions (if any exist)
    local actions = file_io:read_actions()
    if actions then
        print("Actions received:", actions.message_type)
    else
        print("No actions available")
    end
    
    -- Cleanup
    file_io:cleanup_old_files(300)
end

-- Method 3: Interface flexibility example (for future extensions)
local function example_interface_flexibility()
    print("=== Interface Flexibility Example ===")
    
    -- This demonstrates how easy it would be to swap transports
    local file_transport = FileTransport.new("shared")
    local manager = MessageManager.new(file_transport, "FLEXIBLE")
    
    -- The MessageManager doesn't care what transport is used
    -- In the future, we could easily swap to HttpTransport or DatabaseTransport
    
    print("Transport is available:", file_transport:is_available())
    print("Manager ready for any transport type")
end

-- Usage examples (commented out to prevent execution during require)
--[[
example_direct_usage()
example_compatibility_usage() 
example_interface_flexibility()
--]]

return {
    example_direct_usage = example_direct_usage,
    example_compatibility_usage = example_compatibility_usage,
    example_interface_flexibility = example_interface_flexibility
}