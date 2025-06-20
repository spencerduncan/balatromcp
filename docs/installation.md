# Installation Guide: Balatro MCP Integration

> **Get ready to merge AI with Balatro's addictive mechanics.** This guide will have you up and running with superhuman card mastery in minutes.

## Prerequisites

Before diving into the installation, ensure your system can handle the power:

### System Requirements
- **Python 3.8+** (The neural pathways of our system)
- **Balatro** (Your testing ground)
- **Steamodded 1.0+** (The modification framework that makes magic possible)
- **Windows/macOS/Linux** (Cross-platform domination)

### Verify Your Python Installation
```bash
python --version
# Should output: Python 3.8.x or higher
```

If Python isn't installed, download from [python.org](https://python.org) and choose the latest 3.8+ version.

## Step 1: Install Steamodded for Balatro

**First, we need to prepare Balatro for AI integration.**

### Option A: Automatic Installation (Recommended)
1. Navigate to the [Steamodded GitHub releases](https://github.com/Steamopollys/Steamodded/releases)
2. Download the latest release for your platform
3. Extract the contents to your Balatro installation directory
4. Launch Balatro - you should see "Steamodded" in the main menu

### Option B: Manual Installation
1. Locate your Balatro installation:
   - **Steam**: `Steam/steamapps/common/Balatro/`
   - **Direct**: Where you installed Balatro
2. Download Steamodded source code
3. Copy the Steamodded files to your Balatro directory
4. Ensure the file structure matches the Steamodded documentation

### Verify Steamodded Installation
Launch Balatro and confirm:
- ✅ "Mods" option appears in the main menu
- ✅ No error messages on startup
- ✅ Game loads normally

**If you encounter issues:** Check the [Steamodded troubleshooting guide](https://github.com/Steamopollys/Steamodded#troubleshooting)

## Step 2: Install the Balatro MCP Mod

**Now we install the neural bridge between AI and game.**

### Locate Your Mods Directory
The Steamodded mods directory is typically:
- **Windows**: `%APPDATA%/Balatro/Mods/`
- **macOS**: `~/Library/Application Support/Balatro/Mods/`
- **Linux**: `~/.local/share/Balatro/Mods/`

If the directory doesn't exist, create it manually.

### Install the BalatroMCP Mod
1. **Clone or download this repository:**
   ```bash
   git clone https://github.com/your-repo/balatro-mcp.git
   cd balatro-mcp
   ```

2. **Copy the mod files:**
   ```bash
   # Copy the entire mod directory to your Steamodded mods folder
   cp -r mod/ "path/to/your/mods/directory/BalatroMCP/"
   ```

3. **Verify the installation:**
   Your mods directory should now contain:
   ```
   Mods/
   └── BalatroMCP/
       ├── BalatroMCP.lua
       ├── manifest.json
       ├── action_executor.lua
       ├── debug_logger.lua
       ├── file_io.lua
       ├── joker_manager.lua
       └── state_extractor.lua
   ```

### Test the Mod Installation
1. Launch Balatro
2. Navigate to **Mods** in the main menu
3. Confirm **BalatroMCP** appears in the mod list
4. Enable the mod if it's not already active
5. Start a new run - you should see initialization messages in the console

**Expected console output:**
```
BalatroMCP: Mod initialized successfully
BalatroMCP: Starting MCP integration
BalatroMCP: MCP integration started
```

## Step 3: Set Up the Python MCP Server

**Time to unleash the AI controller.**

### Install Python Dependencies
Navigate to the server directory and install requirements:

```bash
cd server/
pip install -r requirements.txt
```

**Key dependencies being installed:**
- `mcp>=1.0.0` - Model Context Protocol implementation
- `pydantic>=2.0.0` - Data validation and serialization
- `asyncio-mqtt>=0.16.0` - Async communication support
- Development tools for testing and debugging

### Verify Server Installation
Run the test suite to ensure everything is working:

```bash
# Run all tests
python -m pytest

# Expected output:
# ========================= test session starts =========================
# ...
# ========================= 229 passed in X.XXs =========================
```

**If tests fail:** Check that all dependencies installed correctly and Python version is 3.8+.

### Create Communication Directory
The system uses shared JSON files for communication:

```bash
# Create the shared directory (if it doesn't exist)
mkdir -p shared/
```

## Step 4: Initial System Test

**Let's verify the complete integration works.**

### Terminal 1: Start Balatro with Mod
1. Launch Balatro through Steam or directly
2. Load the BalatroMCP mod if not auto-loaded
3. Start a new run
4. Watch for mod initialization messages

### Terminal 2: Start MCP Server
```bash
cd server/
python -m main
```

**Expected server output:**
```
INFO - BalatroFileIO initialized with base path: shared
INFO - BalatroStateManager initialized  
INFO - BalatroActionHandler initialized
INFO - BalatroMCPServer initialized
INFO - BalatroMCPServer started
```

### Terminal 3: Test Communication
Check that communication files are being created:

```bash
cd shared/
ls -la

# You should see:
# game_state.json (updated regularly)
# Other files appear as actions are executed
```

### Verify Game State Extraction
The `game_state.json` file should contain structured data like:
```json
{
  "timestamp": "2024-01-01T12:00:00Z",
  "sequence_id": 1,
  "message_type": "game_state",
  "data": {
    "session_id": "unique-session-id",
    "current_phase": "hand_selection",
    "ante": 1,
    "money": 4,
    "hands_remaining": 4,
    "discards_remaining": 3,
    "hand_cards": [...],
    "jokers": [...],
    "available_actions": ["play_hand", "discard_cards", ...]
  }
}
```

## Step 5: Connect Your AI Agent

**Now for the moment of truth - AI control.**

### Basic MCP Client Setup
```python
import asyncio
from mcp import ClientSession

async def test_connection():
    async with ClientSession("stdio", command=["python", "-m", "server.main"]) as session:
        # Test resource access
        resources = await session.list_resources()
        print(f"Available resources: {[r.name for r in resources.resources]}")
        
        # Test tool access
        tools = await session.list_tools()
        print(f"Available tools: {[t.name for t in tools.tools]}")
        
        # Read current game state
        state = await session.read_resource("balatro://game-state")
        print(f"Current game phase: {state}")

# Run the test
asyncio.run(test_connection())
```

### Expected Output
```
Available resources: ['Current Game State', 'Available Actions', 'Joker Order']
Available tools: ['get_game_state', 'play_hand', 'discard_cards', 'go_to_shop', ...]
Current game phase: {'current_phase': 'hand_selection', 'ante': 1, ...}
```

## Troubleshooting

### Common Issues

**"Mod not loading"**
- Verify Steamodded is installed correctly
- Check that mod files are in the correct directory
- Look for error messages in Balatro console

**"Python import errors"**
- Ensure Python 3.8+ is installed
- Verify all requirements.txt dependencies installed
- Check that you're running from the correct directory

**"No communication files created"**
- Confirm both Balatro mod and Python server are running
- Check file permissions on the shared/ directory
- Verify mod initialization messages appeared

**"Connection timeout"**
- Ensure both mod and server are running simultaneously
- Check that shared/ directory is accessible to both processes
- Verify no firewall or antivirus interference

### Debug Mode
Enable detailed logging by setting environment variable:
```bash
export BALATRO_MCP_DEBUG=1
python -m server.main
```

### Advanced Diagnostics
The mod includes comprehensive debug logging. Check the Balatro console for detailed error messages and system status.

## Next Steps

🎉 **Congratulations!** Your Balatro MCP system is now operational.

**Continue to:**
- [Usage Guide](usage.md) - Learn to control Balatro with AI
- [API Reference](api-reference.md) - Master all available actions
- [Developer Guide](developer-guide.md) - Extend and customize the system

**Ready to witness AI mastery of Balatro's deepest strategies?** Your next stop is the [Usage Guide](usage.md).

---

*Installation complete. The AI revolution in Balatro begins now.*