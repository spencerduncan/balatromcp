# Balatro MCP: AI Agent Integration

> **Unleash the power of artificial intelligence in Balatro** - A cutting-edge MCP server that bridges the gap between AI agents and the addictive world of Balatro card strategy.

[![Tests](https://img.shields.io/badge/tests-229%2F229-brightgreen)](server/tests/)
[![Python](https://img.shields.io/badge/python-3.8+-blue)](https://python.org)
[![Steamodded](https://img.shields.io/badge/steamodded-1.0+-orange)](https://github.com/Steamopollys/Steamodded)
[![MCP](https://img.shields.io/badge/MCP-1.0+-purple)](https://github.com/anthropics/mcp)

## What Is This?

Imagine watching an AI master the intricate dance of Balatro's card mechanics - calculating optimal joker arrangements in milliseconds, executing perfect Blueprint/Brainstorm strategies, and navigating complex blind decisions with inhuman precision. **Balatro MCP makes this reality.**

This system creates a seamless bridge between Balatro and AI agents through the Model Context Protocol (MCP), enabling autonomous gameplay that pushes the boundaries of what's possible in roguelike deckbuilding.

## ⚡ Core Capabilities

**15 Precision Game Actions**
- 🎴 **Hand Management**: Play cards, discard strategically
- 🛍️ **Shop Mastery**: Buy, sell, reroll with perfect timing
- 🃏 **Joker Orchestration**: Reorder jokers mid-hand for Blueprint/Brainstorm synergies
- 👁️ **Blind Navigation**: Select, reroll, and adapt to boss mechanics
- 🔀 **Hand Organization**: Sort by rank or suit for optimal visibility

**Real-Time State Access**
- Complete game state extraction (cards, jokers, money, phase, etc.)
- Live action availability detection
- Post-hand joker reordering windows
- Comprehensive blind and shop information

**Battle-Tested Architecture**
- 229/229 passing unit tests
- File-based communication protocol
- Clean dependency injection
- Async Python implementation with Love2D integration

## 🚀 Quick Start

Ready to unleash AI on Balatro? The setup is straightforward:

```bash
# 1. Clone the repository
git clone https://github.com/your-repo/balatro-mcp.git
cd balatro-mcp

# 2. Install Python dependencies
cd server
pip install -r requirements.txt

# 3. Install the Balatro mod (see Installation Guide)
# Copy mod/ folder to your Steamodded mods directory

# 4. Launch Balatro with Steamodded
# The mod auto-initializes and creates communication files

# 5. Start the MCP server
python -m server.main
```

Your AI agent can now connect through any MCP-compatible client and begin dominating Balatro runs.

## 🎯 Why This Matters

**For AI Researchers**: Study emergent strategy in complex card games with full observability and control.

**For Balatro Players**: Watch superhuman play unfold and discover strategies you never imagined.

**For Developers**: Build upon a robust, tested foundation with clean interfaces and comprehensive documentation.

## 📊 System Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   AI Agent      │◄──►│   MCP Server    │◄──►│  Balatro Mod    │
│   (Your Code)   │    │   (Python)      │    │   (Lua)         │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │                        │
                              │                        │
                       ┌─────────────────────────────────────┐
                       │     Shared JSON Files               │
                       │  • game_state.json                  │
                       │  • actions.json                     │
                       │  • action_results.json              │
                       └─────────────────────────────────────┘
```

Communication flows through three JSON files, enabling crash-resilient operation and easy debugging.

## 🎮 Available Actions

The system exposes 15 high-precision game actions:

| Action | Description | Strategic Importance |
|--------|-------------|---------------------|
| [`play_hand`](docs/api-reference.md#play_hand) | Execute card combinations | Core scoring mechanism |
| [`discard_cards`](docs/api-reference.md#discard_cards) | Strategic card removal | Hand optimization |
| [`reorder_jokers`](docs/api-reference.md#reorder_jokers) | **Critical timing window** | Blueprint/Brainstorm mastery |
| [`buy_item`](docs/api-reference.md#buy_item) | Shop purchases | Economy management |
| [`sell_joker`](docs/api-reference.md#sell_joker) | Joker liquidation | Portfolio optimization |
| [`select_blind`](docs/api-reference.md#select_blind) | Blind choice | Risk/reward calculation |
| + 9 more actions... | [See full API reference](docs/api-reference.md) | Complete game control |

## 📚 Documentation

Dive deeper into the system:

- **[Installation Guide](docs/installation.md)** - Complete setup walkthrough
- **[Usage Guide](docs/usage.md)** - AI agent integration examples  
- **[API Reference](docs/api-reference.md)** - Detailed endpoint documentation
- **[Developer Guide](docs/developer-guide.md)** - Extend and customize the system

## 🧪 Example: Basic AI Agent

```python
import mcp

async def basic_balatro_agent():
    async with mcp.ClientSession("stdio", command=["python", "-m", "server.main"]) as session:
        # Get current game state
        state = await session.read_resource("balatro://game-state")
        
        # Play first 5 cards if we have a hand
        if state.current_phase == "hand_selection" and len(state.hand_cards) >= 5:
            result = await session.call_tool("play_hand", {"card_indices": [0, 1, 2, 3, 4]})
            
        # After playing, check for joker reordering opportunities
        if state.post_hand_joker_reorder_available:
            # Reorder to put Blueprint last for maximum copying potential
            new_order = list(range(len(state.jokers)))
            blueprint_idx = next((i for i, j in enumerate(state.jokers) if j.name == "Blueprint"), None)
            if blueprint_idx is not None:
                new_order.append(new_order.pop(blueprint_idx))
                await session.call_tool("reorder_jokers", {"new_order": new_order})
```

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
- Enhance validation logic in [`action_handler.py`](server/action_handler.py)

See the [Developer Guide](docs/developer-guide.md) for detailed contribution instructions.

## ⚠️ Requirements

- **Python 3.8+** with asyncio support
- **Balatro** with **Steamodded 1.0+** installed
- **MCP-compatible client** (or build your own)

## 🎉 Join the Revolution

Ready to witness AI mastery of Balatro's deepest strategies? Clone the repo and dive in.

```bash
git clone https://github.com/your-repo/balatro-mcp.git
cd balatro-mcp
```

The future of Balatro AI starts now.

---

*Built with precision, tested extensively, designed for the next generation of AI-powered gaming.*