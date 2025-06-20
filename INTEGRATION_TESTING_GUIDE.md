# Balatro MCP Integration Testing Guide

## Quick Start Testing Instructions

### Step 1: Install the Enhanced Debug Mod
1. Copy the entire `mod/` directory to your Balatro mods folder:
   - Windows: `%APPDATA%/Balatro/Mods/BalatroMCP/`
   - Steam: `steamapps/common/Balatro/Mods/BalatroMCP/`

2. Ensure all files are present:
   - `manifest.json` (updated with debug_logger.lua)
   - `BalatroMCP.lua` (enhanced with comprehensive error handling)
   - `debug_logger.lua` (new comprehensive debugging system)
   - `file_io.lua` (enhanced with detailed logging)
   - `state_extractor.lua` (enhanced with G object validation)
   - `action_executor.lua`
   - `joker_manager.lua`

### Step 2: Launch Balatro with Debug Logging
1. Start Balatro with SteamModded enabled
2. Watch console output for "BalatroMCP" debug messages
3. Check if `shared/` directory is created in Balatro root
4. Look for debug log files in `shared/` directory

### Step 3: Analyze Debug Output

#### Expected Success Indicators:
```
BalatroMCP [DEBUG_LOGGER]: Debug logger initialized for session: session_XXXXXXX
BalatroMCP [DEBUG_LOGGER]: === ENVIRONMENT TESTING ===
BalatroMCP [DEBUG_LOGGER]: Lua version: Lua 5.X
BalatroMCP [DEBUG_LOGGER]: love.filesystem available
BalatroMCP [DEBUG_LOGGER]: JSON library available
BalatroMCP [DEBUG_LOGGER]: Global G object available
BalatroMCP [FILE_IO]: JSON library loaded successfully
BalatroMCP [FILE_IO]: love.filesystem available
BalatroMCP [FILE_IO]: Directory creation successful: shared
BalatroMCP [STATE_EXTRACTOR]: G object exists
BalatroMCP [INIT]: BalatroMCP: Mod initialized successfully
```

#### Critical Failure Indicators to Look For:
```
ERROR: JSON library NOT available
CRITICAL: love.filesystem not available
CRITICAL: Global G object is nil
ERROR: G.GAME object not available
Missing X critical properties: STATE, GAME, hand, jokers
```

### Step 4: Test Game State Extraction
1. Start a new game or load existing save
2. Look for state extraction messages:
```
BalatroMCP [STATE_EXTRACTOR]: === EXTRACTING CURRENT GAME STATE ===
BalatroMCP [STATE_EXTRACTOR]: Extracted session_id successfully
BalatroMCP [STATE_EXTRACTOR]: STATE EXTRACTION COMPLETED SUCCESSFULLY
```

3. Check `shared/game_state.json` for actual extracted data

### Step 5: Test MCP Server Communication
1. Start the Python MCP server:
```bash
cd server
python main.py
```

2. Monitor both debug logs and server output for communication

## Diagnostic Scenarios

### Scenario 1: JSON Library Missing
**Symptoms**: 
- `ERROR: JSON library NOT available`
- `CRITICAL: No JSON library available - communication will fail`

**Resolution**: The mod will attempt alternative JSON libraries (cjson, dkjson, json.lua). If all fail, we need to implement a basic JSON encoder in Lua.

### Scenario 2: Love2D Filesystem Not Available
**Symptoms**:
- `CRITICAL: love.filesystem not available`
- `ERROR: Directory creation failed`

**Resolution**: Fall back to standard Lua io operations with absolute file paths.

### Scenario 3: G Object Structure Mismatch
**Symptoms**:
- `MISSING: G.STATE is nil`
- `ERROR: G.GAME.current_round.hands_left is nil`
- `ERROR: G.hand.cards is nil`

**Resolution**: The debug logs will show actual available G object properties. We'll need to adapt our extraction logic to match Balatro's actual internal structure.

### Scenario 4: Steammodded Hook Failures
**Symptoms**:
- Mod loads but no game events are captured
- `WARNING: G.FUNCS.play_cards_from_highlighted is nil`

**Resolution**: Use alternative hooking mechanisms or polling-based state monitoring.

## Debug Log Analysis

### Key Log Files to Monitor:

1. **`shared/debug.log`** - Main initialization and environment testing
2. **`shared/file_io_debug.log`** - File operations and JSON handling
3. **`shared/game_state.json`** - Latest extracted game state (if working)
4. **Console output** - Real-time debugging messages

### Critical Log Patterns:

#### Environment Validation:
```
G object keys: CARD_W, FUNCS, GAME, STATE, STATES, hand, jokers, ...
G.STATES keys: SELECTING_HAND, SHOP, BLIND_SELECT, DRAW_TO_HAND, ...
G.FUNCS keys: play_cards_from_highlighted, discard_cards_from_highlighted, ...
```

#### Card Structure Validation:
```
hand[1].base keys: value, suit, nominal, ...
hand[1].base.value = King
hand[1].base.suit = Hearts
```

#### Communication Testing:
```
File write test: SUCCESS
JSON encode test: SUCCESS
JSON decode test: SUCCESS
```

## Performance Testing

### Test Load Impact:
1. Play several hands with debugging enabled
2. Monitor for any gameplay lag or stuttering
3. Check if mod affects game performance negatively
4. Ensure debug logging doesn't cause memory leaks

### Test Memory Usage:
```lua
-- Add to debug logger:
if collectgarbage then
    local mem_before = collectgarbage("count")
    -- ... operations ...
    local mem_after = collectgarbage("count")
    self:log("Memory usage: " .. (mem_after - mem_before) .. " KB")
end
```

## Integration Success Criteria

### Phase 1 Success (Basic Loading):
- [ ] Mod loads without Lua errors
- [ ] All components initialize successfully
- [ ] Debug logs are created and populated
- [ ] No interference with normal gameplay

### Phase 2 Success (Communication):
- [ ] Game state extraction works without errors
- [ ] JSON files are created with valid structure
- [ ] MCP server can read game state files
- [ ] File sequence tracking prevents duplicates

### Phase 3 Success (State Accuracy):
- [ ] Extracted game data matches actual game state
- [ ] Card information is accurate
- [ ] Joker data is complete and correct
- [ ] Money, ante, round data is accurate

### Phase 4 Success (Action Execution):
- [ ] At least play_hand action executes successfully
- [ ] Actions affect game state as expected
- [ ] Invalid actions are rejected gracefully
- [ ] Action results are communicated back

### Phase 5 Success (Production Ready):
- [ ] All action types work correctly
- [ ] Error handling prevents crashes
- [ ] Joker reordering works for Blueprint/Brainstorm
- [ ] Mod can be safely disabled/enabled

## Troubleshooting Common Issues

### Issue: Mod Doesn't Load
1. Check Steammodded is enabled
2. Verify manifest.json syntax
3. Check file permissions
4. Look for Lua syntax errors in console

### Issue: No Debug Output
1. Verify console output is enabled in Balatro
2. Check if shared/ directory was created
3. Try manual debug.log creation test
4. Verify write permissions

### Issue: State Extraction Fails
1. Check G object validation logs
2. Verify game is in expected state
3. Test with fresh game vs loaded save
4. Check for timing-sensitive extraction

### Issue: Actions Don't Execute
1. Verify G.FUNCS availability in logs
2. Check game phase when action attempted
3. Test with simple actions first (sort_hand)
4. Verify card/joker indices are valid

## Next Steps After Testing

Based on test results, create issues for:

1. **Structural Fixes**: Update code to match actual Balatro internals
2. **Fallback Implementation**: Add compatibility layers for missing dependencies
3. **Performance Optimization**: Reduce debug overhead for production
4. **Error Recovery**: Improve graceful degradation for edge cases
5. **Documentation Updates**: Document actual vs expected game structures

## Support Information

If testing reveals critical incompatibilities:

1. **Save all debug logs** - Essential for diagnosing issues
2. **Document Balatro version** - Game updates may change internals
3. **Test with minimal mod set** - Isolate mod conflicts
4. **Provide game save files** - For reproducing specific issues

This systematic approach will provide comprehensive validation of our diagnostic assumptions and clear evidence for any necessary fixes.