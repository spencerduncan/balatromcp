-- Action execution module for Balatro MCP mod
-- Handles execution of actions requested by the MCP server

-- Load validation framework components
local ActionValidator = assert(SMODS.load_file("action_executor/validators/action_validator.lua"))()
local BlindValidator = assert(SMODS.load_file("action_executor/validators/blind_validator.lua"))()
local RerollValidator = assert(SMODS.load_file("action_executor/validators/reroll_validator.lua"))()
local StateExtractorUtils = assert(SMODS.load_file("state_extractor/utils/state_extractor_utils.lua"))()

local ActionExecutor = {}
ActionExecutor.__index = ActionExecutor

function ActionExecutor.new(state_extractor, joker_manager)
    local self = setmetatable({}, ActionExecutor)
    self.state_extractor = state_extractor
    self.joker_manager = joker_manager
    
    -- Validate that dependencies are available before framework initialization
    if not state_extractor then
        print("BalatroMCP: Warning - ActionExecutor created without state_extractor dependency")
    end
    
    if not joker_manager then
        print("BalatroMCP: Warning - ActionExecutor created without joker_manager dependency")
    end
    
    -- Defer validator initialization to ensure extractors are ready
    self.validator = nil
    self.reroll_tracker = nil
    self._validators_initialized = false
    
    print("BalatroMCP: ActionExecutor created, validation framework will be initialized on first use")
    return self
end

-- Lazy initialization of validation framework to avoid dependency issues
function ActionExecutor:ensure_validators_initialized()
    if self._validators_initialized then
        return true
    end
    
    -- Validate that state_extractor is ready before proceeding
    if not self.state_extractor then
        print("BalatroMCP: Warning - Cannot initialize validators without state_extractor")
        return false
    end
    
    -- Initialize validation framework
    self.validator = ActionValidator.new()
    
    -- Register validators for specific action types
    local blind_validator = BlindValidator.new()
    local reroll_validator = RerollValidator.new()
    
    self.validator:register_validator(blind_validator)
    self.validator:register_validator(reroll_validator)
    
    -- Store reroll tracker reference for cost deduction and tracking
    self.reroll_tracker = reroll_validator:get_reroll_tracker()
    
    -- Initialize the validation framework
    local init_success = pcall(function()
        self.validator:initialize()
    end)
    
    if init_success then
        self._validators_initialized = true
        print("BalatroMCP: Validation framework initialized successfully")
        return true
    else
        print("BalatroMCP: Warning - Failed to initialize validation framework")
        return false
    end
end

-- Centralized validation methods to eliminate code duplication
function ActionExecutor:validate_game_state()
    if not G then
        return false, "Game state not available"
    end

    if not G.STATE then
        return false, "Game state not available"
    end

    if not G.STATES then
        return false, "Game state not available"
    end

    return true, nil
end

function ActionExecutor:get_current_state_name()
    if not G or not G.STATES then
        return "UNKNOWN"
    end

    for name, value in pairs(G.STATES) do
        if value == G.STATE then
            return name
        end
    end

    return "UNKNOWN"
end

function ActionExecutor:execute_action(action_data)
    local action_type = action_data.action_type
    
    print("BalatroMCP: Executing action: " .. action_type)
    
    -- Ensure validators are initialized before proceeding
    if not self:ensure_validators_initialized() then
        return {
            success = false,
            error_message = "Validation framework not available - dependencies not ready",
            new_state = nil
        }
    end
    
    -- NEW: Validate action before execution
    local game_state = self.validator:get_current_game_state()
    
    -- Add voucher information to game state for validation
    if self.state_extractor then
        local success, voucher_data = pcall(function()
            local VoucherAnteExtractor = assert(SMODS.load_file("state_extractor/extractors/voucher_ante_extractor.lua"))()
            local extractor = VoucherAnteExtractor.new()
            local result = extractor:extract()
            return result and result.vouchers_ante
        end)
        
        if success and voucher_data and type(voucher_data) == "table" then
            local owned_vouchers = voucher_data.owned_vouchers
            if owned_vouchers and type(owned_vouchers) == "table" then
                game_state.owned_vouchers = owned_vouchers
            else
                game_state.owned_vouchers = {}
            end
        else
            game_state.owned_vouchers = {}
        end
    else
        game_state.owned_vouchers = {}
    end
    
    local validation_result = self.validator:validate_action(action_type, action_data, game_state)
    
    if not validation_result.is_valid then
        print("BalatroMCP: Action validation failed: " .. validation_result.error_message)
        return {
            success = false,
            error_message = validation_result.error_message,
            new_state = nil
        }
    end
    
    print("BalatroMCP: Action validation passed: " .. validation_result.success_message)
    
    -- Continue with existing execution logic
    -- action_data may be modified by validation (e.g., blind_type override)
    local success = false
    local error_message = nil
    local new_state = nil
    
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
    elseif action_type == "use_pack_tarot" then
        success, error_message = self:execute_use_pack_tarot(action_data)
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
    elseif action_type == "move_playing_card" then
        success, error_message = self:execute_move_playing_card(action_data)
    elseif action_type == "skip_blind" then
        success, error_message = self:execute_skip_blind(action_data)
    elseif action_type == "go_next" then
        success, error_message = self:execute_go_next(action_data)
    else
        success = false
        error_message = "Unknown action type: " .. action_type
    end
    
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
    local card_indices = action_data.card_indices
    
    if not card_indices or #card_indices == 0 then
        return false, "No cards specified"
    end
    
    if not G or not G.hand or not G.hand.cards then
        return false, "No hand available"
    end
    
    local hand_size = #G.hand.cards
    for _, index in ipairs(card_indices) do
        if index < 0 or index >= hand_size then
            return false, "Invalid card index: " .. index
        end
    end
    
    for _, index in ipairs(card_indices) do
        local card = G.hand.cards[index + 1] -- Lua 1-based indexing
        if card then
            G.hand:add_to_highlighted(card)
        end
    end
    
    if G.FUNCS and G.FUNCS.play_cards_from_highlighted then
        G.FUNCS.play_cards_from_highlighted()
        return true, nil
    else
        return false, "Play hand function not available"
    end
end

function ActionExecutor:execute_discard_cards(action_data)
    local card_indices = action_data.card_indices
    
    if not card_indices or #card_indices == 0 then
        return false, "No cards specified"
    end
    
    if not G or not G.hand or not G.hand.cards then
        return false, "No hand available"
    end
    
    local hand_size = #G.hand.cards
    for _, index in ipairs(card_indices) do
        if index < 0 or index >= hand_size then
            return false, "Invalid card index: " .. index
        end
    end
    
    for _, index in ipairs(card_indices) do
        local card = G.hand.cards[index + 1] -- Lua 1-based indexing
        if card then
            G.hand:add_to_highlighted(card)
        end
    end
    
    if G.FUNCS and G.FUNCS.discard_cards_from_highlighted then
        G.FUNCS.discard_cards_from_highlighted()
        return true, nil
    else
        return false, "Discard function not available"
    end
end

function ActionExecutor:execute_go_to_shop(action_data)
    print("BalatroMCP: Executing cash_out to go to shop")
    
    local success, error_message = self:validate_game_state()
    if not success then
        return false, error_message
    end
    
    if G.STATE ~= G.STATES.ROUND_EVAL then
        local current_state_name = self:get_current_state_name()
        return false, "Cannot cash out, must be in round eval state. Current state: " .. current_state_name
    end
    
    if not G.FUNCS or not G.FUNCS.cash_out then
        return false, "Cash out function not available"
    end
    
    local fake_button = {
        config = {
            button = ""
        }
    }
    
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
    local shop_index = action_data.shop_index
    
    if not shop_index or shop_index < 0 then
        return false, "Invalid shop index"
    end
    
    local success, error_message = self:validate_game_state()
    if not success then
        return false, error_message
    end
    
    if G.STATE ~= G.STATES.SHOP then
        local current_state_name = self:get_current_state_name()
        return false, "Cannot buy item, must be in shop state. Current state: " .. current_state_name
    end
    
    local shop_items = {}
    local shop_collections = {
        {collection = G.shop_jokers, name = "jokers", type = "main", category = "joker"},
        {collection = G.shop_consumables, name = "consumables", type = "main", category = "consumable"},  -- For planets, tarots, spectrals
        {collection = G.shop_booster, name = "boosters", type = "booster", category = "booster"},      -- For booster packs
        {collection = G.shop_vouchers, name = "vouchers", type = "voucher", category = "voucher"}      -- For vouchers
    }
    
    for _, shop_collection in ipairs(shop_collections) do
        if shop_collection.collection and shop_collection.collection.cards then
            for _, card in ipairs(shop_collection.collection.cards) do
                table.insert(shop_items, {card = card, type = shop_collection.type, name = shop_collection.name, category = shop_collection.category})
            end
        end
    end
    
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
    local is_consumable = card.ability.set == "Planet" or card.ability.set == "Tarot" or card.ability.set == "Spectral"
    
    print("BalatroMCP: Attempting to buy " .. item_category .. " item at index " .. shop_index .. " (type: " .. item_type .. ", category: " .. card.ability.set .. ", buy_and_use: " .. tostring(buy_and_use) .. ")")
    
    -- Check for buy space, but skip if using buy_and_use for consumables (they don't go to inventory)
    if item_type == "main" and G.FUNCS and G.FUNCS.check_for_buy_space then
        if not (action_data.buy_and_use == "true" and is_consumable) then
            if not G.FUNCS.check_for_buy_space(card) then
                return false, "Cannot buy item - no space available"
            end
        end
    end
    
    local cost = card.cost or 0
    local available_money = (G.GAME.dollars or 0) - (G.GAME.bankrupt_at or 0)
    
    if cost > available_money and cost > 0 then
        return false, "Not enough money: need " .. cost .. " but have " .. available_money .. " available"
    end
    
    local success, error_result
    
    if item_type == "main" then
        if not G.FUNCS or not G.FUNCS.buy_from_shop then
            return false, "Buy function not available"
        end
        
        -- Handle buy_and_use for consumables
        if action_data.buy_and_use == "true" and is_consumable then
            -- Check if buy_and_use is available for this consumable
            if not G.FUNCS.can_buy_and_use then
                return false, "Buy and use function not available"
            end
            
            print("BalatroMCP: Calling G.FUNCS.buy_from_shop with buy_and_use for " .. item_category)
            success, error_result = pcall(function()
                G.FUNCS.buy_from_shop({config = {ref_table = card, id = "buy_and_use"}})
            end)
        else
            print("BalatroMCP: Calling G.FUNCS.buy_from_shop for " .. item_category)
            success, error_result = pcall(function()
                G.FUNCS.buy_from_shop({config = {ref_table = card}})
            end)
        end
        
    elseif item_type == "voucher" then
        if not G.FUNCS or not G.FUNCS.use_card then
            return false, "Use card function not available"
        end
        
        print("BalatroMCP: Calling G.FUNCS.use_card for voucher")
        success, error_result = pcall(function()
            G.FUNCS.use_card({config = {ref_table = card}})
        end)
        
    elseif item_type == "booster" then
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
    
    if joker.sell_card then
        joker:sell_card()
        return true, nil
    else
        return false, "Joker cannot be sold"
    end
end

function ActionExecutor:execute_sell_consumable(action_data)
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
    
    if consumable.sell_card then
        consumable:sell_card()
        return true, nil
    else
        return false, "Consumable cannot be sold"
    end
end

function ActionExecutor:execute_reorder_jokers(action_data)
    local from_index = action_data.from_index
    local to_index = action_data.to_index
    
    -- Validate from_index parameter
    if from_index == nil or from_index < 0 then
        return false, "Invalid from index"
    end
    
    -- Validate to_index parameter
    if to_index == nil or to_index < 0 then
        return false, "Invalid to index"
    end
    
    print("BalatroMCP: Reordering jokers from index " .. from_index .. " to index " .. to_index)
    
    -- Check if jokers collection exists
    if not G or not G.jokers or not G.jokers.cards then
        return false, "No jokers available"
    end
    
    local joker_count = #G.jokers.cards
    
    -- Handle edge cases
    if joker_count == 0 then
        return false, "No jokers to reorder"
    end
    
    if joker_count == 1 then
        return false, "Cannot reorder with only one joker"
    end
    
    -- Validate indices are within bounds
    if from_index >= joker_count then
        return false, "From index out of bounds: " .. from_index .. " (max: " .. (joker_count - 1) .. ")"
    end
    
    if to_index >= joker_count then
        return false, "To index out of bounds: " .. to_index .. " (max: " .. (joker_count - 1) .. ")"
    end
    
    -- Convert to 1-based indexing for Lua
    local from_lua_index = from_index + 1
    local to_lua_index = to_index + 1
    
    -- Perform the swap
    local temp_joker = G.jokers.cards[from_lua_index]
    G.jokers.cards[from_lua_index] = G.jokers.cards[to_lua_index]
    G.jokers.cards[to_lua_index] = temp_joker
    
    print("BalatroMCP: Joker reordering successful!")
    return true, nil
end

function ActionExecutor:execute_select_blind(action_data)
    local blind_type = action_data.blind_type
    
    if not blind_type then
        return false, "No blind type specified"
    end
    
    print("BalatroMCP: Selecting blind: " .. blind_type)
    
    local success, error_message = self:validate_game_state()
    if not success then
        return false, error_message
    end
    
    if G.STATE ~= G.STATES.BLIND_SELECT then
        local current_state_name = self:get_current_state_name()
        return false, "Game not in blind selection state. Current state: " .. current_state_name
    end
    
    if not G.FUNCS or not G.FUNCS.select_blind then
        return false, "Blind selection function not available"
    end
    
    -- CORRECTED APPROACH: Use real UI button element like working game code
    -- Based on the working code sample: G.blind_select_opts[string.lower(G.GAME.blind_on_deck)]:get_UIE_by_ID("select_blind_button")
    
    if not G.blind_select_opts then
        return false, "G.blind_select_opts not available - blind selection UI not initialized"
    end
    
    local blind_key = string.lower(blind_type)
    local blind_option = G.blind_select_opts[blind_key]
    
    if not blind_option then
        local available_blinds = {}
        for key, _ in pairs(G.blind_select_opts) do
            table.insert(available_blinds, key)
        end
        return false, "Blind option '" .. blind_key .. "' not found. Available: " .. table.concat(available_blinds, ", ")
    end
    
    if not blind_option.get_UIE_by_ID then
        return false, "Blind option missing get_UIE_by_ID method"
    end
    
    local select_button = blind_option:get_UIE_by_ID("select_blind_button")
    if not select_button then
        return false, "Select blind button not found in blind option UI"
    end
    
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
    local pack_index = action_data.pack_index
    
    if not pack_index or pack_index < 0 then
        return false, "Invalid pack index"
    end
    
    print("BalatroMCP: Selecting pack offer at index: " .. pack_index)
    
    local success, error_message = self:validate_game_state()
    if not success then
        return false, error_message
    end
    
    if not G.FUNCS or not G.FUNCS.use_card then
        return false, "Use card function not available"
    end
    
    -- Pack offers are typically stored in G.pack_cards when available
    if not G.pack_cards or not G.pack_cards.cards then
        return false, "No pack offers available"
    end
    
    if pack_index >= #G.pack_cards.cards then
        return false, "Pack offer not found at index: " .. pack_index .. " (max: " .. (#G.pack_cards.cards - 1) .. ")"
    end
    
    local pack_card = G.pack_cards.cards[pack_index + 1] -- Lua 1-based indexing
    if not pack_card then
        return false, "Pack offer not found at index: " .. pack_index
    end
    
    print("BalatroMCP: Calling G.FUNCS.use_card for pack offer")
    local call_success, error_result = pcall(function()
        G.FUNCS.use_card({config = {ref_table = pack_card}})
    end)
    
    if call_success then
        print("BalatroMCP: Pack offer selection successful!")
        return true, nil
    else
        return false, "Pack offer selection failed: " .. tostring(error_result)
    end
end

function ActionExecutor:execute_reroll_boss(action_data)
    -- Validation already completed by ActionValidator, safe to execute
    local current_ante = StateExtractorUtils.safe_get_nested_value(G, {"GAME", "round_resets", "ante"}, 1)
    
    if G.FUNCS and G.FUNCS.reroll_boss then
        -- Track usage for Director's Cut limitation (per ante)
        local success, track_msg = self.reroll_tracker:increment_reroll_usage(current_ante)
        if not success then
            print("BalatroMCP: Warning - Failed to track reroll usage: " .. tostring(track_msg))
        end
        
        -- Execute the reroll (game handles cost deduction automatically)
        local success, error_result = pcall(function()
            G.FUNCS.reroll_boss()
        end)
        
        if success then
            print("BalatroMCP: Boss reroll successful (ante " .. current_ante .. ", cost handled by game)")
            return true, nil
        else
            return false, "Boss reroll failed: " .. tostring(error_result)
        end
    else
        return false, "Boss reroll not available"
    end
end

function ActionExecutor:execute_reroll_shop(action_data)
    if G.FUNCS and G.FUNCS.reroll_shop then
        G.FUNCS.reroll_shop()
        return true, nil
    else
        return false, "Shop reroll not available"
    end
end

function ActionExecutor:execute_sort_hand_by_rank(action_data)
    if not G or not G.hand or not G.hand.cards then
        return false, "No hand available"
    end
    
    table.sort(G.hand.cards, function(a, b)
        local rank_order = {
            ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6, ["7"] = 7, ["8"] = 8,
            ["9"] = 9, ["10"] = 10, ["Jack"] = 11, ["Queen"] = 12, ["King"] = 13, ["Ace"] = 14
        }
        local rank_a = rank_order[a.base.value] or 0
        local rank_b = rank_order[b.base.value] or 0
        return rank_a < rank_b
    end)
    
    for i, card in ipairs(G.hand.cards) do
        card.T.x = (i - 1) * G.CARD_W * 0.7
    end
    
    return true, nil
end

function ActionExecutor:execute_sort_hand_by_suit(action_data)
    if not G or not G.hand or not G.hand.cards then
        return false, "No hand available"
    end
    
    table.sort(G.hand.cards, function(a, b)
        local suit_order = {["Spades"] = 1, ["Hearts"] = 2, ["Clubs"] = 3, ["Diamonds"] = 4}
        local suit_a = suit_order[a.base.suit] or 0
        local suit_b = suit_order[b.base.suit] or 0
        return suit_a < suit_b
    end)
    
    for i, card in ipairs(G.hand.cards) do
        card.T.x = (i - 1) * G.CARD_W * 0.7
    end
    
    return true, nil
end

function ActionExecutor:execute_use_consumable(action_data)
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
    
    if consumable:can_use_consumeable(false, false) then
        G.FUNCS.use_card({config = {ref_table = consumable}})
        return true, nil
    else
        return false, "Consumable cannot be used"
    end
end


function ActionExecutor:execute_move_playing_card(action_data)
    local from_index = action_data.from_index
    local to_index = action_data.to_index
    
    -- Validate from_index parameter
    if from_index == nil or from_index < 0 then
        return false, "Invalid from index"
    end
    
    -- Validate to_index parameter
    if to_index == nil or to_index < 0 then
        return false, "Invalid to index"
    end
    
    print("BalatroMCP: Moving playing card from index " .. from_index .. " to index " .. to_index)
    
    -- Check if hand exists
    if not G or not G.hand or not G.hand.cards then
        return false, "No hand available"
    end
    
    local hand_size = #G.hand.cards
    
    -- Handle edge cases
    if hand_size == 0 then
        return false, "No cards in hand to move"
    end
    
    if hand_size == 1 then
        return false, "Cannot move with only one card in hand"
    end
    
    -- Validate indices are within bounds
    if from_index >= hand_size then
        return false, "From index out of bounds: " .. from_index .. " (max: " .. (hand_size - 1) .. ")"
    end
    
    if to_index >= hand_size then
        return false, "To index out of bounds: " .. to_index .. " (max: " .. (hand_size - 1) .. ")"
    end
    
    -- Convert to 1-based indexing for Lua
    local from_lua_index = from_index + 1
    local to_lua_index = to_index + 1
    
    -- Perform the swap
    local temp_card = G.hand.cards[from_lua_index]
    G.hand.cards[from_lua_index] = G.hand.cards[to_lua_index]
    G.hand.cards[to_lua_index] = temp_card
    
    -- Update card positions for visual consistency
    for i, card in ipairs(G.hand.cards) do
        if card.T then
            card.T.x = (i - 1) * G.CARD_W * 0.7
        end
    end
    
    print("BalatroMCP: Playing card move successful!")
    return true, nil
end

function ActionExecutor:execute_skip_blind(action_data)
    print("BalatroMCP: Executing skip blind")
    
    local success, error_message = self:validate_game_state()
    if not success then
        return false, error_message
    end
    
    if G.STATE ~= G.STATES.BLIND_SELECT then
        local current_state_name = self:get_current_state_name()
        return false, "Cannot skip blind, must be in blind selection state. Current state: " .. current_state_name
    end
    
    -- Check if skip function is available (tests expect this check to take precedence)
    if not G.FUNCS or not G.FUNCS.skip_blind then
        return false, "Skip blind function not available"
    end
    
    if not G.GAME.blind_on_deck then
        return false, "Missing Blind"
    end

    local blind_choice = string.lower(G.GAME.blind_on_deck)
    local blind_option = G.blind_select_opts[blind_choice]

    if not blind_option then
        local available_blinds = {}
        for key, _ in pairs(G.blind_select_opts) do
            table.insert(available_blinds, key)
        end
        return false, "Blind option '" .. blind_choice .. "' not found. Available: " .. table.concat(available_blinds, ", ")
    end
    
    if not blind_option.get_UIE_by_ID then
        return false, "Blind option missing get_UIE_by_ID method"
    end
    
    local skip_button = blind_option:get_UIE_by_ID("tag_container")
    if not skip_button then
        return false, "Skip blind button not found in UI"
    end
    
    print("BalatroMCP: Calling G.FUNCS.skip_blind with skip button")
    local call_success, error_result = pcall(function()
        G.FUNCS.skip_blind(skip_button)
    end)
    
    if call_success then
        print("BalatroMCP: Skip blind successful!")
        return true, nil
    else
        return false, "Skip blind failed: " .. tostring(error_result)
    end
end

function ActionExecutor:execute_go_next(action_data)
    print("BalatroMCP: Executing go next")
    
    local success, error_message = self:validate_game_state()
    if not success then
        return false, error_message
    end
    
    if not G.FUNCS or not G.FUNCS.toggle_shop then
        return false, "Toggle shop function not available"
    end
    
    -- Create a button with toggle_shop id following the established pattern
    local toggle_button = {
        config = {
            button = "toggle_shop"
        }
    }
    
    print("BalatroMCP: Calling G.FUNCS.toggle_shop")
    local call_success, error_result = pcall(function()
        G.FUNCS.toggle_shop(toggle_button)
    end)
    
    if call_success then
        print("BalatroMCP: Go next successful!")
        return true, nil
    else
        return false, "Go next failed: " .. tostring(error_result)
    end
end

function ActionExecutor:execute_use_pack_tarot(action_data)
    local pack_index = action_data.pack_index
    local target_card_indices = action_data.target_card_indices or {}
    
    if not pack_index or pack_index < 0 then
        return false, "Invalid pack index"
    end
    
    print("BalatroMCP: Using pack tarot at index: " .. pack_index .. " with " .. #target_card_indices .. " targets")
    
    local success, error_message = self:validate_game_state()
    if not success then
        return false, error_message
    end
    
    if not G.FUNCS or not G.FUNCS.use_card then
        return false, "Use card function not available"
    end
    
    -- Pack offers are typically stored in G.pack_cards when available
    if not G.pack_cards or not G.pack_cards.cards then
        return false, "No pack offers available"
    end
    
    if pack_index >= #G.pack_cards.cards then
        return false, "Pack offer not found at index: " .. pack_index .. " (max: " .. (#G.pack_cards.cards - 1) .. ")"
    end
    
    local pack_card = G.pack_cards.cards[pack_index + 1] -- Lua 1-based indexing
    if not pack_card then
        return false, "Pack offer not found at index: " .. pack_index
    end
    
    -- Validate that this is a tarot card
    if not pack_card.ability or pack_card.ability.set ~= "Tarot" then
        return false, "Pack item at index " .. pack_index .. " is not a tarot card (found: " .. tostring(pack_card.ability and pack_card.ability.set or "unknown") .. ")"
    end
    
    -- Validate target card indices if provided
    if #target_card_indices > 0 then
        if not G.hand or not G.hand.cards then
            return false, "No hand cards available for targeting"
        end
        
        local hand_size = #G.hand.cards
        for _, target_index in ipairs(target_card_indices) do
            if target_index < 0 or target_index >= hand_size then
                return false, "Invalid target card index: " .. target_index .. " (hand size: " .. hand_size .. ")"
            end
        end
        
        -- Select target cards for tarot use
        for _, target_index in ipairs(target_card_indices) do
            local target_card = G.hand.cards[target_index + 1] -- Lua 1-based indexing
            if target_card then
                G.hand:add_to_highlighted(target_card)
                print("BalatroMCP: Added target card at index " .. target_index .. " to highlighted")
            end
        end
    end
    
    print("BalatroMCP: Calling G.FUNCS.use_card for tarot with " .. #target_card_indices .. " highlighted cards")
    local call_success, error_result = pcall(function()
        G.FUNCS.use_card({config = {ref_table = pack_card}})
    end)
    
    if call_success then
        print("BalatroMCP: Pack tarot use successful!")
        return true, nil
    else
        return false, "Pack tarot use failed: " .. tostring(error_result)
    end
end

return ActionExecutor