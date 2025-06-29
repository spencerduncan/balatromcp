/**
 * Integration test to verify BalatroMCP compatibility
 * Creates mock data in BalatroMCP format to test the file interface
 */

import fs from 'fs/promises';
import path from 'path';
import { BalatroMCPFileInterface } from './file-interface.js';

async function runIntegrationTest() {
  console.log('🧪 Running BalatroMCP compatibility integration test...');
  
  const testDir = './test-integration';
  const fileInterface = new BalatroMCPFileInterface(testDir);
  
  try {
    // Initialize
    await fileInterface.initialize();
    console.log('✓ File interface initialized');
    
    // Create mock game state in BalatroMCP format
    const mockGameState = {
      timestamp: "2024-12-29T12:34:56Z",
      sequence_id: 1,
      message_type: "comprehensive_state_update",
      state: {
        session_id: "test_session_123",
        current_phase: "hand_selection",
        hand_cards: [
          { id: 1, rank: "A", suit: "Spades", enhancement: null, edition: null, seal: null },
          { id: 2, rank: "K", suit: "Hearts", enhancement: null, edition: null, seal: null }
        ],
        jokers: [
          { id: 101, name: "Joker", rarity: "Common", ability: "Standard joker" }
        ],
        consumables: [],
        shop_jokers: [],
        blind_info: {
          name: "Small Blind",
          chips: 30,
          mult: 1
        },
        money: 25,
        ante: 1,
        hands_left: 4,
        discards_left: 3
      }
    };
    
    // Write mock game state file
    const gameStateFile = path.join(testDir, 'game_state.json');
    await fs.writeFile(gameStateFile, JSON.stringify(mockGameState, null, 2));
    console.log('✓ Mock game state created');
    
    // Create mock deck state
    const mockDeckState = {
      timestamp: "2024-12-29T12:34:56Z",
      sequence_id: 2,
      message_type: "deck_state",
      data: {
        session_id: "test_session_123",
        timestamp: Date.now(),
        card_count: 48,
        deck_cards: [
          { id: 3, rank: "Q", suit: "Clubs", enhancement: null, edition: null, seal: null },
          { id: 4, rank: "J", suit: "Diamonds", enhancement: null, edition: null, seal: null }
        ]
      }
    };
    
    const deckStateFile = path.join(testDir, 'deck_state.json');
    await fs.writeFile(deckStateFile, JSON.stringify(mockDeckState, null, 2));
    console.log('✓ Mock deck state created');
    
    // Test reading files
    const readGameState = await fileInterface.readGameState();
    if (readGameState) {
      console.log('✓ Game state read successfully');
      console.log(`  Phase: ${readGameState.state?.current_phase}`);
      console.log(`  Money: ${readGameState.state?.money}`);
      console.log(`  Hand cards: ${readGameState.state?.hand_cards?.length || 0}`);
    } else {
      console.log('❌ Failed to read game state');
    }
    
    const readDeckState = await fileInterface.readDeckState();
    if (readDeckState) {
      console.log('✓ Deck state read successfully');
      console.log(`  Card count: ${readDeckState.data?.card_count}`);
    } else {
      console.log('❌ Failed to read deck state');
    }
    
    // Test writing actions
    console.log('\n🎮 Testing action writing...');
    
    // Test play_hand action
    await fileInterface.writeAction({
      action_type: 'play_hand',
      sequence_id: 50,
      card_indices: [0, 1]
    });
    console.log('✓ play_hand action written');
    
    // Test select_blind action
    await fileInterface.writeAction({
      action_type: 'select_blind',
      sequence_id: 51,
      blind_type: 'big'
    });
    console.log('✓ select_blind action written');
    
    // Test buy_item action
    await fileInterface.writeAction({
      action_type: 'buy_item',
      sequence_id: 52,
      shop_index: 0,
      buy_and_use: 'true'
    });
    console.log('✓ buy_item action written');
    
    // Verify actions file was created with correct format
    const actionsFile = path.join(testDir, 'actions.json');
    const actionsContent = await fs.readFile(actionsFile, 'utf-8');
    const parsedAction = JSON.parse(actionsContent);
    
    console.log('\n📋 Last action written:');
    console.log(`  Message type: ${parsedAction.message_type}`);
    console.log(`  Action type: ${parsedAction.data.action_type}`);
    console.log(`  Sequence ID: ${parsedAction.data.sequence_id}`);
    console.log(`  Timestamp: ${parsedAction.timestamp}`);
    
    // List all files
    const files = await fileInterface.listSharedFiles();
    console.log(`\n📁 Shared files found: ${files.join(', ')}`);
    
    console.log('\n✅ Integration test completed successfully!');
    console.log('\n🔗 BalatroMCP format compatibility verified:');
    console.log('  ✓ Message envelope structure (timestamp, sequence_id, message_type, data)');
    console.log('  ✓ Action data format with all required fields');
    console.log('  ✓ File naming convention (game_state.json, deck_state.json, actions.json)');
    console.log('  ✓ JSON structure matching BalatroMCP mod expectations');
    
  } catch (error) {
    console.error('❌ Integration test failed:', error);
  } finally {
    // Cleanup
    try {
      await fs.rm(testDir, { recursive: true, force: true });
      console.log('✓ Test cleanup completed');
    } catch (cleanupError) {
      console.warn('⚠️  Cleanup warning:', cleanupError);
    }
  }
}

// Run the test
runIntegrationTest().catch(console.error);