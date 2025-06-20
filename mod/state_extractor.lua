-- State extraction module for Balatro MCP mod
-- Extracts game state information for the MCP server

local StateExtractor = {}
StateExtractor.__index = StateExtractor

function StateExtractor.new()
    local self = setmetatable({}, StateExtractor)
    self.component_name = "STATE_EXTRACTOR"
    
    -- Immediately test G object availability and structure
    self:log("Initializing StateExtractor")
    self:validate_g_object()
    
    return self
end

function StateExtractor:log(message)
    -- Simple logging for this component
    local log_msg = "BalatroMCP [" .. self.component_name .. "]: " .. message
    print(log_msg)
end

function StateExtractor:validate_g_object()
    -- Comprehensive validation of G object structure
    self:log("=== VALIDATING G OBJECT STRUCTURE ===")
    
    if not G then
        self:log("CRITICAL: Global G object is nil - game state extraction impossible")
        return false
    end
    
    self:log("G object exists")
    
    -- Test critical G object properties
    local critical_properties = {
        "STATE", "STATES", "GAME", "hand", "jokers", "consumeables", "shop_jokers", "FUNCS"
    }
    
    local missing_properties = {}
    for _, prop in ipairs(critical_properties) do
        if G[prop] == nil then
            table.insert(missing_properties, prop)
            self:log("MISSING: G." .. prop .. " is nil")
        else
            self:log("FOUND: G." .. prop .. " exists (type: " .. type(G[prop]) .. ")")
        end
    end
    
    if #missing_properties > 0 then
        self:log("WARNING: Missing " .. #missing_properties .. " critical properties: " .. table.concat(missing_properties, ", "))
    end
    
    -- Test specific structures we rely on
    self:validate_game_object()
    self:validate_card_areas()
    self:validate_states()
    
    return #missing_properties == 0
end

function StateExtractor:validate_game_object()
    if not G or not G.GAME then
        self:log("ERROR: G.GAME object not available")
        return
    end
    
    self:log("--- VALIDATING G.GAME STRUCTURE ---")
    
    local game_properties = {"dollars", "current_round", "round_resets", "blind"}
    for _, prop in ipairs(game_properties) do
        if G.GAME[prop] ~= nil then
            self:log("G.GAME." .. prop .. " = " .. tostring(G.GAME[prop]) .. " (type: " .. type(G.GAME[prop]) .. ")")
        else
            self:log("ERROR: G.GAME." .. prop .. " is nil")
        end
    end
    
    -- Test round structure
    if G.GAME.current_round then
        self:log("--- VALIDATING CURRENT ROUND ---")
        local round_properties = {"hands_left", "discards_left"}
        for _, prop in ipairs(round_properties) do
            if G.GAME.current_round[prop] ~= nil then
                self:log("G.GAME.current_round." .. prop .. " = " .. tostring(G.GAME.current_round[prop]))
            else
                self:log("ERROR: G.GAME.current_round." .. prop .. " is nil")
            end
        end
    end
    
    -- Test ante structure
    if G.GAME.round_resets then
        self:log("--- VALIDATING ROUND RESETS ---")
        if G.GAME.round_resets.ante then
            self:log("G.GAME.round_resets.ante = " .. tostring(G.GAME.round_resets.ante))
        else
            self:log("ERROR: G.GAME.round_resets.ante is nil")
        end
    end
end

function StateExtractor:validate_card_areas()
    self:log("--- VALIDATING CARD AREAS ---")
    
    local areas = {
        {name = "hand", object = G.hand},
        {name = "jokers", object = G.jokers},
        {name = "consumeables", object = G.consumeables},
        {name = "shop_jokers", object = G.shop_jokers}
    }
    
    for _, area in ipairs(areas) do
        if area.object then
            self:log("G." .. area.name .. " exists")
            
            if area.object.cards then
                self:log("G." .. area.name .. ".cards exists with " .. #area.object.cards .. " items")
                
                -- Validate first card structure if available
                if #area.object.cards > 0 then
                    self:validate_card_structure(area.object.cards[1], area.name .. "[1]")
                end
            else
                self:log("ERROR: G." .. area.name .. ".cards is nil")
            end
        else
            self:log("ERROR: G." .. area.name .. " is nil")
        end
    end
end

function StateExtractor:validate_card_structure(card, card_name)
    if not card then
        self:log("ERROR: " .. card_name .. " is nil")
        return
    end
    
    self:log("--- VALIDATING " .. card_name .. " STRUCTURE ---")
    
    -- Check base properties
    if card.base then
        self:log(card_name .. ".base exists")
        if card.base.value then
            self:log(card_name .. ".base.value = " .. tostring(card.base.value))
        else
            self:log("ERROR: " .. card_name .. ".base.value is nil")
        end
        
        if card.base.suit then
            self:log(card_name .. ".base.suit = " .. tostring(card.base.suit))
        else
            self:log("ERROR: " .. card_name .. ".base.suit is nil")
        end
    else
        self:log("ERROR: " .. card_name .. ".base is nil")
    end
    
    -- Check other properties
    local other_properties = {"ability", "edition", "seal", "unique_val", "config"}
    for _, prop in ipairs(other_properties) do
        if card[prop] ~= nil then
            self:log(card_name .. "." .. prop .. " exists (type: " .. type(card[prop]) .. ")")
        else
            self:log("WARNING: " .. card_name .. "." .. prop .. " is nil")
        end
    end
end

function StateExtractor:validate_states()
    if not G.STATE or not G.STATES then
        self:log("ERROR: G.STATE or G.STATES not available")
        return
    end
    
    self:log("--- VALIDATING GAME STATES ---")
    self:log("Current G.STATE = " .. tostring(G.STATE))
    
    -- List all available states
    if type(G.STATES) == "table" then
        local state_names = {}
        for key, value in pairs(G.STATES) do
            table.insert(state_names, key .. "=" .. tostring(value))
        end
        self:log("Available G.STATES: " .. table.concat(state_names, ", "))
    end
end

function StateExtractor:extract_current_state()
    -- This function will extract the current game state
    -- Implementation will depend on Balatro's internal structure
    
    self:log("=== EXTRACTING CURRENT GAME STATE ===")
    
    local state = {}
    local extraction_errors = {}
    
    -- Extract each component with error handling
    local extractions = {
        {name = "session_id", func = function() return self:get_session_id() end},
        {name = "current_phase", func = function() return self:get_current_phase() end},
        {name = "ante", func = function() return self:get_ante() end},
        {name = "money", func = function() return self:get_money() end},
        {name = "hands_remaining", func = function() return self:get_hands_remaining() end},
        {name = "discards_remaining", func = function() return self:get_discards_remaining() end},
        {name = "hand_cards", func = function() return self:extract_hand_cards() end},
        {name = "jokers", func = function() return self:extract_jokers() end},
        {name = "consumables", func = function() return self:extract_consumables() end},
        {name = "current_blind", func = function() return self:extract_current_blind() end},
        {name = "shop_contents", func = function() return self:extract_shop_contents() end},
        {name = "available_actions", func = function() return self:get_available_actions() end},
        {name = "post_hand_joker_reorder_available", func = function() return self:is_joker_reorder_available() end}
    }
    
    for _, extraction in ipairs(extractions) do
        local success, result = pcall(extraction.func)
        if success then
            state[extraction.name] = result
            self:log("Extracted " .. extraction.name .. " successfully")
        else
            table.insert(extraction_errors, extraction.name .. ": " .. tostring(result))
            self:log("ERROR extracting " .. extraction.name .. ": " .. tostring(result))
            state[extraction.name] = nil -- Ensure it's explicitly nil
        end
    end
    
    if #extraction_errors > 0 then
        self:log("STATE EXTRACTION COMPLETED WITH " .. #extraction_errors .. " ERRORS")
        state.extraction_errors = extraction_errors
    else
        self:log("STATE EXTRACTION COMPLETED SUCCESSFULLY")
    end
    
    return state
end

function StateExtractor:get_session_id()
    -- Generate or retrieve session ID
    if not self.session_id then
        self.session_id = "session_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
    end
    return self.session_id
end

function StateExtractor:get_current_phase()
    -- Determine current game phase
    -- This needs to be implemented based on Balatro's game state
    if G and G.STATE then
        if G.STATE == G.STATES.SELECTING_HAND then
            return "hand_selection"
        elseif G.STATE == G.STATES.SHOP then
            return "shop"
        elseif G.STATE == G.STATES.BLIND_SELECT then
            return "blind_selection"
        elseif G.STATE == G.STATES.DRAW_TO_HAND then
            return "hand_selection"
        else
            return "hand_selection" -- Default
        end
    end
    return "hand_selection"
end

function StateExtractor:get_ante()
    -- Get current ante level
    if G and G.GAME and G.GAME.round_resets then
        return G.GAME.round_resets.ante or 1
    end
    return 1
end

function StateExtractor:get_money()
    -- Get current money
    if G and G.GAME then
        return G.GAME.dollars or 0
    end
    return 0
end

function StateExtractor:get_hands_remaining()
    -- Get remaining hands for current round
    if G and G.GAME then
        return G.GAME.current_round.hands_left or 0
    end
    return 0
end

function StateExtractor:get_discards_remaining()
    -- Get remaining discards for current round
    if G and G.GAME then
        return G.GAME.current_round.discards_left or 0
    end
    return 0
end

function StateExtractor:extract_hand_cards()
    -- Extract current hand cards
    local hand_cards = {}
    
    if G and G.hand and G.hand.cards then
        for i, card in ipairs(G.hand.cards) do
            table.insert(hand_cards, {
                id = card.unique_val or ("card_" .. i),
                rank = card.base.value or "A",
                suit = card.base.suit or "Spades",
                enhancement = self:get_card_enhancement(card),
                edition = self:get_card_edition(card),
                seal = self:get_card_seal(card)
            })
        end
    end
    
    return hand_cards
end

function StateExtractor:get_card_enhancement(card)
    -- Determine card enhancement
    if card.ability and card.ability.name then
        local enhancement_map = {
            m_bonus = "bonus",
            m_mult = "mult",
            m_wild = "wild",
            m_glass = "glass",
            m_steel = "steel",
            m_stone = "stone",
            m_gold = "gold"
        }
        return enhancement_map[card.ability.name] or "none"
    end
    return "none"
end

function StateExtractor:get_card_edition(card)
    -- Determine card edition
    if card.edition then
        if card.edition.foil then
            return "foil"
        elseif card.edition.holo then
            return "holographic"
        elseif card.edition.polychrome then
            return "polychrome"
        elseif card.edition.negative then
            return "negative"
        end
    end
    return "none"
end

function StateExtractor:get_card_seal(card)
    -- Determine card seal
    if card.seal then
        return card.seal
    end
    return "none"
end

function StateExtractor:extract_jokers()
    -- Extract current jokers
    local jokers = {}
    
    if G and G.jokers and G.jokers.cards then
        for i, joker in ipairs(G.jokers.cards) do
            table.insert(jokers, {
                id = joker.unique_val or ("joker_" .. i),
                name = joker.ability.name or "Unknown",
                position = i - 1, -- 0-based indexing
                properties = self:extract_joker_properties(joker)
            })
        end
    end
    
    return jokers
end

function StateExtractor:extract_joker_properties(joker)
    -- Extract joker-specific properties
    local properties = {}
    
    if joker.ability then
        properties.extra = joker.ability.extra or {}
        properties.mult = joker.ability.mult or 0
        properties.chips = joker.ability.t_chips or 0
    end
    
    return properties
end

function StateExtractor:extract_consumables()
    -- Extract consumable cards
    local consumables = {}
    
    if G and G.consumeables and G.consumeables.cards then
        for i, consumable in ipairs(G.consumeables.cards) do
            table.insert(consumables, {
                id = consumable.unique_val or ("consumable_" .. i),
                name = consumable.ability.name or "Unknown",
                card_type = consumable.ability.set or "Tarot",
                properties = consumable.ability.extra or {}
            })
        end
    end
    
    return consumables
end

function StateExtractor:extract_current_blind()
    -- Extract current blind information
    if G and G.GAME and G.GAME.blind then
        local blind = G.GAME.blind
        return {
            name = blind.name or "Unknown",
            blind_type = self:determine_blind_type(blind),
            requirement = blind.chips or 0,
            reward = blind.dollars or 0,
            properties = blind.config or {}
        }
    end
    
    return nil
end

function StateExtractor:determine_blind_type(blind)
    -- Determine the type of blind
    if blind.boss then
        return "boss"
    elseif blind.name and string.find(blind.name, "Big") then
        return "big"
    else
        return "small"
    end
end

function StateExtractor:extract_shop_contents()
    -- Extract shop contents
    local shop_contents = {}
    
    if G and G.shop_jokers and G.shop_jokers.cards then
        for i, item in ipairs(G.shop_jokers.cards) do
            table.insert(shop_contents, {
                index = i - 1, -- 0-based indexing
                item_type = "joker",
                name = item.ability.name or "Unknown",
                cost = item.cost or 0,
                properties = item.ability.extra or {}
            })
        end
    end
    
    -- Add other shop items (booster packs, consumables, etc.)
    -- This would need to be expanded based on Balatro's shop structure
    
    return shop_contents
end

function StateExtractor:get_available_actions()
    -- Determine available actions based on current game state
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
    elseif phase == "shop" then
        table.insert(actions, "buy_item")
        table.insert(actions, "sell_joker")
        table.insert(actions, "sell_consumable")
        table.insert(actions, "reroll_shop")
    elseif phase == "blind_selection" then
        table.insert(actions, "select_blind")
        table.insert(actions, "reroll_boss")
    end
    
    -- Add consumable usage if consumables are available
    if #self:extract_consumables() > 0 then
        table.insert(actions, "use_consumable")
    end
    
    -- Add joker reordering if available
    if self:is_joker_reorder_available() then
        table.insert(actions, "reorder_jokers")
    end
    
    return actions
end

function StateExtractor:is_joker_reorder_available()
    -- Check if joker reordering is currently available
    -- This would be true during the critical timing window after hand play
    -- Implementation depends on tracking game state timing
    return false -- Placeholder - needs implementation
end

return StateExtractor