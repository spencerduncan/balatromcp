/**
 * File interface for BalatroMCP shared file operations
 */

import fs from 'fs/promises';
import path from 'path';
import chokidar from 'chokidar';
import { 
  BalatroMCPMessage, 
  ActionData, 
  GameStateData, 
  DeckStateData, 
  HandLevelsData, 
  VouchersAnteData, 
  ActionResult 
} from './types.js';

export class BalatroMCPFileInterface {
  private sharedDir: string;
  private sequenceId: number = 1;
  private watchers: chokidar.FSWatcher[] = [];

  constructor(sharedDir: string = './shared') {
    this.sharedDir = path.resolve(sharedDir);
  }

  /**
   * Initialize the file interface and ensure shared directory exists
   */
  async initialize(): Promise<void> {
    try {
      await fs.mkdir(this.sharedDir, { recursive: true });
      console.log(`BalatroMCP file interface initialized: ${this.sharedDir}`);
    } catch (error) {
      console.error('Failed to initialize shared directory:', error);
      throw error;
    }
  }

  /**
   * Read game state from game_state.json
   */
  async readGameState(): Promise<BalatroMCPMessage | null> {
    return this.readJsonFile('game_state.json');
  }

  /**
   * Read deck state from deck_state.json
   */
  async readDeckState(): Promise<BalatroMCPMessage | null> {
    return this.readJsonFile('deck_state.json');
  }

  /**
   * Read hand levels from hand_levels.json
   */
  async readHandLevels(): Promise<BalatroMCPMessage | null> {
    return this.readJsonFile('hand_levels.json');
  }

  /**
   * Read vouchers ante from vouchers_ante.json
   */
  async readVouchersAnte(): Promise<BalatroMCPMessage | null> {
    return this.readJsonFile('vouchers_ante.json');
  }

  /**
   * Read action results from action_results.json
   */
  async readActionResults(): Promise<BalatroMCPMessage | null> {
    return this.readJsonFile('action_results.json');
  }

  /**
   * Write action to actions.json in BalatroMCP format
   */
  async writeAction(actionData: ActionData): Promise<void> {
    const message: BalatroMCPMessage = {
      timestamp: new Date().toISOString().replace(/\.\d{3}Z$/, 'Z'),
      sequence_id: actionData.sequence_id || this.getNextSequenceId(),
      message_type: 'action',
      data: actionData
    };

    await this.writeJsonFile('actions.json', message);
  }

  /**
   * Watch for changes in shared files
   */
  startWatching(onFileChange: (filename: string, content: BalatroMCPMessage | null) => void): void {
    const filesToWatch = [
      'game_state.json',
      'deck_state.json', 
      'hand_levels.json',
      'vouchers_ante.json',
      'action_results.json'
    ];

    filesToWatch.forEach(filename => {
      const filepath = path.join(this.sharedDir, filename);
      const watcher = chokidar.watch(filepath, {
        ignoreInitial: false,
        persistent: true
      });

      watcher.on('change', async () => {
        const content = await this.readJsonFile(filename);
        onFileChange(filename, content);
      });

      watcher.on('add', async () => {
        const content = await this.readJsonFile(filename);
        onFileChange(filename, content);
      });

      this.watchers.push(watcher);
    });

    console.log('Started watching BalatroMCP shared files');
  }

  /**
   * Stop all file watchers
   */
  stopWatching(): void {
    this.watchers.forEach(watcher => watcher.close());
    this.watchers = [];
    console.log('Stopped watching BalatroMCP shared files');
  }

  /**
   * Get next sequence ID for actions
   */
  getNextSequenceId(): number {
    return this.sequenceId++;
  }

  /**
   * List all available shared files
   */
  async listSharedFiles(): Promise<string[]> {
    try {
      const files = await fs.readdir(this.sharedDir);
      return files.filter(file => file.endsWith('.json'));
    } catch (error) {
      console.error('Failed to list shared files:', error);
      return [];
    }
  }

  /**
   * Generic JSON file reader
   */
  private async readJsonFile(filename: string): Promise<BalatroMCPMessage | null> {
    const filepath = path.join(this.sharedDir, filename);
    
    try {
      const content = await fs.readFile(filepath, 'utf-8');
      return JSON.parse(content) as BalatroMCPMessage;
    } catch (error) {
      if ((error as any).code === 'ENOENT') {
        return null; // File doesn't exist yet
      }
      console.error(`Failed to read ${filename}:`, error);
      return null;
    }
  }

  /**
   * Generic JSON file writer
   */
  private async writeJsonFile(filename: string, data: BalatroMCPMessage): Promise<void> {
    const filepath = path.join(this.sharedDir, filename);
    
    try {
      const jsonContent = JSON.stringify(data, null, 2);
      await fs.writeFile(filepath, jsonContent, 'utf-8');
      console.log(`Wrote ${filename}`);
    } catch (error) {
      console.error(`Failed to write ${filename}:`, error);
      throw error;
    }
  }
}