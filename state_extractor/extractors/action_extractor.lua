-- Available actions detection module
-- Handles available actions detection

local IExtractor = require("state_extractor.extractors.i_extractor")
local StateExtractorUtils = require("state_extractor.utils.state_extractor_utils")

local ActionExtractor = {}
ActionExtractor.__index = ActionExtractor
setmetatable(ActionExtractor, {__index = IExtractor})

function ActionExtractor.new()
    local self = setmetatable({}, ActionExtractor)
    return self
end

function ActionExtractor:get_name()
    return "action_extractor"
end

function ActionExtractor:extract()
    local success, result = pcall(function()
        return self:get_available_actions()
    end)
    
    if success then
        return {available_actions = result}
    else
        return {available_actions = {}}
    end
end

function ActionExtractor:get_available_actions()
    local actions = {}
    local phase = self:get_current_phase()
    
    if phase == "hand_selection" then
        if self:get_hands_remaining() > 0 then
            table.insert(actions, "play_hand")
        end
        if self:get_discards_remaining() > 0 then
            table.insert(actions, "discard_cards")
        end
        table.insert(actions, "go_to_shop")
        table.insert(actions, "sort_hand_by_rank")
        table.insert(actions, "sort_hand_by_suit")
        table.insert(actions, "sell_joker")
        table.insert(actions, "sell_consumable")
        table.insert(actions, "reorder_jokers")
        table.insert(actions, "move_playing_card")
        table.insert(actions, "use_consumable")
    elseif phase == "shop" then
        table.insert(actions, "buy_item")
        table.insert(actions, "sell_joker")
        table.insert(actions, "sell_consumable")
        table.insert(actions, "reroll_shop")
        table.insert(actions, "reorder_jokers")
        table.insert(actions, "use_consumable")
        table.insert(actions, "go_next")
    elseif phase == "blind_selection" then
        table.insert(actions, "select_blind")
        table.insert(actions, "reroll_boss")
        -- TODO: This is not available for boss blind
        table.insert(actions, "skip_blind")
    end
    
    -- Add consumable usage if consumables are available
    if self:has_consumables() then
        table.insert(actions, "use_consumable")
    end
    
    -- Add joker reordering if available
    if self:is_joker_reorder_available() then
        table.insert(actions, "reorder_jokers")
    end
    
    return actions
end

-- Helper methods for action detection
function ActionExtractor:get_current_phase()
    -- Simplified phase detection for action purposes
    if not StateExtractorUtils.safe_check_path(G, {"STATE"}) then
        return "hand_selection"
    end
    
    if not StateExtractorUtils.safe_check_path(G, {"STATES"}) then
        return "hand_selection"
    end
    
    local current_state = G.STATE
    local states = G.STATES
    
    if current_state == states.SELECTING_HAND then
        return "hand_selection"
    elseif current_state == states.SHOP then
        return "shop"
    elseif current_state == states.BLIND_SELECT then
        return "blind_selection"
    else
        return "hand_selection" -- Safe default
    end
end

function ActionExtractor:get_hands_remaining()
    if G and G.GAME and G.GAME.current_round and type(G.GAME.current_round.hands_left) == "number" then
        return G.GAME.current_round.hands_left
    end
    return 0
end

function ActionExtractor:get_discards_remaining()
    if G and G.GAME and G.GAME.current_round and type(G.GAME.current_round.discards_left) == "number" then
        return G.GAME.current_round.discards_left
    end
    return 0
end

function ActionExtractor:has_consumables()
    if not StateExtractorUtils.safe_check_path(G, {"consumeables", "cards"}) then
        return false
    end
    return #G.consumeables.cards > 0
end

function ActionExtractor:is_joker_reorder_available()
    return false -- Placeholder - needs implementation
end

return ActionExtractor