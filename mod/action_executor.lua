-- Action execution module for Balatro MCP mod
-- Handles execution of actions requested by the MCP server

local ActionExecutor = {}
ActionExecutor.__index = ActionExecutor

function ActionExecutor.new(state_extractor, joker_manager)
    local self = setmetatable({}, ActionExecutor)
    self.state_extractor = state_extractor
    self.joker_manager = joker_manager
    return self
end

function ActionExecutor:execute_action(action_data)
    -- Execute an action and return the result
    local action_type = action_data.action_type
    
    print("BalatroMCP: Executing action: " .. action_type)
    
    local success = false
    local error_message = nil
    local new_state = nil
    
    -- Execute the appropriate action
    if action_type == "play_hand" then
        success, error_message = self:execute_play_hand(action_data)
    elseif action_type == "discard_cards" then
        success, error_message = self:execute_discard_cards(action_data)
    elseif action_type == "go_to_shop" then
        success, error_message = self:execute_go_to_shop(action_data)
    elseif action_type == "buy_item" then
        success, error_message = self:execute_buy_item(action_data)
    elseif action_type == "sell_joker" then
        success, error_message = self:execute_sell_joker(action_data)
    elseif action_type == "sell_consumable" then
        success, error_message = self:execute_sell_consumable(action_data)
    elseif action_type == "reorder_jokers" then
        success, error_message = self:execute_reorder_jokers(action_data)
    elseif action_type == "select_blind" then
        success, error_message = self:execute_select_blind(action_data)
    elseif action_type == "select_pack_offer" then
        success, error_message = self:execute_select_pack_offer(action_data)
    elseif action_type == "reroll_boss" then
        success, error_message = self:execute_reroll_boss(action_data)
    elseif action_type == "reroll_shop" then
        success, error_message = self:execute_reroll_shop(action_data)
    elseif action_type == "sort_hand_by_rank" then
        success, error_message = self:execute_sort_hand_by_rank(action_data)
    elseif action_type == "sort_hand_by_suit" then
        success, error_message = self:execute_sort_hand_by_suit(action_data)
    elseif action_type == "use_consumable" then
        success, error_message = self:execute_use_consumable(action_data)
    elseif action_type == "diagnose_blind_progression" then
        success, error_message = self:execute_diagnose_blind_progression(action_data)
    elseif action_type == "diagnose_blind_activation" then
        success, error_message = self:execute_diagnose_blind_activation(action_data)
    else
        success = false
        error_message = "Unknown action type: " .. action_type
    end
    
    -- Get new state after action execution
    if success then
        new_state = self.state_extractor:extract_current_state()
    end
    
    return {
        success = success,
        error_message = error_message,
        new_state = new_state
    }
end

function ActionExecutor:execute_play_hand(action_data)
    -- Execute play hand action
    local card_indices = action_data.card_indices
    
    if not card_indices or #card_indices == 0 then
        return false, "No cards specified"
    end
    
    -- Validate indices
    if not G or not G.hand or not G.hand.cards then
        return false, "No hand available"
    end
    
    local hand_size = #G.hand.cards
    for _, index in ipairs(card_indices) do
        if index < 0 or index >= hand_size then
            return false, "Invalid card index: " .. index
        end
    end
    
    -- Select the cards
    for _, index in ipairs(card_indices) do
        local card = G.hand.cards[index + 1] -- Lua 1-based indexing
        if card then
            G.hand:add_to_highlighted(card)
        end
    end
    
    -- Trigger play hand action
    -- This needs to interface with Balatro's game mechanics
    if G.FUNCS and G.FUNCS.play_cards_from_highlighted then
        G.FUNCS.play_cards_from_highlighted()
        return true, nil
    else
        return false, "Play hand function not available"
    end
end

function ActionExecutor:execute_discard_cards(action_data)
    -- Execute discard cards action
    local card_indices = action_data.card_indices
    
    if not card_indices or #card_indices == 0 then
        return false, "No cards specified"
    end
    
    -- Validate indices
    if not G or not G.hand or not G.hand.cards then
        return false, "No hand available"
    end
    
    local hand_size = #G.hand.cards
    for _, index in ipairs(card_indices) do
        if index < 0 or index >= hand_size then
            return false, "Invalid card index: " .. index
        end
    end
    
    -- Select the cards for discard
    for _, index in ipairs(card_indices) do
        local card = G.hand.cards[index + 1] -- Lua 1-based indexing
        if card then
            G.hand:add_to_highlighted(card)
        end
    end
    
    -- Trigger discard action
    if G.FUNCS and G.FUNCS.discard_cards_from_highlighted then
        G.FUNCS.discard_cards_from_highlighted()
        return true, nil
    else
        return false, "Discard function not available"
    end
end

function ActionExecutor:execute_go_to_shop(action_data)
    -- Navigate to shop using cash_out function
    print("BalatroMCP: Executing cash_out to go to shop")
    
    -- STATE VALIDATION: Ensure we're in correct state for cash out
    if not G or not G.STATE or not G.STATES then
        return false, "Game state not available"
    end
    
    if G.STATE ~= G.STATES.ROUND_EVAL then
        local current_state_name = "UNKNOWN"
        if G.STATES then
            for name, value in pairs(G.STATES) do
                if value == G.STATE then
                    current_state_name = name
                    break
                end
            end
        end
        return false, "Cannot cash out, must be in round eval state. Current state: " .. current_state_name
    end
    
    -- Validate G.FUNCS.cash_out exists
    if not G.FUNCS or not G.FUNCS.cash_out then
        return false, "Cash out function not available"
    end
    
    -- Create fake button config for cash_out function
    local fake_button = {
        config = {
            button = ""
        }
    }
    
    -- Execute cash_out using event manager
    if G.E_MANAGER and G.E_MANAGER.add_event then
        G.E_MANAGER:add_event(Event({
            trigger = 'immediate',
            no_delete = true,
            func = function()
                G.FUNCS.cash_out(fake_button)
                return true
            end
        }))
        print("BalatroMCP: Cash out event added successfully")
        return true, nil
    else
        return false, "Event manager not available"
    end
end

function ActionExecutor:execute_buy_item(action_data)
    -- Buy an item from the shop using the correct Balatro purchase pattern for different item types
    local shop_index = action_data.shop_index
    
    if not shop_index or shop_index < 0 then
        return false, "Invalid shop index"
    end
    
    -- STATE VALIDATION: Ensure we're in shop state
    if not G or not G.STATE or not G.STATES then
        return false, "Game state not available"
    end
    
    if G.STATE ~= G.STATES.SHOP then
        local current_state_name = "UNKNOWN"
        if G.STATES then
            for name, value in pairs(G.STATES) do
                if value == G.STATE then
                    current_state_name = name
                    break
                end
            end
        end
        return false, "Cannot buy item, must be in shop state. Current state: " .. current_state_name
    end
    
    -- Build unified shop list with item type tracking in the same order as the game displays them
    local shop_items = {}
    local shop_collections = {
        {collection = G.shop_jokers, name = "jokers", type = "main"},
        {collection = G.shop_consumables, name = "consumables", type = "main"},  -- For planets, tarots, spectrals
        {collection = G.shop_booster, name = "boosters", type = "booster"},      -- For booster packs
        {collection = G.shop_vouchers, name = "vouchers", type = "voucher"}      -- For vouchers
    }
    
    -- Build unified shop list in display order, tracking item types
    for _, shop_collection in ipairs(shop_collections) do
        if shop_collection.collection and shop_collection.collection.cards then
            for _, card in ipairs(shop_collection.collection.cards) do
                table.insert(shop_items, {card = card, type = shop_collection.type, name = shop_collection.name})
            end
        end
    end
    
    -- Validate shop index
    if #shop_items == 0 then
        return false, "No shop items available"
    end
    
    if shop_index >= #shop_items then
        return false, "Shop item not found at index: " .. shop_index .. " (max: " .. (#shop_items - 1) .. ")"
    end
    
    local shop_item = shop_items[shop_index + 1] -- Lua 1-based indexing
    local card = shop_item.card
    local item_type = shop_item.type
    local item_category = shop_item.name
    
    print("BalatroMCP: Attempting to buy " .. item_category .. " item at index " .. shop_index .. " (type: " .. item_type .. ")")
    
    -- Check if there's space for the purchase (only for main items)
    if item_type == "main" and G.FUNCS and G.FUNCS.check_for_buy_space then
        if not G.FUNCS.check_for_buy_space(card) then
            return false, "Cannot buy item - no space available"
        end
    end
    
    -- Check if player can afford it (accounting for bankrupt_at like the working code)
    local cost = card.cost or 0
    local available_money = (G.GAME.dollars or 0) - (G.GAME.bankrupt_at or 0)
    
    if cost > available_money and cost > 0 then
        return false, "Not enough money: need " .. cost .. " but have " .. available_money .. " available"
    end
    
    -- Execute purchase using the correct Balatro pattern based on item type
    local success, error_result
    
    if item_type == "main" then
        -- Main shop items (jokers, consumables) use buy_from_shop
        if not G.FUNCS or not G.FUNCS.buy_from_shop then
            return false, "Buy function not available"
        end
        
        print("BalatroMCP: Calling G.FUNCS.buy_from_shop for " .. item_category)
        success, error_result = pcall(function()
            G.FUNCS.buy_from_shop({config = {ref_table = card}})
        end)
        
    elseif item_type == "voucher" then
        -- Vouchers use use_card
        if not G.FUNCS or not G.FUNCS.use_card then
            return false, "Use card function not available"
        end
        
        print("BalatroMCP: Calling G.FUNCS.use_card for voucher")
        success, error_result = pcall(function()
            G.FUNCS.use_card({config = {ref_table = card}})
        end)
        
    elseif item_type == "booster" then
        -- Boosters use use_card
        if not G.FUNCS or not G.FUNCS.use_card then
            return false, "Use card function not available"
        end
        
        print("BalatroMCP: Calling G.FUNCS.use_card for booster pack")
        success, error_result = pcall(function()
            G.FUNCS.use_card({config = {ref_table = card}})
        end)
        
    else
        return false, "Unknown item type: " .. item_type
    end
    
    if success then
        print("BalatroMCP: " .. item_category .. " purchase successful!")
        return true, nil
    else
        return false, "Purchase failed: " .. tostring(error_result)
    end
end

function ActionExecutor:execute_sell_joker(action_data)
    -- Sell a joker
    local joker_index = action_data.joker_index
    
    if not joker_index or joker_index < 0 then
        return false, "Invalid joker index"
    end
    
    if not G or not G.jokers or not G.jokers.cards then
        return false, "No jokers available"
    end
    
    local joker = G.jokers.cards[joker_index + 1] -- Lua 1-based indexing
    if not joker then
        return false, "Joker not found at index: " .. joker_index
    end
    
    -- Execute sale
    if joker.sell_card then
        joker:sell_card()
        return true, nil
    else
        return false, "Joker cannot be sold"
    end
end

function ActionExecutor:execute_sell_consumable(action_data)
    -- Sell a consumable
    local consumable_index = action_data.consumable_index
    
    if not consumable_index or consumable_index < 0 then
        return false, "Invalid consumable index"
    end
    
    if not G or not G.consumeables or not G.consumeables.cards then
        return false, "No consumables available"
    end
    
    local consumable = G.consumeables.cards[consumable_index + 1] -- Lua 1-based indexing
    if not consumable then
        return false, "Consumable not found at index: " .. consumable_index
    end
    
    -- Execute sale
    if consumable.sell_card then
        consumable:sell_card()
        return true, nil
    else
        return false, "Consumable cannot be sold"
    end
end

function ActionExecutor:execute_reorder_jokers(action_data)
    -- Reorder jokers - critical for Blueprint/Brainstorm strategy
    local new_order = action_data.new_order
    
    if not new_order or #new_order == 0 then
        return false, "No new order specified"
    end
    
    return self.joker_manager:reorder_jokers(new_order)
end

function ActionExecutor:execute_select_blind(action_data)
    -- Select a blind using the correct UI button element approach
    local blind_type = action_data.blind_type
    
    if not blind_type then
        return false, "No blind type specified"
    end
    
    print("BalatroMCP: Selecting blind: " .. blind_type)
    
    -- STATE VALIDATION: Ensure we're in correct state for blind selection
    if not G or not G.STATE or not G.STATES then
        return false, "Game state not available"
    end
    
    if G.STATE ~= G.STATES.BLIND_SELECT then
        local current_state_name = "UNKNOWN"
        if G.STATES then
            for name, value in pairs(G.STATES) do
                if value == G.STATE then
                    current_state_name = name
                    break
                end
            end
        end
        return false, "Game not in blind selection state. Current state: " .. current_state_name
    end
    
    -- Validate G.FUNCS.select_blind exists
    if not G.FUNCS or not G.FUNCS.select_blind then
        return false, "Blind selection function not available"
    end
    
    -- CORRECTED APPROACH: Use real UI button element like working game code
    -- Based on the working code sample: G.blind_select_opts[string.lower(G.GAME.blind_on_deck)]:get_UIE_by_ID("select_blind_button")
    
    -- First, validate that G.blind_select_opts exists
    if not G.blind_select_opts then
        return false, "G.blind_select_opts not available - blind selection UI not initialized"
    end
    
    -- Get the blind option UI element for the requested blind type
    local blind_key = string.lower(blind_type)
    local blind_option = G.blind_select_opts[blind_key]
    
    if not blind_option then
        -- List available blind options for debugging
        local available_blinds = {}
        for key, _ in pairs(G.blind_select_opts) do
            table.insert(available_blinds, key)
        end
        return false, "Blind option '" .. blind_key .. "' not found. Available: " .. table.concat(available_blinds, ", ")
    end
    
    -- Get the actual button element from the blind option
    if not blind_option.get_UIE_by_ID then
        return false, "Blind option missing get_UIE_by_ID method"
    end
    
    local select_button = blind_option:get_UIE_by_ID("select_blind_button")
    if not select_button then
        return false, "Select blind button not found in blind option UI"
    end
    
    -- Call G.FUNCS.select_blind with the actual button element
    print("BalatroMCP: Calling G.FUNCS.select_blind with proper UI button")
    local success, error_result = pcall(function()
        G.FUNCS.select_blind(select_button)
    end)
    
    if success then
        print("BalatroMCP: Blind selection successful!")
        return true, nil
    else
        return false, "Blind selection failed: " .. tostring(error_result)
    end
end

function ActionExecutor:execute_select_pack_offer(action_data)
    -- Select a pack offer
    local pack_index = action_data.pack_index
    
    if not pack_index or pack_index < 0 then
        return false, "Invalid pack index"
    end
    
    -- Interface with pack selection system
    return false, "Pack selection not yet implemented"
end

function ActionExecutor:execute_reroll_boss(action_data)
    -- Reroll boss blind
    if G.FUNCS and G.FUNCS.reroll_boss then
        G.FUNCS.reroll_boss()
        return true, nil
    else
        return false, "Boss reroll not available"
    end
end

function ActionExecutor:execute_reroll_shop(action_data)
    -- Reroll shop contents
    if G.FUNCS and G.FUNCS.reroll_shop then
        G.FUNCS.reroll_shop()
        return true, nil
    else
        return false, "Shop reroll not available"
    end
end

function ActionExecutor:execute_sort_hand_by_rank(action_data)
    -- Sort hand cards by rank
    if not G or not G.hand or not G.hand.cards then
        return false, "No hand available"
    end
    
    -- Sort cards by rank
    table.sort(G.hand.cards, function(a, b)
        local rank_order = {
            ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6, ["7"] = 7, ["8"] = 8,
            ["9"] = 9, ["10"] = 10, ["Jack"] = 11, ["Queen"] = 12, ["King"] = 13, ["Ace"] = 14
        }
        local rank_a = rank_order[a.base.value] or 0
        local rank_b = rank_order[b.base.value] or 0
        return rank_a < rank_b
    end)
    
    -- Update card positions
    for i, card in ipairs(G.hand.cards) do
        card.T.x = (i - 1) * G.CARD_W * 0.7
    end
    
    return true, nil
end

function ActionExecutor:execute_sort_hand_by_suit(action_data)
    -- Sort hand cards by suit
    if not G or not G.hand or not G.hand.cards then
        return false, "No hand available"
    end
    
    -- Sort cards by suit
    table.sort(G.hand.cards, function(a, b)
        local suit_order = {["Spades"] = 1, ["Hearts"] = 2, ["Clubs"] = 3, ["Diamonds"] = 4}
        local suit_a = suit_order[a.base.suit] or 0
        local suit_b = suit_order[b.base.suit] or 0
        return suit_a < suit_b
    end)
    
    -- Update card positions
    for i, card in ipairs(G.hand.cards) do
        card.T.x = (i - 1) * G.CARD_W * 0.7
    end
    
    return true, nil
end

function ActionExecutor:execute_use_consumable(action_data)
    -- Use a consumable card
    local item_id = action_data.item_id
    
    if not item_id then
        return false, "No consumable ID specified"
    end
    
    if not G or not G.consumeables or not G.consumeables.cards then
        return false, "No consumables available"
    end
    
    -- Find the consumable by ID
    local consumable = nil
    for _, card in ipairs(G.consumeables.cards) do
        if card.unique_val == item_id then
            consumable = card
            break
        end
    end
    
    if not consumable then
        return false, "Consumable not found: " .. item_id
    end
    
    -- Use the consumable
    if consumable.use then
        consumable:use()
        return true, nil
    else
        return false, "Consumable cannot be used"
    end
end

function ActionExecutor:execute_diagnose_blind_progression(action_data)
    -- Execute blind progression diagnostics
    print("BalatroMCP: Running blind progression diagnostics...")
    
    -- Load diagnostic module using SMODS with required ID
    local BlindProgressionDiagnostics = SMODS.load_file('blind_progression_diagnostics.lua', 'balatro_mcp')()
    local diagnostics = BlindProgressionDiagnostics.new()
    
    -- Run comprehensive diagnosis
    diagnostics:diagnose_blind_state()
    diagnostics:log_hand_result_processing()
    
    return true, nil
end

function ActionExecutor:execute_diagnose_blind_activation(action_data)
    -- Execute blind activation diagnostics
    print("BalatroMCP: Running blind activation diagnostics...")
    
    -- Load diagnostic module using SMODS with required ID
    local BlindActivationDiagnostics = SMODS.load_file('blind_activation_diagnostics.lua', 'balatro_mcp')()
    local diagnostics = BlindActivationDiagnostics.new()
    
    -- Run comprehensive activation diagnosis
    diagnostics:diagnose_blind_activation_state()
    diagnostics:check_blind_database()
    
    return true, nil
end

return ActionExecutor