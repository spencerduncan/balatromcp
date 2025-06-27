-- Available actions detection module
-- Handles available actions detection

local IExtractor = assert(SMODS.load_file("state_extractor/extractors/i_extractor.lua"))()
local StateExtractorUtils = assert(SMODS.load_file("state_extractor/utils/state_extractor_utils.lua"))()

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
    
    -- Inline phase detection logic
    local phase = "hand_selection" -- Safe default
    if StateExtractorUtils.safe_check_path(G, {"STATE"}) and StateExtractorUtils.safe_check_path(G, {"STATES"}) then
        local current_state = G.STATE
        local states = G.STATES
        
        if current_state == states.SELECTING_HAND then
            phase = "hand_selection"
        elseif current_state == states.SHOP then
            phase = "shop"
        elseif current_state == states.BLIND_SELECT then
            phase = "blind_selection"
        else
            phase = "hand_selection" -- Safe default
        end
    end
    
    if phase == "hand_selection" then
        -- Inline hands remaining check
        local hands_remaining = 0
        if G and G.GAME and G.GAME.current_round and type(G.GAME.current_round.hands_left) == "number" then
            hands_remaining = G.GAME.current_round.hands_left
        end
        
        -- Inline discards remaining check
        local discards_remaining = 0
        if G and G.GAME and G.GAME.current_round and type(G.GAME.current_round.discards_left) == "number" then
            discards_remaining = G.GAME.current_round.discards_left
        end
        
        if hands_remaining > 0 then
            table.insert(actions, "play_hand")
        end
        if discards_remaining > 0 then
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