#!/usr/bin/env node
/**
 * BalatroMCP MCP Server
 * Provides MCP interface compatibility with BalatroMCP mod's file-based protocol
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ErrorCode,
  ListResourcesRequestSchema,
  ListToolsRequestSchema,
  McpError,
  ReadResourceRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { BalatroMCPFileInterface } from './file-interface.js';
import { ActionData, SupportedActionType } from './types.js';

class BalatroMCPServer {
  private server: Server;
  private fileInterface: BalatroMCPFileInterface;

  constructor(sharedDir?: string) {
    this.fileInterface = new BalatroMCPFileInterface(sharedDir);
    this.server = new Server(
      {
        name: 'balatromcp-server',
        version: '1.0.0',
      },
      {
        capabilities: {
          resources: {},
          tools: {},
        },
      }
    );

    this.setupHandlers();
  }

  private setupHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      return {
        tools: [
          {
            name: 'execute_action',
            description: 'Execute a BalatroMCP action (play_hand, select_blind, buy_item, etc.)',
            inputSchema: {
              type: 'object',
              properties: {
                action_type: {
                  type: 'string',
                  description: 'Type of action to execute',
                  enum: [
                    'skip_blind', 'select_blind', 'play_hand', 'discard_cards',
                    'go_to_shop', 'buy_item', 'sell_joker', 'sell_consumable',
                    'use_consumable', 'reorder_jokers', 'reroll_boss', 'reroll_shop',
                    'sort_hand_by_rank', 'sort_hand_by_suit', 'move_playing_card',
                    'select_pack_offer', 'go_next', 'diagnose_blind_progression',
                    'diagnose_blind_activation'
                  ]
                },
                parameters: {
                  type: 'object',
                  description: 'Action-specific parameters',
                  additionalProperties: true
                }
              },
              required: ['action_type']
            }
          },
          {
            name: 'get_action_results',
            description: 'Get the latest action execution results',
            inputSchema: {
              type: 'object',
              properties: {},
              additionalProperties: false
            }
          },
          {
            name: 'list_shared_files',
            description: 'List all available shared JSON files',
            inputSchema: {
              type: 'object',
              properties: {},
              additionalProperties: false
            }
          }
        ]
      };
    });

    // List available resources
    this.server.setRequestHandler(ListResourcesRequestSchema, async () => {
      return {
        resources: [
          {
            uri: 'balatromcp://game_state',
            mimeType: 'application/json',
            name: 'Game State',
            description: 'Current Balatro game state including cards, money, phase, etc.'
          },
          {
            uri: 'balatromcp://deck_state', 
            mimeType: 'application/json',
            name: 'Deck State',
            description: 'Current deck composition and card information'
          },
          {
            uri: 'balatromcp://hand_levels',
            mimeType: 'application/json', 
            name: 'Hand Levels',
            description: 'Poker hand statistics and levels'
          },
          {
            uri: 'balatromcp://vouchers_ante',
            mimeType: 'application/json',
            name: 'Vouchers and Ante',
            description: 'Voucher information and ante requirements'
          }
        ]
      };
    });

    // Read resources
    this.server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
      const { uri } = request.params;
      
      switch (uri) {
        case 'balatromcp://game_state': {
          const gameState = await this.fileInterface.readGameState();
          return {
            contents: [
              {
                uri,
                mimeType: 'application/json',
                text: gameState ? JSON.stringify(gameState, null, 2) : '{"error": "No game state available"}'
              }
            ]
          };
        }
        
        case 'balatromcp://deck_state': {
          const deckState = await this.fileInterface.readDeckState();
          return {
            contents: [
              {
                uri,
                mimeType: 'application/json',
                text: deckState ? JSON.stringify(deckState, null, 2) : '{"error": "No deck state available"}'
              }
            ]
          };
        }
        
        case 'balatromcp://hand_levels': {
          const handLevels = await this.fileInterface.readHandLevels();
          return {
            contents: [
              {
                uri,
                mimeType: 'application/json',
                text: handLevels ? JSON.stringify(handLevels, null, 2) : '{"error": "No hand levels available"}'
              }
            ]
          };
        }
        
        case 'balatromcp://vouchers_ante': {
          const vouchersAnte = await this.fileInterface.readVouchersAnte();
          return {
            contents: [
              {
                uri,
                mimeType: 'application/json',
                text: vouchersAnte ? JSON.stringify(vouchersAnte, null, 2) : '{"error": "No vouchers ante available"}'
              }
            ]
          };
        }
        
        default:
          throw new McpError(ErrorCode.InvalidRequest, `Unknown resource: ${uri}`);
      }
    });

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;
      
      switch (name) {
        case 'execute_action': {
          return await this.executeAction(args as any);
        }
        
        case 'get_action_results': {
          const results = await this.fileInterface.readActionResults();
          return {
            content: [
              {
                type: 'text',
                text: results ? JSON.stringify(results, null, 2) : 'No action results available'
              }
            ]
          };
        }
        
        case 'list_shared_files': {
          const files = await this.fileInterface.listSharedFiles();
          return {
            content: [
              {
                type: 'text',
                text: JSON.stringify({ files }, null, 2)
              }
            ]
          };
        }
        
        default:
          throw new McpError(ErrorCode.MethodNotFound, `Unknown tool: ${name}`);
      }
    });
  }

  private async executeAction(args: { action_type: SupportedActionType; parameters?: any }): Promise<any> {
    const { action_type, parameters = {} } = args;
    
    // Build action data in BalatroMCP format
    const actionData: ActionData = {
      action_type,
      sequence_id: this.fileInterface.getNextSequenceId(),
      ...parameters
    };

    try {
      await this.fileInterface.writeAction(actionData);
      
      return {
        content: [
          {
            type: 'text',
            text: `Action '${action_type}' executed successfully with sequence ID ${actionData.sequence_id}`
          }
        ]
      };
    } catch (error) {
      throw new McpError(
        ErrorCode.InternalError,
        `Failed to execute action: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }

  async run() {
    // Initialize file interface
    await this.fileInterface.initialize();
    
    // Start file watching for real-time updates
    this.fileInterface.startWatching((filename, content) => {
      console.log(`File updated: ${filename}`);
    });

    // Set up cleanup on exit
    process.on('SIGINT', () => {
      console.log('Shutting down BalatroMCP server...');
      this.fileInterface.stopWatching();
      process.exit(0);
    });

    // Start the server
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.log('BalatroMCP MCP server running');
  }
}

// Start the server
const server = new BalatroMCPServer();
server.run().catch(console.error);