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

local StateExtractor = require("state_extractor.state_extractor")

return StateExtractor