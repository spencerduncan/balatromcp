/**
 * Unit tests for BalatroMCP file interface
 */

import fs from 'fs/promises';
import path from 'path';
import { BalatroMCPFileInterface } from '../file-interface.js';
import { ActionData } from '../types.js';

describe('BalatroMCPFileInterface', () => {
  let fileInterface: BalatroMCPFileInterface;
  let testDir: string;

  beforeEach(async () => {
    testDir = path.join(process.cwd(), 'test-temp', `test-${Date.now()}`);
    fileInterface = new BalatroMCPFileInterface(testDir);
    await fileInterface.initialize();
  });

  afterEach(async () => {
    fileInterface.stopWatching();
    try {
      await fs.rm(testDir, { recursive: true, force: true });
    } catch (error) {
      // Ignore cleanup errors
    }
  });

  describe('initialization', () => {
    test('should create shared directory', async () => {
      const stats = await fs.stat(testDir);
      expect(stats.isDirectory()).toBe(true);
    });
  });

  describe('action writing', () => {
    test('should write action to actions.json', async () => {
      const actionData: ActionData = {
        action_type: 'play_hand',
        sequence_id: 42,
        card_indices: [0, 1, 2, 3, 4]
      };

      await fileInterface.writeAction(actionData);

      const actionFile = path.join(testDir, 'actions.json');
      const content = await fs.readFile(actionFile, 'utf-8');
      const parsedContent = JSON.parse(content);

      expect(parsedContent.message_type).toBe('action');
      expect(parsedContent.data.action_type).toBe('play_hand');
      expect(parsedContent.data.sequence_id).toBe(42);
      expect(parsedContent.data.card_indices).toEqual([0, 1, 2, 3, 4]);
      expect(parsedContent.timestamp).toBeDefined();
    });

    test('should auto-generate sequence ID if not provided', async () => {
      const actionData: ActionData = {
        action_type: 'skip_blind',
        sequence_id: 0 // Will be overridden
      };

      await fileInterface.writeAction(actionData);

      const actionFile = path.join(testDir, 'actions.json');
      const content = await fs.readFile(actionFile, 'utf-8');
      const parsedContent = JSON.parse(content);

      expect(parsedContent.data.sequence_id).toBeGreaterThan(0);
    });
  });

  describe('file reading', () => {
    test('should return null for non-existent files', async () => {
      const gameState = await fileInterface.readGameState();
      expect(gameState).toBeNull();
    });

    test('should read existing JSON files', async () => {
      const testData = {
        timestamp: '2024-01-01T12:00:00Z',
        sequence_id: 1,
        message_type: 'game_state',
        data: { test: 'data' }
      };

      const gameStateFile = path.join(testDir, 'game_state.json');
      await fs.writeFile(gameStateFile, JSON.stringify(testData));

      const result = await fileInterface.readGameState();
      expect(result).toEqual(testData);
    });
  });

  describe('file listing', () => {
    test('should list JSON files in shared directory', async () => {
      await fs.writeFile(path.join(testDir, 'game_state.json'), '{}');
      await fs.writeFile(path.join(testDir, 'deck_state.json'), '{}');
      await fs.writeFile(path.join(testDir, 'other.txt'), 'text');

      const files = await fileInterface.listSharedFiles();
      
      expect(files).toContain('game_state.json');
      expect(files).toContain('deck_state.json');
      expect(files).not.toContain('other.txt');
    });
  });

  describe('sequence ID management', () => {
    test('should increment sequence IDs', () => {
      const id1 = fileInterface.getNextSequenceId();
      const id2 = fileInterface.getNextSequenceId();
      const id3 = fileInterface.getNextSequenceId();

      expect(id2).toBe(id1 + 1);
      expect(id3).toBe(id2 + 1);
    });
  });
});