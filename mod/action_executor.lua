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
            card.highlighted = true
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
            card.highlighted = true
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
    -- Navigate to shop
    print("ActionExecutor: DEBUG - Before go_to_shop call")
    
    -- CRITICAL: Use direct global access to ensure fresh state
    local state_before_direct = _G.G and _G.G.STATE or "NIL"
    local state_before_cached = G and G.STATE or "NIL"
    
    print("ActionExecutor: TIMING - Direct _G.G.STATE before = " .. tostring(state_before_direct))
    print("ActionExecutor: TIMING - Cached G.STATE before = " .. tostring(state_before_cached))
    print("ActionExecutor: TIMING - Are they equal? " .. tostring(state_before_direct == state_before_cached))
    
    if _G.G and _G.G.STATES then
        for key, value in pairs(_G.G.STATES) do
            local marker = (_G.G.STATE == value) and " *** CURRENT ***" or ""
            print("ActionExecutor: DEBUG - " .. key .. " = " .. tostring(value) .. marker)
        end
    end
    
    if G.FUNCS and G.FUNCS.go_to_shop then
        print("ActionExecutor: DEBUG - Calling G.FUNCS.go_to_shop()")
        G.FUNCS.go_to_shop()
        
        -- DIAGNOSTIC: Check state after function call using both methods
        local state_after_direct = _G.G and _G.G.STATE or "NIL"
        local state_after_cached = G and G.STATE or "NIL"
        
        print("ActionExecutor: TIMING - Direct _G.G.STATE after = " .. tostring(state_after_direct))
        print("ActionExecutor: TIMING - Cached G.STATE after = " .. tostring(state_after_cached))
        print("ActionExecutor: TIMING - Are they equal? " .. tostring(state_after_direct == state_after_cached))
        
        -- Check if state actually changed using direct access
        if _G.G and _G.G.STATES and _G.G.STATE == _G.G.STATES.SHOP then
            print("ActionExecutor: DEBUG - SUCCESS: State changed to SHOP (direct access)")
        else
            print("ActionExecutor: DEBUG - WARNING: State did not change to SHOP (direct access)")
        end
        
        return true, nil
    else
        return false, "Shop navigation not available"
    end
end

function ActionExecutor:execute_buy_item(action_data)
    -- Buy an item from the shop
    local shop_index = action_data.shop_index
    
    if not shop_index or shop_index < 0 then
        return false, "Invalid shop index"
    end
    
    -- Access shop items
    if not G or not G.shop_jokers or not G.shop_jokers.cards then
        return false, "No shop available"
    end
    
    local item = G.shop_jokers.cards[shop_index + 1] -- Lua 1-based indexing
    if not item then
        return false, "Shop item not found at index: " .. shop_index
    end
    
    -- Check if player can afford it
    if G.GAME and G.GAME.dollars < (item.cost or 0) then
        return false, "Insufficient funds"
    end
    
    -- Execute purchase
    if item.buy then
        item:buy()
        return true, nil
    else
        return false, "Item cannot be purchased"
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
    -- Select a blind with comprehensive crash diagnostics
    local blind_type = action_data.blind_type
    
    if not blind_type then
        return false, "No blind type specified"
    end
    
    print("ActionExecutor: BLIND_SELECT_DEBUG - Starting select_blind for type: " .. tostring(blind_type))
    
    -- DIAGNOSTIC 1: Validate game state before blind selection
    if not G then
        print("ActionExecutor: BLIND_SELECT_ERROR - G object is nil")
        return false, "Game state not available"
    end
    
    if not G.STATE then
        print("ActionExecutor: BLIND_SELECT_ERROR - G.STATE is nil")
        return false, "Game state invalid"
    end
    
    print("ActionExecutor: BLIND_SELECT_DEBUG - Current G.STATE: " .. tostring(G.STATE))
    
    -- DIAGNOSTIC 2: Check for blind-related objects and their config fields
    local blind_objects_to_check = {"G.GAME", "G.GAME.current_blind", "G.GAME.blind_big", "G.GAME.blind_small"}
    
    for _, obj_path in ipairs(blind_objects_to_check) do
        local obj = nil
        if obj_path == "G.GAME" then
            obj = G.GAME
        elseif obj_path == "G.GAME.current_blind" then
            obj = G.GAME and G.GAME.current_blind
        elseif obj_path == "G.GAME.blind_big" then
            obj = G.GAME and G.GAME.blind_big
        elseif obj_path == "G.GAME.blind_small" then
            obj = G.GAME and G.GAME.blind_small
        end
        
        if obj then
            print("ActionExecutor: BLIND_SELECT_DEBUG - " .. obj_path .. " exists")
            if obj.config then
                print("ActionExecutor: BLIND_SELECT_DEBUG - " .. obj_path .. ".config exists")
            else
                print("ActionExecutor: BLIND_SELECT_ERROR - " .. obj_path .. ".config is NIL - POTENTIAL CRASH SOURCE")
            end
        else
            print("ActionExecutor: BLIND_SELECT_DEBUG - " .. obj_path .. " is nil")
        end
    end
    
    -- DIAGNOSTIC 3: Check what select_blind function expects
    if not G.FUNCS then
        print("ActionExecutor: BLIND_SELECT_ERROR - G.FUNCS is nil")
        return false, "Game functions not available"
    end
    
    if not G.FUNCS.select_blind then
        print("ActionExecutor: BLIND_SELECT_ERROR - G.FUNCS.select_blind is nil")
        return false, "Blind selection function not available"
    end
    
    print("ActionExecutor: BLIND_SELECT_DEBUG - G.FUNCS.select_blind exists, type: " .. type(G.FUNCS.select_blind))
    
    -- DIAGNOSTIC 4: Try to find the actual blind selection UI elements
    local blind_choice_elements = {"G.blind_select", "G.blind_select_opts", "G.ROOM"}
    for _, element_path in ipairs(blind_choice_elements) do
        local element = nil
        if element_path == "G.blind_select" then
            element = G.blind_select
        elseif element_path == "G.blind_select_opts" then
            element = G.blind_select_opts
        elseif element_path == "G.ROOM" then
            element = G.ROOM
        end
        
        if element then
            print("ActionExecutor: BLIND_SELECT_DEBUG - " .. element_path .. " exists, type: " .. type(element))
        else
            print("ActionExecutor: BLIND_SELECT_DEBUG - " .. element_path .. " is nil")
        end
    end
    
    -- DIAGNOSTIC 5: Wrap the function call in crash diagnostics
    print("ActionExecutor: BLIND_SELECT_DEBUG - Attempting to call G.FUNCS.select_blind with parameter: " .. tostring(blind_type))
    
    local success, error_result = pcall(function()
        -- Try different calling patterns that Balatro might expect
        print("ActionExecutor: BLIND_SELECT_DEBUG - Trying direct string parameter call")
        return G.FUNCS.select_blind(blind_type)
    end)
    
    if not success then
        print("ActionExecutor: BLIND_SELECT_ERROR - Direct call failed: " .. tostring(error_result))
        
        -- DIAGNOSTIC 6: Try alternative calling patterns
        print("ActionExecutor: BLIND_SELECT_DEBUG - Trying alternative calling patterns...")
        
        -- Pattern 1: Try with table parameter (common Balatro pattern)
        local alt_success1, alt_error1 = pcall(function()
            print("ActionExecutor: BLIND_SELECT_DEBUG - Trying table parameter call")
            return G.FUNCS.select_blind({type = blind_type})
        end)
        
        if not alt_success1 then
            print("ActionExecutor: BLIND_SELECT_ERROR - Table parameter call failed: " .. tostring(alt_error1))
        else
            print("ActionExecutor: BLIND_SELECT_SUCCESS - Table parameter call succeeded")
            return true, nil
        end
        
        -- Pattern 2: Try with button-like object (UI pattern)
        local alt_success2, alt_error2 = pcall(function()
            print("ActionExecutor: BLIND_SELECT_DEBUG - Trying button object parameter call")
            return G.FUNCS.select_blind({config = {blind = {type = blind_type}}})
        end)
        
        if not alt_success2 then
            print("ActionExecutor: BLIND_SELECT_ERROR - Button object call failed: " .. tostring(alt_error2))
        else
            print("ActionExecutor: BLIND_SELECT_SUCCESS - Button object call succeeded")
            return true, nil
        end
        
        -- All patterns failed
        print("ActionExecutor: BLIND_SELECT_CRITICAL - All calling patterns failed")
        print("ActionExecutor: BLIND_SELECT_CRITICAL - Original error: " .. tostring(error_result))
        return false, "Blind selection failed: " .. tostring(error_result)
    else
        print("ActionExecutor: BLIND_SELECT_SUCCESS - Direct call succeeded")
        return true, nil
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

return ActionExecutor