# Balatro MCP Mod

> **AI-powered Balatro gameplay** - A Steamodded mod that enables AI agents to interact with Balatro through state extraction and action execution.

[![Tests](https://img.shields.io/badge/tests-199%2F201-brightgreen)](mod/)
[![Steamodded](https://img.shields.io/badge/steamodded-1.0+-orange)](https://github.com/Steamopollys/Steamodded)
[![LuaUnit](https://img.shields.io/badge/luaunit-3.4-blue)](mod/libs/luaunit.lua)

## What Is This?

This Steamodded mod extracts complete game state from Balatro and enables external AI agents to control gameplay through JSON file communication. The mod provides comprehensive state information and supports 15+ precision game actions for autonomous AI gameplay.

## ⚡ Core Capabilities

**Complete Game State Extraction**
- 🎴 **Hand and deck information**: Cards with enhancements, editions, seals
- 🃏 **Joker collection**: Complete properties and positions
- 💰 **Economy tracking**: Money, ante, hands/discards remaining
- 👁️ **Game phase detection**: Hand selection, shop, blind selection, scoring
- 🛍️ **Shop contents**: Available items and costs

**15 Precision Game Actions**
- 🎴 **Hand Management**: Play cards, discard strategically
- 🛍️ **Shop Mastery**: Buy, sell, reroll with perfect timing
- 🃏 **Joker Orchestration**: Reorder jokers mid-hand for Blueprint/Brainstorm synergies
- 👁️ **Blind Navigation**: Select, reroll, and adapt to boss mechanics
- 🔀 **Hand Organization**: Sort by rank or suit for optimal visibility

**Battle-Tested Architecture**
- 199/201 passing unit tests (99.0% success rate)
- File-based communication protocol
- Clean modular design with comprehensive error handling
- Love2D filesystem integration

## 🚀 Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/your-repo/balatro-mcp.git
cd balatro-mcp

# 2. Install the Balatro mod
# Copy mod/ folder to your Steamodded mods directory:
# Windows: %APPDATA%/Balatro/Mods/BalatroMCP/
# Steam: steamapps/common/Balatro/Mods/BalatroMCP/

# 3. Launch Balatro with Steamodded
# The mod auto-initializes and creates communication files

# 4. Connect your AI agent
# Read game_state.json for current state
# Write actions.json to execute commands
# Monitor action_results.json for feedback
```

## 📊 Communication Protocol

The mod uses JSON file communication for external AI integration:

```
┌─────────────────┐    ┌─────────────────┐
│   AI Agent      │◄──►│  Balatro Mod    │
│   (External)    │    │   (This Repo)   │
└─────────────────┘    └─────────────────┘
          │                      │
          └──────────────────────┘
                    │
            ┌─────────────────────┐
            │   JSON Files        │
            │ • game_state.json   │
            │ • actions.json      │
            │ • action_results.json│
            └─────────────────────┘
```

## 🎮 Available Actions

| Action | Description | Strategic Importance |
|--------|-------------|---------------------|
| `play_hand` | Execute card combinations | Core scoring mechanism |
| `discard_cards` | Strategic card removal | Hand optimization |
| `reorder_jokers` | **Critical timing window** | Blueprint/Brainstorm mastery |
| `buy_item` | Shop purchases | Economy management |
| `sell_joker` | Joker liquidation | Portfolio optimization |
| `select_blind` | Blind choice | Risk/reward calculation |
| `sort_hand_by_rank` | Hand organization | Visual optimization |
| `sort_hand_by_suit` | Hand organization | Suit-based strategies |
| + 7 more actions... | Complete game control | Full automation capability |

## 🔧 Advanced Features

**Post-Hand Joker Reordering**
The crown jewel of this system - precise timing control for joker reordering after hand play but before final scoring. This enables advanced strategies like Blueprint/Brainstorm optimization that are impossible with manual play.

**Comprehensive State Validation**
Every action is validated against current game state, with detailed error reporting for impossible moves.

**File-Based Communication**
No network dependencies, no complex protocols - just JSON files that you can inspect, modify, and debug.

## 🤝 Contributing

This system is built for extension and customization:

- Add new game actions in [`action_executor.lua`](mod/action_executor.lua)
- Extend state extraction in [`state_extractor.lua`](mod/state_extractor.lua)
- Enhance file communication in [`file_io.lua`](mod/file_io.lua)
- Add tests in [`mod/test_*_luaunit.lua`](mod/) files

## ⚠️ Requirements

- **Balatro** with **Steamodded 1.0+** installed
- JSON library support (included with most Love2D distributions)

## 🧪 Testing

The mod includes comprehensive unit tests using LuaUnit v3.4:

```bash
# Run tests from mod directory
lua run_luaunit_tests.lua

# Current status: 199/201 tests passing (99.0% success rate)
```

## 🎉 Ready to Build AI Agents?

This mod provides the foundation for AI-powered Balatro gameplay. The complete game state extraction and action execution system enables sophisticated AI strategies that would be impossible with manual play.

```bash
git clone https://github.com/your-repo/balatro-mcp.git
cd balatro-mcp/mod
```

Start building the future of AI gaming.

---

*Built with precision, tested extensively, designed for autonomous AI gameplay.*