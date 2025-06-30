# BalatroMCP MCP Server

A Model Context Protocol (MCP) server that provides compatibility with the BalatroMCP mod's file-based interface. This server allows AI agents to interact with Balatro through the MCP protocol while maintaining full compatibility with the existing BalatroMCP mod's shared file system.

## Features

- **File Interface Compatibility**: Reads and writes the same JSON files as BalatroMCP mod
- **Real-time Updates**: File watching for live game state changes
- **Complete Action Support**: All BalatroMCP action types supported
- **MCP Protocol Compliance**: Standard MCP server implementation
- **Structured Data Access**: Game state, deck state, hand levels, vouchers data

## Installation

```bash
cd mcp-server
npm install
npm run build
```

## Usage

### 🚀 Quick Start with Startup Scripts

**Linux/macOS (Recommended):**
```bash
# Full startup with tests and integration checks
./start-mcp-server.sh

# Quick start without tests
./start-mcp-server.sh --no-tests

# Show all options
./start-mcp-server.sh --help
```

**Windows (PowerShell):**
```powershell
# Full startup with tests
.\start-mcp-server.ps1

# Quick start without tests  
.\start-mcp-server.ps1 -NoTests

# Show help
.\start-mcp-server.ps1 -Help
```

**Windows (Double-click):**
```
Double-click: start-mcp-server.bat
```

**npm Scripts:**
```bash
# Linux/macOS
npm run startup

# Windows  
npm run startup-win
```

### Manual Startup

If you prefer manual control:
```bash
npm install
npm run build
npm start
```

### Configuration

Configure your MCP client to connect to this server. For Claude Desktop, add to your configuration:

```json
{
  "mcpServers": {
    "balatromcp": {
      "command": "node",
      "args": ["/path/to/balatromcp/mcp-server/dist/index.js"],
      "env": {
        "SHARED_DIR": "/path/to/balatro/shared"
      }
    }
  }
}
```

## Available Resources

The server provides these MCP resources:

- `balatromcp://game_state` - Current game state (hand cards, money, phase, etc.)
- `balatromcp://deck_state` - Deck composition and card information  
- `balatromcp://hand_levels` - Poker hand statistics and levels
- `balatromcp://vouchers_ante` - Voucher information and ante requirements

## Available Tools

### execute_action

Execute BalatroMCP actions with the mod:

```typescript
{
  "action_type": "play_hand",
  "parameters": {
    "card_indices": [0, 1, 2, 3, 4]
  }
}
```

Supported action types:
- `skip_blind` - Skip current blind
- `select_blind` - Select blind type (small/big/boss)
- `play_hand` - Play selected cards
- `discard_cards` - Discard selected cards
- `buy_item` - Purchase item from shop
- `sell_joker` - Sell joker card
- `sell_consumable` - Sell consumable item
- `use_consumable` - Use consumable item
- `reorder_jokers` - Reorder joker positions
- `move_playing_card` - Move card position
- And more...

### get_action_results

Get the latest action execution results from the mod.

### list_shared_files

List all available shared JSON files.

## File Interface

The server maintains compatibility with BalatroMCP's file structure:

**Read Files:**
- `shared/game_state.json` - Main game state
- `shared/deck_state.json` - Deck information
- `shared/hand_levels.json` - Hand statistics  
- `shared/vouchers_ante.json` - Voucher/ante data
- `shared/action_results.json` - Action execution results

**Write Files:**
- `shared/actions.json` - Action commands for the mod

## Message Format

All messages use the BalatroMCP envelope format:

```json
{
  "timestamp": "2024-01-01T12:00:00Z",
  "sequence_id": 123,
  "message_type": "action",
  "data": {
    "action_type": "play_hand",
    "sequence_id": 123,
    "card_indices": [0, 1, 2, 3, 4]
  }
}
```

## Development

```bash
# Development mode with auto-reload
npm run dev

# Build
npm run build

# Test
npm test
```

## Integration with BalatroMCP Mod

This server acts as a bridge between MCP clients and the BalatroMCP mod:

1. **Client** → **MCP Server** → **Shared Files** → **BalatroMCP Mod** → **Balatro Game**
2. **Game State** → **Mod** → **Shared Files** → **MCP Server** → **Client**

The server maintains the exact file format and protocol used by the BalatroMCP mod, ensuring seamless integration without requiring any changes to the existing mod.