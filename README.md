# BalatroMCP: AI-Powered Balatro Automation Platform

> **The complete AI integration solution for Balatro** - Advanced Steamodded mod with MCP server providing secure, comprehensive game state extraction and autonomous action execution for AI agents.

[![Tests](https://img.shields.io/badge/tests-293%20passing-brightgreen)](tests/)
[![Coverage](https://img.shields.io/badge/test_coverage-35%2B_modules-blue)](tests/)
[![Steamodded](https://img.shields.io/badge/steamodded-1.0+-orange)](https://github.com/Steamopollys/Steamodded)
[![MCP Protocol](https://img.shields.io/badge/MCP-compatible-purple)](mcp-server/)
[![LuaUnit](https://img.shields.io/badge/luaunit-3.4-blue)](libs/luaunit.lua)
[![TypeScript](https://img.shields.io/badge/typescript-5.3+-blue)](mcp-server/)

## 🚀 What Is BalatroMCP?

BalatroMCP is a production-grade platform that bridges Balatro gameplay with AI agents through multiple interfaces. It provides **complete game state extraction**, **secure action validation**, and **autonomous gameplay execution** via both file-based communication and the Model Context Protocol (MCP).

**🎯 Perfect for:** AI researchers, game automation enthusiasts, machine learning practitioners, and developers building intelligent gaming agents.

### 🌟 Unique Capabilities
- **🔒 Action Validation System**: Prevents AI agents from bypassing game rules
- **⚡ Real-time State Extraction**: Live game monitoring with 35+ specialized extractors  
- **🔄 MCP Server Integration**: Standard protocol support for seamless AI agent connection
- **🧪 Battle-tested Reliability**: 293 comprehensive tests across all components
- **⏱️ Post-hand Joker Reordering**: Precise timing control impossible with manual play

## 🏗️ Enterprise-Grade Architecture

### 🔧 **Transport Abstraction Layer**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   AI Agent      │◄──►│ MessageManager  │◄──►│ IMessageTransport│
│   (External)    │    │                 │    │ Implementation  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │                        │
                              ▼                        ▼
                    ┌─────────────────┐    ┌─────────────────┐
                    │ StateExtractor  │    │ AsyncFileTransport│
                    │ (Game→JSON)     │    │ (Non-blocking I/O)│
                    └─────────────────┘    └─────────────────┘
```

### 🛡️ **Action Validation System** 
**NEW: Prevents AI agents from bypassing game progression rules**
- **Blind Selection Enforcement**: AI must follow `blind_on_deck` progression
- **Boss Reroll Validation**: Voucher ownership and cost verification  
- **Per-Ante Usage Limits**: Director's Cut (1 per ante) vs Retcon (unlimited)
- **Extensible Framework**: Plugin architecture for future action types

### 📊 **Comprehensive State Extraction**
**35+ Specialized Extractors** covering every aspect of game state:

| Category | Extractors | Strategic Value |
|----------|------------|----------------|
| **🎴 Cards** | Hand, Deck, Playing | Complete card tracking with enhancements |
| **🃏 Jokers** | Collection, Reorder | Position-aware joker management |
| **💰 Economy** | Money, Shop, Vouchers | Financial decision-making data |
| **🎯 Game Flow** | Phase, Blind, Round | State machine awareness |
| **📈 Statistics** | Hand Levels, Session | Performance analytics |

### 🚀 **Dual Interface Support**

#### **1. File-Based Communication** (Classic)
- **Zero Dependencies**: Pure JSON file exchange
- **Debug Friendly**: Inspect all communication in real-time
- **Async Operations**: Non-blocking I/O with Love2D threading
- **File Watching**: Real-time state monitoring

#### **2. MCP Server** (Modern) ✨ **NEW**
- **Standard Protocol**: Model Context Protocol compliance
- **Type Safety**: Full TypeScript implementation with ESM modules
- **Real-time Updates**: File watching with instant notifications
- **Resource Management**: Proper cleanup and error boundaries

### 🧪 **Testing Excellence**
- **293 Tests** across 35+ modules with **99%+ success rate**
- **Unit Testing**: Component isolation with comprehensive mocking
- **Integration Testing**: End-to-end workflow validation
- **Async Testing**: Threading and file operation validation
- **Defensive Testing**: Graceful degradation verification

## 🚀 Quick Start Guide

### 📋 **Prerequisites**
- **Balatro** (Steam/Standalone)
- **Steamodded 1.0+** ([Installation Guide](https://github.com/Steamopollys/Steamodded))
- **Node.js 18+** (for MCP server)
- **PowerShell** (Windows, for action testing)

### ⚡ **Fast Track Installation**

```bash
# 1. Clone and setup
git clone https://github.com/spencerduncan/balatromcp.git
cd balatromcp

# 2. Deploy Balatro mod (Windows)
powershell -ExecutionPolicy Bypass -File deploy-mod.ps1

# 3. Setup MCP server (optional but recommended)
cd mcp-server
npm install
npm run build

# 4. Launch Balatro with Steamodded enabled
# The mod auto-initializes and creates shared/ directory

# 5. Test the connection
npm test  # Verify MCP server functionality
```

### 🔧 **Manual Installation**

**Balatro Mod:**
```bash
# Copy entire repository directory to:
# Windows: %APPDATA%/Balatro/Mods/BalatroMCP/
# macOS:   ~/Library/Application Support/Balatro/Mods/BalatroMCP/
# Linux:   ~/.local/share/Balatro/Mods/BalatroMCP/
```

**Verification:**
```bash
# Run comprehensive test suite
lua tests/run_luaunit_tests.lua

# Expected: 293 tests passing across 35+ modules
```

## 🔌 Integration Options

### **Option 1: MCP Server** (Recommended) ⭐

**Perfect for:** Claude, OpenAI agents, custom AI implementations

```typescript
// Configure Claude Desktop
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

**Available Resources:**
- `balatromcp://game_state` - Live game state with hand cards, money, phase
- `balatromcp://deck_state` - Complete deck composition and statistics
- `balatromcp://hand_levels` - Poker hand statistics and progression
- `balatromcp://vouchers_ante` - Voucher collection and ante requirements

### **Option 2: Direct File Communication**

**Perfect for:** Custom scripts, research environments, debugging

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   AI Agent      │◄──►│  shared/ Files  │◄──►│  Balatro Mod    │
│   (Your Code)   │    │     (JSON)      │    │  (BalatroMCP)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                        ┌───────────────────────────┐
                        │  📁 shared/ directory     │
                        │  ├── game_state.json     │ ← Read
                        │  ├── deck_state.json     │ ← Read  
                        │  ├── hand_levels.json    │ ← Read
                        │  ├── vouchers_ante.json  │ ← Read
                        │  ├── action_results.json │ ← Read
                        │  └── actions.json        │ ← Write
                        └───────────────────────────┘
```

**Message Envelope Format:**
```json
{
  "timestamp": "2024-01-15T12:34:56Z",
  "sequence_id": 42,
  "message_type": "action",
  "data": {
    "action_type": "play_hand",
    "sequence_id": 42,
    "card_indices": [0, 1, 2, 3, 4]
  }
}
```

## 🎮 Complete Action Library

### **🔥 Core Gameplay Actions**

| Action | Parameters | Validation | Strategic Impact |
|--------|------------|------------|------------------|
| `play_hand` | `card_indices: number[]` | ✅ Hand validity | **Primary scoring mechanism** |
| `discard_cards` | `card_indices: number[]` | ✅ Discard limits | **Hand optimization** |
| `select_blind` | `blind_type: string` | 🛡️ **Enforced progression** | **Risk management** |
| `skip_blind` | - | ✅ Game state | **Resource conservation** |
| `reorder_jokers` | `from_index, to_index: number` | ✅ Position bounds | **🏆 Blueprint/Brainstorm mastery** |

### **🛍️ Economy & Shop Actions**

| Action | Parameters | Validation | Economic Impact |
|--------|------------|------------|----------------|
| `buy_item` | `shop_index: number, buy_and_use?: string` | ✅ Funds + availability | **Portfolio growth** |
| `sell_joker` | `joker_index: number` | ✅ Ownership | **Liquidity management** |
| `sell_consumable` | `consumable_index: number` | ✅ Inventory | **Resource optimization** |
| `use_consumable` | `consumable_index: number` | ✅ Usability | **Strategic enhancement** |
| `reroll_shop` | - | ✅ Cost availability | **Selection optimization** |
| `reroll_boss` | - | 🛡️ **Voucher validation** | **Risk mitigation** |

### **🎴 Hand & Deck Management**

| Action | Parameters | Validation | Organizational Benefit |
|--------|------------|------------|----------------------|
| `move_playing_card` | `from_index, to_index: number` | ✅ Valid positions | **Precise hand control** |
| `sort_hand_by_rank` | - | ✅ Game state | **Rank-based strategies** |
| `sort_hand_by_suit` | - | ✅ Game state | **Suit-focused play** |
| `select_pack_offer` | `pack_index: number` | ✅ Pack availability | **Collection building** |

### **🔒 Action Validation Features**

- **🛡️ Game Rule Enforcement**: Prevents impossible actions (e.g., playing invalid hands)
- **💰 Cost Validation**: Ensures sufficient funds before expensive operations  
- **📋 Progression Compliance**: Forces correct blind selection sequence
- **🎫 Voucher Requirements**: Validates boss reroll permissions
- **⏱️ Timing Windows**: Enables post-hand joker reordering
- **🚫 Error Prevention**: Detailed validation results with actionable messages

## 🏆 Advanced Features & Strategic Advantages

### **⚡ Post-Hand Joker Reordering**
**The crown jewel capability** - Precise timing control for joker reordering after hand execution but before final scoring calculation. This enables advanced optimization strategies:

```lua
-- Example: Blueprint positioning for maximum effect
1. Play hand → 2. Reorder jokers → 3. Calculate final score
```

**Strategic Benefits:**
- **Blueprint Mastery**: Position Blueprint to copy optimal jokers
- **Brainstorm Optimization**: Maximize copying of most valuable jokers  
- **Dynamic Adaptation**: Adjust strategy mid-hand based on drawn cards
- **Impossible Manual Play**: Sub-second timing windows AI can exploit

### **🛡️ Action Validation System**
**Enterprise-grade security** preventing AI agents from breaking game rules:

```typescript
// Validation Pipeline
Action Request → State Validation → Rule Enforcement → Execution/Rejection
```

**Validation Categories:**
- **🎯 Blind Progression**: Enforces `blind_on_deck` sequence (ignores AI preferences)
- **💳 Cost Verification**: Prevents insufficient fund transactions
- **🎫 Voucher Authentication**: Validates Director's Cut/Retcon ownership  
- **📊 Usage Tracking**: Per-ante limits with automatic reset
- **🔍 State Consistency**: Real-time game state validation

### **🔄 Async File Operations**
**Love2D threading integration** for non-blocking performance:

```lua
-- Non-blocking file operations
transport:write_message(data, "game_state", function(success)
    -- Callback-based completion
end)
```

### **📊 Defensive State Extraction**
Every extractor includes **graceful degradation**:

```lua
-- Example: Safe extraction pattern
if not G or not G.hand or not G.hand.cards then
    return {}  -- Safe empty array, never crashes
end
```

## 🛠️ Development & Extension

### **🏗️ Architecture Overview**

```
BalatroMCP/
├── 🎮 action_executor/          # Action execution & validation
│   ├── validators/              # Pluggable validation system
│   └── utils/                   # Supporting utilities
├── 📊 state_extractor/          # Modular state extraction
│   ├── extractors/              # 35+ specialized extractors
│   └── utils/                   # Extraction utilities  
├── 🔄 transports/               # Communication backends
├── 🧪 tests/                    # 293 comprehensive tests
├── 🌐 mcp-server/               # TypeScript MCP implementation
└── 📚 docs/                     # Implementation guides
```

### **🔧 Extension Points**

#### **Adding New Actions**
```lua
-- 1. Add to action_executor.lua
function ActionExecutor:my_new_action(action_data)
    -- Implementation
end

-- 2. Create validator (optional)
local MyActionValidator = {}
function MyActionValidator:validate(action_data, game_state)
    return ValidationResult.success()
end

-- 3. Add comprehensive tests
-- tests/test_my_new_action_luaunit.lua
```

#### **Custom State Extractors**
```lua
-- state_extractor/extractors/my_extractor.lua
local MyExtractor = {}
function MyExtractor:extract()
    return {
        my_data = self:extract_my_data()
    }
end
```

#### **New Transport Methods**
```lua
-- transports/my_transport.lua
local MyTransport = {}
function MyTransport:write_message(data, type)
    -- Custom communication logic
end
```

### **🧪 Testing Standards**

**Test Categories:**
- **Unit Tests**: Component isolation with mocking
- **Integration Tests**: End-to-end workflow validation  
- **Async Tests**: Threading and file operation testing
- **Validation Tests**: Action validation framework testing
- **Extraction Tests**: State extraction accuracy verification

**Running Tests:**
```bash
# Full test suite (recommended)
lua tests/run_luaunit_tests.lua

# Specific component testing
lua tests/test_action_executor_luaunit.lua
lua tests/test_state_extractor_luaunit.lua

# MCP server testing
cd mcp-server && npm test
```

### **📋 Contribution Guidelines**

1. **🧪 Test Coverage**: All new features require comprehensive tests
2. **📝 Documentation**: Update CLAUDE.md with implementation lessons
3. **🔒 Validation**: New actions should include appropriate validation
4. **♻️ Code Style**: Follow existing Lua and TypeScript conventions
5. **🏗️ Architecture**: Maintain separation of concerns and modularity

## 🔧 System Requirements

### **🎮 Balatro Setup**
- **Balatro** (Steam or standalone version)
- **Steamodded 1.0+** ([Download here](https://github.com/Steamopollys/Steamodded))
- **Love2D** (typically bundled with Balatro)

### **🌐 MCP Server (Optional)**
- **Node.js 18+** 
- **npm** or **yarn**
- **TypeScript 5.3+** (dev dependency)

### **🖥️ Platform Support**
- ✅ **Windows** (Primary - PowerShell scripts included)
- ✅ **macOS** (Manual installation)
- ✅ **Linux** (Manual installation)

## 📊 Quality Metrics

### **🧪 Test Coverage**
```
📈 Testing Statistics:
├── 293 Total Tests
├── 35+ Test Modules  
├── 99%+ Success Rate
├── Unit + Integration Coverage
└── Async Operation Testing
```

**Test Categories:**
- **🔧 Action Execution**: 45+ tests covering all action types
- **📊 State Extraction**: 85+ tests for all extractors
- **🔄 Transport Layer**: 60+ tests for file/async operations
- **🛡️ Validation System**: 35+ tests for rule enforcement
- **🌐 MCP Server**: 7+ TypeScript tests with integration
- **⚡ Performance**: Async threading and file operation tests

### **🏗️ Architecture Quality**
- **SOLID Principles**: Clean separation of concerns
- **Error Handling**: Comprehensive graceful degradation
- **Resource Management**: Proper cleanup and memory management
- **Type Safety**: Full TypeScript implementation for MCP server
- **Security**: Action validation prevents rule bypassing

## 🚀 Getting Started Examples

### **📖 Basic File Communication**
```python
import json
import time

# Read current game state
with open('shared/game_state.json', 'r') as f:
    game_state = json.load(f)
    
print(f"Phase: {game_state['data']['current_phase']}")
print(f"Money: ${game_state['data']['dollars']}")

# Execute an action
action = {
    "timestamp": "2024-01-15T12:34:56Z",
    "sequence_id": 1,
    "message_type": "action", 
    "data": {
        "action_type": "play_hand",
        "sequence_id": 1,
        "card_indices": [0, 1, 2, 3, 4]
    }
}

with open('shared/actions.json', 'w') as f:
    json.dump(action, f)
    
# Check results
time.sleep(0.5)
with open('shared/action_results.json', 'r') as f:
    result = json.load(f)
    print(f"Action result: {result['data']['success']}")
```

### **🔌 MCP Integration**
```bash
# Start MCP server
cd mcp-server
npm start

# Configure Claude Desktop (in config.json)
{
  "mcpServers": {
    "balatromcp": {
      "command": "node",
      "args": ["/path/to/balatromcp/mcp-server/dist/index.js"]
    }
  }
}
```

## 🆘 Troubleshooting

### **🔍 Common Issues**

**Mod Not Loading:**
```bash
# Check Steamodded installation
# Verify mod directory structure:
# %APPDATA%/Balatro/Mods/BalatroMCP/BalatroMCP.lua
```

**No Shared Files:**
```bash
# Check mod initialization logs in Balatro console
# Verify file permissions in shared/ directory
```

**Action Not Executing:**
```bash
# Check action_results.json for validation errors
# Verify action parameters match expected format
# Ensure game is in correct phase for action
```

**MCP Server Issues:**
```bash
# Check Node.js version (18+)
node --version

# Verify TypeScript compilation
cd mcp-server && npm run build

# Test MCP server functionality  
npm test
```

### **🐛 Debug Mode**
```lua
-- Enable verbose logging in BalatroMCP.lua
balatro_mcp_debug = true
```

## 📚 Documentation & Resources

- **📖 [CLAUDE.md](CLAUDE.md)** - Comprehensive development guide
- **🏗️ [Architecture Docs](docs/)** - Implementation deep-dives
- **🧪 [Testing Guide](tests/README.md)** - Test framework documentation
- **🌐 [MCP Server Guide](mcp-server/README.md)** - TypeScript implementation details
- **🔧 [Action Reference](ACTION_TESTING.md)** - Complete action documentation

## 🎉 Ready to Build the Future?

**BalatroMCP provides the complete foundation for AI-powered Balatro gameplay.** Whether you're building research experiments, training reinforcement learning agents, or creating sophisticated game AI, this platform provides the reliability, security, and extensibility you need.

### **🚀 Quick Start Command**
```bash
git clone https://github.com/spencerduncan/balatromcp.git
cd balatromcp
powershell -ExecutionPolicy Bypass -File deploy-mod.ps1
cd mcp-server && npm install && npm test
```

**Join the AI gaming revolution.** 🤖🎮

---

**🏆 Built with enterprise-grade architecture • 🧪 Tested comprehensively • 🔒 Secured with validation • 🚀 Optimized for AI agents**

*BalatroMCP: Where artificial intelligence meets card game mastery.*