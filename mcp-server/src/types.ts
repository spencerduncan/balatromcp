/**
 * Types for BalatroMCP message format compatibility
 */

export interface BalatroMCPMessage {
  timestamp: string;
  sequence_id: number;
  message_type: string;
  data: any;
}

export interface ActionData {
  action_type: string;
  sequence_id: number;
  [key: string]: any;
}

export interface GameStateData {
  session_id: string;
  current_phase: string;
  hand_cards: any[];
  jokers: any[];
  consumables: any[];
  shop_jokers: any[];
  blind_info: any;
  game_stats: any;
  money: number;
  ante: number;
  [key: string]: any;
}

export interface DeckStateData {
  session_id: string;
  timestamp: number;
  card_count: number;
  deck_cards: any[];
}

export interface HandLevelsData {
  session_id: string;
  timestamp: number;
  total_hands_played: number;
  hands: Record<string, any>;
}

export interface VouchersAnteData {
  current_ante: number;
  ante_requirements: any;
  owned_vouchers: any[];
  shop_vouchers: any[];
  skip_vouchers: any[];
}

export interface ActionResult {
  action_type: string;
  sequence_id: number;
  success: boolean;
  result: string;
  timestamp: string;
}

export type SupportedActionType = 
  | "skip_blind"
  | "select_blind" 
  | "play_hand"
  | "discard_cards"
  | "go_to_shop"
  | "buy_item"
  | "sell_joker"
  | "sell_consumable"
  | "use_consumable"
  | "reorder_jokers"
  | "reroll_boss"
  | "reroll_shop"
  | "sort_hand_by_rank"
  | "sort_hand_by_suit"
  | "move_playing_card"
  | "select_pack_offer"
  | "go_next"
  | "diagnose_blind_progression"
  | "diagnose_blind_activation";