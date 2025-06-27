-- Entry point facade for refactored StateExtractor
-- This file maintains backward compatibility while using the new modular architecture
-- 
-- The original StateExtractor has been refactored into a modular system located in:
-- state_extractor/state_extractor.lua - Main orchestrator
-- state_extractor/extractors/ - Specialized extraction components
-- state_extractor/utils/ - Shared utility functions
--
-- All original method signatures and behavior are preserved for seamless integration
-- with existing code that depends on the StateExtractor interface.
--
-- Original implementation preserved in: state_extractor_original.lua

-- Load the main StateExtractor using SMODS for compatibility
local StateExtractor = nil
if SMODS then
    local success, extractor_or_error = pcall(function()
        return assert(SMODS.load_file("state_extractor/state_extractor.lua"))()
    end)
    
    if success then
        StateExtractor = extractor_or_error
    else
        error("Failed to load state_extractor/state_extractor.lua: " .. tostring(extractor_or_error))
    end
else
    error("SMODS not available - StateExtractor requires SMODS framework")
end

return StateExtractor