# Balatro MCP Integration Testing Plan

## Testing Strategy Overview

Based on my analysis of the codebase, I've identified the most likely sources of integration issues and created comprehensive debugging systems to validate them.

## Primary Risk Assessment

### Most Likely Issues (1-2):
1. **Balatro Internal Structure Mismatches** - Our state extraction assumes specific G object structures
2. **JSON/File System Dependencies** - Core communication relies on external libraries that may not be available

### Secondary Risks (3-7):
3. **Steammodded Integration Problems** - Manifest or hook implementation issues
4. **Game Function Hook Failures** - G.FUNCS may not exist as expected
5. **Module Loading Issues** - Lua require() path problems in Steammodded
6. **Communication Protocol Timing** - File polling synchronization issues
7. **Card/Joker Data Structure Assumptions** - Specific property expectations may be wrong

## Debugging Enhancements Added

### 1. Comprehensive Debug Logger (`debug_logger.lua`)
- Environment capability testing (Lua version, Love2D, JSON library)
- G object structure analysis and validation
- File system operation testing
- Component-specific logging with timestamps

### 2. Enhanced File I/O Module (`file_io.lua`)
- JSON library availability testing with fallback options
- Directory creation validation
- File operation error logging
- Message sequence tracking verification

### 3. Enhanced State Extractor (`state_extractor.lua`)
- G object structure validation on initialization
- Individual component extraction error handling
- Card/joker structure validation
- Game state enumeration testing

### 4. Main Module Integration (`BalatroMCP.lua`)
- Component initialization error handling
- Environment testing on startup
- Communication system validation

## Testing Phases

### Phase 1: Mod Loading Verification
**Objective**: Verify the mod loads correctly in Balatro through SteamModded

**Test Steps**:
1. Install mod in Balatro/Mods directory
2. Launch Balatro with SteamModded
3. Check for mod initialization messages in console
4. Verify debug log creation in `shared/debug.log`

**Expected Results**:
- No Lua errors during mod loading
- Debug logger reports successful environment testing
- All components initialize without errors
- File system operations complete successfully

**Potential Issues & Diagnostics**:
- **JSON library missing**: Debug log will show "JSON library NOT available"
- **Love2D filesystem issues**: Log will show "love.filesystem NOT available"
- **G object missing**: Log will show "Global G object NOT available"
- **Module loading failures**: Component initialization errors in logs

### Phase 2: Communication Protocol Testing
**Objective**: Test file-based JSON communication between mod and MCP server

**Test Steps**:
1. Start MCP server with monitoring
2. Trigger game state extraction from mod
3. Verify JSON files are created and readable
4. Test action file processing
5. Verify sequence tracking works correctly

**Expected Results**:
- `shared/game_state.json` created with valid structure
- Server can read and parse game state files
- Action files are processed and removed correctly
- Sequence IDs prevent duplicate processing

**Potential Issues & Diagnostics**:
- **File creation failures**: File I/O debug logs will show write errors
- **JSON encoding/decoding issues**: Specific error messages in logs
- **Permission problems**: File system operation failures
- **Sequence synchronization**: Duplicate or missed actions

### Phase 3: Game State Extraction Debugging
**Objective**: Test state extractor against actual Balatro internal structures

**Test Steps**:
1. Load a game session
2. Trigger state extraction at different game phases
3. Validate extracted data against actual game state
4. Test edge cases (empty hand, no jokers, etc.)

**Expected Results**:
- All game state components extracted without errors
- Card data matches actual hand contents
- Joker information is accurate
- Money, ante, and round data is correct

**Potential Issues & Diagnostics**:
- **G object structure mismatches**: Validation logs will show missing properties
- **Card data structure issues**: Card validation will fail
- **Game phase detection problems**: State detection errors
- **Missing game components**: Extraction errors for specific areas

### Phase 4: Action Execution Testing
**Objective**: Test action executor can successfully execute game actions

**Test Steps**:
1. Send play_hand action through MCP
2. Verify cards are selected and played correctly
3. Test shop interactions (buy/sell)
4. Test joker reordering functionality
5. Verify error handling for invalid actions

**Expected Results**:
- Actions execute without Lua errors
- Game state changes as expected
- Invalid actions are rejected gracefully
- Action results are communicated back correctly

**Potential Issues & Diagnostics**:
- **G.FUNCS missing**: Action executor will report function unavailable
- **Card selection failures**: Index validation errors
- **Game timing issues**: Actions attempted at wrong game phase
- **Hook integration problems**: Game functions don't behave as expected

### Phase 5: Error Handling and Edge Cases
**Objective**: Test mod behavior during various game state transitions

**Test Steps**:
1. Test during round transitions
2. Test during blind selection
3. Test with empty collections (no jokers, no consumables)
4. Test recovery from communication failures
5. Test mod disable/enable functionality

**Expected Results**:
- Mod handles state transitions gracefully
- Empty collections don't cause errors
- Communication failures don't crash the mod
- Mod can be safely disabled and re-enabled

## Success Criteria

### Minimum Viable Integration:
- [ ] Mod loads without errors in Balatro/SteamModded
- [ ] Basic game state extraction works
- [ ] File-based communication established
- [ ] At least one action (play_hand) executes successfully

### Full Integration Success:
- [ ] All game state components extract correctly
- [ ] All action types execute successfully
- [ ] Error handling works properly
- [ ] No interference with normal gameplay
- [ ] Joker reordering works for Blueprint/Brainstorm strategy

## Diagnostic Log Analysis

The debug system will create several log files in the `shared/` directory:

1. **`debug.log`** - Main debug logger output with environment testing
2. **`file_io_debug.log`** - File I/O operations and JSON handling
3. **`game_state.json`** - Latest game state (if successful)
4. **`actions.json`** - Pending actions from server
5. **`action_results.json`** - Action execution results

## Next Steps After Testing

Based on test results, we'll need to:

1. **Fix identified structural mismatches** between our assumptions and actual Balatro internals
2. **Implement fallback strategies** for missing libraries or functions
3. **Adjust communication timing** if synchronization issues are found
4. **Refine error handling** based on actual failure modes discovered
5. **Optimize performance** if gameplay interference is detected

## Risk Mitigation

If critical dependencies are missing:
- **No JSON library**: Implement simple JSON encoder/decoder in Lua
- **No Love2D filesystem**: Use Lua's built-in io operations with file paths
- **G object structure different**: Create compatibility layer with actual structures
- **Missing game functions**: Implement alternative approaches or graceful degradation

This comprehensive testing approach will systematically validate each component while providing detailed diagnostics to identify and resolve integration issues.