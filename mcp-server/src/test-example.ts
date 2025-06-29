/**
 * Example test script for BalatroMCP MCP Server
 * Demonstrates how to test the file interface functionality
 */

import { BalatroMCPFileInterface } from './file-interface.js';
import { ActionData } from './types.js';

async function testFileInterface() {
  console.log('Testing BalatroMCP File Interface...');
  
  const fileInterface = new BalatroMCPFileInterface('./test-shared');
  
  // Initialize
  await fileInterface.initialize();
  
  // Test writing an action
  const testAction: ActionData = {
    action_type: 'play_hand',
    sequence_id: 42,
    card_indices: [0, 1, 2, 3, 4]
  };
  
  await fileInterface.writeAction(testAction);
  console.log('✓ Action written successfully');
  
  // Test reading files (will be null if they don't exist)
  const gameState = await fileInterface.readGameState();
  console.log('Game state:', gameState ? 'Found' : 'Not found');
  
  const deckState = await fileInterface.readDeckState();
  console.log('Deck state:', deckState ? 'Found' : 'Not found');
  
  // List shared files
  const files = await fileInterface.listSharedFiles();
  console.log('Shared files:', files);
  
  console.log('Test completed successfully!');
}

// Run test if this file is executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  testFileInterface().catch(console.error);
}