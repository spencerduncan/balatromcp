-- State extraction module for Balatro MCP mod
-- Extracts game state information for the MCP server

local StateExtractor = {}
StateExtractor.__index = StateExtractor

function StateExtractor.new()
    local self = setmetatable({}, StateExtractor)
    self.component_name = "STATE_EXTRACTOR"
    
    -- Immediately test G object availability and structure
    self:validate_g_object()
    
    return self
end

function StateExtractor:validate_g_object()
    if not G then
        return false
    end
    
    -- Test critical G object properties
    local critical_properties = {
        "STATE", "STATES", "GAME", "hand", "jokers", "consumeables", "shop_jokers", "FUNCS"
    }
    
    local missing_properties = {}
    for _, prop in ipairs(critical_properties) do
        if G[prop] == nil then
            table.insert(missing_properties, prop)
        end
    end
    
    -- Test specific structures we rely on
    self:validate_game_object()
    self:validate_card_areas()
    self:validate_states()
    
    return #missing_properties == 0
end

function StateExtractor:validate_game_object()
    if not G or not G.GAME then
        return
    end
end

function StateExtractor:validate_card_areas()
    local areas = {
        {name = "hand", object = G.hand},
        {name = "jokers", object = G.jokers},
        {name = "consumeables", object = G.consumeables},
        {name = "shop_jokers", object = G.shop_jokers}
    }
    
    for _, area in ipairs(areas) do
        if area.object and area.object.cards and #area.object.cards > 0 then
            self:validate_card_structure(area.object.cards[1], area.name .. "[1]")
        end
    end
end

function StateExtractor:validate_card_structure(card, card_name)
    if not card then
        return
    end
end

function StateExtractor:validate_states()
    if not G.STATE or not G.STATES then
        return
    end
end

function StateExtractor:extract_current_state()
    local state = {}
    local extraction_errors = {}
    
    -- Extract each component with error handling (SILENT MODE)
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
            -- REMOVED: Individual success logging
        else
            table.insert(extraction_errors, extraction.name .. ": " .. tostring(result))
            state[extraction.name] = nil -- Ensure it's explicitly nil
        end
    end
    
    if #extraction_errors > 0 then
        state.extraction_errors = extraction_errors
    end
    
    return state
end

function StateExtractor:get_session_id()
    if not self.session_id then
        self.session_id = "session_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
    end
    return self.session_id
end

function StateExtractor:get_current_phase()
    -- Validate G object structure
    if not self:safe_check_path(G, {"STATE"}) then
        return "hand_selection"
    end
    
    if not self:safe_check_path(G, {"STATES"}) then
        return "hand_selection"
    end
    
    -- Use consistent direct access to G object
    local current_state = G.STATE
    local states = G.STATES
    
    -- Comprehensive state mapping using G.STATES constants
    -- Hand/Card Selection States
    if current_state == states.SELECTING_HAND then
        return "hand_selection"
    elseif current_state == states.DRAW_TO_HAND then
        return "drawing_cards"
    elseif current_state == states.HAND_PLAYED then
        return "hand_played"
    
    -- Shop and Purchase States
    elseif current_state == states.SHOP then
        return "shop"
    
    -- Blind Selection and Round States
    elseif current_state == states.BLIND_SELECT then
        return "blind_selection"
    elseif current_state == states.NEW_ROUND then
        return "new_round"
    elseif current_state == states.ROUND_EVAL then
        return "round_evaluation"
    
    -- Pack Opening States
    elseif current_state == states.STANDARD_PACK then
        return "pack_opening"
    elseif current_state == states.BUFFOON_PACK then
        return "pack_opening"
    elseif current_state == states.TAROT_PACK then
        return "pack_opening"
    elseif current_state == states.PLANET_PACK then
        return "pack_opening"
    elseif current_state == states.SPECTRAL_PACK then
        return "pack_opening"
    elseif current_state == states.SMODS_BOOSTER_OPENED then
        return "pack_opening"
    
    -- Consumable Usage States
    elseif current_state == states.PLAY_TAROT then
        return "using_consumable"
    
    -- Menu and Navigation States
    elseif current_state == states.MENU then
        return "menu"
    elseif current_state == states.SPLASH then
        return "splash"
    elseif current_state == states.TUTORIAL then
        return "tutorial"
    elseif current_state == states.DEMO_CTA then
        return "demo_prompt"
    
    -- Game End States
    elseif current_state == states.GAME_OVER then
        return "game_over"
    
    -- Special Game Modes
    elseif current_state == states.SANDBOX then
        return "sandbox"
    
    -- Fallback for unknown states
    else
        return "hand_selection" -- Safe default
    end
end

function StateExtractor:get_ante()
    local ante = self:safe_get_nested_value(G, {"GAME", "round_resets", "ante"}, 1)
    return ante
end

function StateExtractor:get_money()
    local money = self:safe_get_nested_value(G, {"GAME", "dollars"}, 0)
    return money
end

function StateExtractor:get_hands_remaining()
    if G and G.GAME and G.GAME.current_round and type(G.GAME.current_round.hands_left) == "number" then
        return G.GAME.current_round.hands_left
    end
    return 0
end

function StateExtractor:get_discards_remaining()
    if G and G.GAME and G.GAME.current_round and type(G.GAME.current_round.discards_left) == "number" then
        return G.GAME.current_round.discards_left
    end
    return 0
end

function StateExtractor:extract_hand_cards()
    -- Extract current hand cards with CIRCULAR REFERENCE SAFE access
    local hand_cards = {}
    
    if not self:safe_check_path(G, {"hand", "cards"}) then
        return hand_cards
    end
    
    for i, card in ipairs(G.hand.cards) do
        if card then
            -- SAFE EXTRACTION: Only extract primitive values, avoid object references
            local safe_card = {
                id = self:safe_primitive_value(card, "unique_val", "card_" .. i),
                rank = self:safe_primitive_nested_value(card, {"base", "value"}, "A"),
                suit = self:safe_primitive_nested_value(card, {"base", "suit"}, "Spades"),
                enhancement = self:get_card_enhancement_safe(card),
                edition = self:get_card_edition_safe(card),
                seal = self:get_card_seal_safe(card)
            }
            table.insert(hand_cards, safe_card)
        end
    end
    
    return hand_cards
end

function StateExtractor:extract_deck_cards()
    -- Extract current deck cards with CIRCULAR REFERENCE SAFE access
    local deck_cards = {}
    
    if not self:safe_check_path(G, {"playing_cards"}) then
        return deck_cards
    end
    
    for i, card in ipairs(G.playing_cards) do
        if card then
            -- SAFE EXTRACTION: Only extract primitive values, avoid object references
            local safe_card = {
                id = self:safe_primitive_value(card, "unique_val", "deck_card_" .. i),
                rank = self:safe_primitive_nested_value(card, {"base", "value"}, "A"),
                suit = self:safe_primitive_nested_value(card, {"base", "suit"}, "Spades"),
                enhancement = self:get_card_enhancement_safe(card),
                edition = self:get_card_edition_safe(card),
                seal = self:get_card_seal_safe(card)
            }
            table.insert(deck_cards, safe_card)
        end
    end
    
    return deck_cards
end

function StateExtractor:get_card_enhancement(card)
    if not card then
        return "none"
    end
    
    local ability_name = self:safe_get_nested_value(card, {"ability", "name"}, nil)
    if ability_name then
        local enhancement_map = {
            m_bonus = "bonus",
            m_mult = "mult",
            m_wild = "wild",
            m_glass = "glass",
            m_steel = "steel",
            m_stone = "stone",
            m_gold = "gold"
        }
        return enhancement_map[ability_name] or "none"
    end
    return "none"
end

function StateExtractor:get_card_edition(card)
    if not card then
        return "none"
    end
    
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
    if card.seal then
        return card.seal
    end
    return "none"
end

function StateExtractor:extract_jokers()
    -- Extract current jokers with CIRCULAR REFERENCE SAFE access
    local jokers = {}
    
    if not self:safe_check_path(G, {"jokers", "cards"}) then
        return jokers
    end
    
    for i, joker in ipairs(G.jokers.cards) do
        if joker then
            local safe_joker = {
                id = self:safe_primitive_value(joker, "unique_val", "joker_" .. i),
                name = self:safe_primitive_nested_value(joker, {"ability", "name"}, "Unknown"),
                position = i - 1, -- 0-based indexing
                properties = self:extract_joker_properties_safe(joker)
            }
            table.insert(jokers, safe_joker)
        end
    end
    
    return jokers
end

function StateExtractor:extract_joker_properties(joker)
    local properties = {}
    
    if not joker then
        return properties
    end
    
    properties.extra = self:safe_get_nested_value(joker, {"ability", "extra"}, {})
    properties.mult = self:safe_get_nested_value(joker, {"ability", "mult"}, 0)
    properties.chips = self:safe_get_nested_value(joker, {"ability", "t_chips"}, 0)
    
    return properties
end

function StateExtractor:extract_consumables()
    -- Extract consumable cards with CIRCULAR REFERENCE SAFE access
    local consumables = {}
    
    if not self:safe_check_path(G, {"consumeables", "cards"}) then
        return consumables
    end
    
    for i, consumable in ipairs(G.consumeables.cards) do
        if consumable then
            local safe_consumable = {
                id = self:safe_primitive_value(consumable, "unique_val", "consumable_" .. i),
                name = self:safe_primitive_nested_value(consumable, {"ability", "name"}, "Unknown"),
                card_type = self:safe_primitive_nested_value(consumable, {"ability", "set"}, "Tarot"),
                -- AVOID CIRCULAR REFERENCE: Don't extract complex properties object
                properties = {}
            }
            table.insert(consumables, safe_consumable)
        end
    end
    
    return consumables
end

function StateExtractor:extract_current_blind()
    -- Extract current blind information with CIRCULAR REFERENCE SAFE access
    local current_phase = self:get_current_phase()
    
    -- During blind selection phase, extract information from blind selection options
    if current_phase == "blind_selection" then
        return self:extract_blind_selection_info()
    end
    
    -- For other phases, extract from current blind
    if not self:safe_check_path(G, {"GAME", "blind"}) then
        return {
            name = "",
            blind_type = "small",
            requirement = 0,
            reward = 0,
            properties = {}
        }
    end
    
    local blind = G.GAME.blind
    return {
        name = self:safe_primitive_value(blind, "name", ""),
        blind_type = self:determine_blind_type_safe(blind),
        requirement = self:safe_primitive_value(blind, "chips", 0),
        reward = self:safe_primitive_value(blind, "dollars", 0),
        -- AVOID CIRCULAR REFERENCE: Don't extract complex config object
        properties = {}
    }
end

function StateExtractor:extract_blind_selection_info()
    -- Extract blind information during blind selection phase
    local blind_info = {
        name = "",
        blind_type = "small",
        requirement = 0,
        reward = 0,
        properties = {}
    }
    
    -- Try to determine which blind is being selected from game progression
    if self:safe_check_path(G, {"GAME", "blind_on_deck"}) then
        local blind_on_deck = G.GAME.blind_on_deck
        if blind_on_deck then
            blind_info.blind_type = string.lower(blind_on_deck)
            
            -- Try to get blind details from selection options
            if self:safe_check_path(G, {"blind_select_opts"}) then
                local blind_option = G.blind_select_opts[string.lower(blind_on_deck)]
                if blind_option and blind_option.config and blind_option.config.blind then
                    local blind_config = blind_option.config.blind
                    blind_info.name = self:safe_primitive_value(blind_config, "name", "")
                    blind_info.requirement = self:safe_primitive_value(blind_config, "chips", 0)
                    blind_info.reward = self:safe_primitive_value(blind_config, "dollars", 0)
                end
            end
        end
    else
        -- Fallback: determine from available blind options
        if self:safe_check_path(G, {"blind_select_opts"}) then
            -- If we have both small and big, we're likely selecting big blind
            if G.blind_select_opts["big"] and G.blind_select_opts["small"] then
                blind_info.blind_type = "big"
                
                local blind_option = G.blind_select_opts["big"]
                if blind_option and blind_option.config and blind_option.config.blind then
                    local blind_config = blind_option.config.blind
                    blind_info.name = self:safe_primitive_value(blind_config, "name", "Big Blind")
                    blind_info.requirement = self:safe_primitive_value(blind_config, "chips", 0)
                    blind_info.reward = self:safe_primitive_value(blind_config, "dollars", 0)
                end
            elseif G.blind_select_opts["small"] then
                blind_info.blind_type = "small"
                
                local blind_option = G.blind_select_opts["small"]
                if blind_option and blind_option.config and blind_option.config.blind then
                    local blind_config = blind_option.config.blind
                    blind_info.name = self:safe_primitive_value(blind_config, "name", "Small Blind")
                    blind_info.requirement = self:safe_primitive_value(blind_config, "chips", 0)
                    blind_info.reward = self:safe_primitive_value(blind_config, "dollars", 0)
                end
            elseif G.blind_select_opts["boss"] then
                blind_info.blind_type = "boss"
                
                local blind_option = G.blind_select_opts["boss"]
                if blind_option and blind_option.config and blind_option.config.blind then
                    local blind_config = blind_option.config.blind
                    blind_info.name = self:safe_primitive_value(blind_config, "name", "Boss Blind")
                    blind_info.requirement = self:safe_primitive_value(blind_config, "chips", 0)
                    blind_info.reward = self:safe_primitive_value(blind_config, "dollars", 0)
                end
            end
        end
    end
    
    return blind_info
end

function StateExtractor:determine_blind_type(blind)
    if not blind then
        return "small"
    end
    
    -- Check if it's a boss blind
    if self:safe_get_value(blind, "boss", false) then
        return "boss"
    end
    
    -- Check if it's a big blind by name
    local blind_name = self:safe_get_value(blind, "name", "")
    if type(blind_name) == "string" and string.find(blind_name, "Big") then
        return "big"
    end
    
    return "small"
end

function StateExtractor:extract_shop_contents()
    -- Extract shop contents with CIRCULAR REFERENCE SAFE access
    local shop_contents = {}
    
    -- Extract jokers from G.shop_jokers.cards with proper ability.set filtering
    if self:safe_check_path(G, {"shop_jokers", "cards"}) then
        for i, item in ipairs(G.shop_jokers.cards) do
            if item and item.ability and item.ability.set then
                local item_type = "unknown"
                local ability_set = self:safe_primitive_nested_value(item, {"ability", "set"}, "")
                
                -- Classify item based on ability.set
                if ability_set == "Joker" then
                    item_type = "joker"
                elseif ability_set == "Planet" then
                    item_type = "planet"
                elseif ability_set == "Tarot" then
                    item_type = "tarot"
                elseif ability_set == "Spectral" then
                    item_type = "spectral"
                elseif ability_set == "Booster" then
                    item_type = "booster"
                else
                    -- Use the raw ability.set value if unknown
                    item_type = string.lower(ability_set)
                end
                
                local safe_item = {
                    index = i - 1, -- 0-based indexing
                    item_type = item_type,
                    name = self:safe_primitive_nested_value(item, {"ability", "name"}, "Unknown"),
                    cost = self:safe_primitive_value(item, "cost", 0),
                    -- AVOID CIRCULAR REFERENCE: Don't extract complex properties object
                    properties = {}
                }
                table.insert(shop_contents, safe_item)
            end
        end
    end
    
    -- Extract consumables from G.shop_consumables.cards if it exists
    if self:safe_check_path(G, {"shop_consumables", "cards"}) then
        for i, item in ipairs(G.shop_consumables.cards) do
            if item and item.ability and item.ability.set then
                local ability_set = self:safe_primitive_nested_value(item, {"ability", "set"}, "")
                local item_type = string.lower(ability_set)
                
                local safe_item = {
                    index = (#shop_contents), -- Continue indexing from jokers
                    item_type = item_type,
                    name = self:safe_primitive_nested_value(item, {"ability", "name"}, "Unknown"),
                    cost = self:safe_primitive_value(item, "cost", 0),
                    properties = {}
                }
                table.insert(shop_contents, safe_item)
            end
        end
    end
    
    -- Extract boosters from G.shop_booster.cards if it exists
    if self:safe_check_path(G, {"shop_booster", "cards"}) then
        for i, item in ipairs(G.shop_booster.cards) do
            if item and item.ability and item.ability.set then
                local ability_set = self:safe_primitive_nested_value(item, {"ability", "set"}, "")
                local item_type = string.lower(ability_set)
                
                local safe_item = {
                    index = (#shop_contents), -- Continue indexing
                    item_type = item_type,
                    name = self:safe_primitive_nested_value(item, {"ability", "name"}, "Unknown"),
                    cost = self:safe_primitive_value(item, "cost", 0),
                    properties = {}
                }
                table.insert(shop_contents, safe_item)
            end
        end
    end
    
    -- Extract vouchers from G.shop_vouchers.cards if it exists
    if self:safe_check_path(G, {"shop_vouchers", "cards"}) then
        for i, item in ipairs(G.shop_vouchers.cards) do
            if item and item.ability and item.ability.set then
                local ability_set = self:safe_primitive_nested_value(item, {"ability", "set"}, "")
                local item_type = string.lower(ability_set)
                
                local safe_item = {
                    index = (#shop_contents), -- Continue indexing
                    item_type = item_type,
                    name = self:safe_primitive_nested_value(item, {"ability", "name"}, "Unknown"),
                    cost = self:safe_primitive_value(item, "cost", 0),
                    properties = {}
                }
                table.insert(shop_contents, safe_item)
            end
        end
    end
    
    
    return shop_contents
end

function StateExtractor:get_available_actions()
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
    return false -- Placeholder - needs implementation
end

-- Safe access utility functions
function StateExtractor:safe_check_path(root, path)
    if not root then
        return false
    end
    
    local current = root
    for _, key in ipairs(path) do
        if type(current) ~= "table" or current[key] == nil then
            return false
        end
        current = current[key]
    end
    return true
end

function StateExtractor:safe_get_value(table, key, default)
    if not table or type(table) ~= "table" then
        return default
    end
    
    if table[key] ~= nil then
        return table[key]
    end
    
    return default
end

function StateExtractor:safe_get_nested_value(root, path, default)
    if not root then
        return default
    end
    
    local current = root
    for _, key in ipairs(path) do
        if type(current) ~= "table" or current[key] == nil then
            return default
        end
        current = current[key]
    end
    return current
end

-- CIRCULAR REFERENCE SAFE utility functions
function StateExtractor:safe_primitive_value(table, key, default)
    -- Safely get a PRIMITIVE VALUE ONLY from a table with default fallback
    -- This prevents circular references by only returning primitive types
    if not table or type(table) ~= "table" then
        return default
    end
    
    local value = table[key]
    if value ~= nil then
        local value_type = type(value)
        if value_type == "string" or value_type == "number" or value_type == "boolean" then
            return value
        else
            -- Non-primitive type detected, return default to avoid circular reference
            return default
        end
    end
    
    return default
end

function StateExtractor:safe_primitive_nested_value(root, path, default)
    -- Safely get a nested PRIMITIVE VALUE ONLY from a table structure
    -- This prevents circular references by only returning primitive types
    if not root then
        return default
    end
    
    local current = root
    for _, key in ipairs(path) do
        if type(current) ~= "table" or current[key] == nil then
            return default
        end
        current = current[key]
    end
    
    -- Only return if it's a primitive type
    local value_type = type(current)
    if value_type == "string" or value_type == "number" or value_type == "boolean" then
        return current
    else
        -- Non-primitive type detected, return default to avoid circular reference
        return default
    end
end

-- SAFE card property extraction methods
function StateExtractor:get_card_enhancement_safe(card)
    -- Determine card enhancement with CIRCULAR REFERENCE SAFE access
    if not card then
        return "none"
    end
    
    local ability_name = self:safe_primitive_nested_value(card, {"ability", "name"}, nil)
    if ability_name and type(ability_name) == "string" then
        local enhancement_map = {
            m_bonus = "bonus",
            m_mult = "mult",
            m_wild = "wild",
            m_glass = "glass",
            m_steel = "steel",
            m_stone = "stone",
            m_gold = "gold"
        }
        return enhancement_map[ability_name] or "none"
    end
    return "none"
end

function StateExtractor:get_card_edition_safe(card)
    -- Determine card edition with CIRCULAR REFERENCE SAFE access
    if not card then
        return "none"
    end
    
    if card.edition and type(card.edition) == "table" then
        -- Check each edition type as primitive boolean
        if self:safe_primitive_value(card.edition, "foil", false) then
            return "foil"
        elseif self:safe_primitive_value(card.edition, "holo", false) then
            return "holographic"
        elseif self:safe_primitive_value(card.edition, "polychrome", false) then
            return "polychrome"
        elseif self:safe_primitive_value(card.edition, "negative", false) then
            return "negative"
        end
    end
    return "none"
end

function StateExtractor:get_card_seal_safe(card)
    -- Determine card seal with CIRCULAR REFERENCE SAFE access
    if not card then
        return "none"
    end
    
    local seal = self:safe_primitive_value(card, "seal", "none")
    return seal
end

function StateExtractor:extract_joker_properties_safe(joker)
    -- Extract joker-specific properties with CIRCULAR REFERENCE SAFE access
    local properties = {}
    
    if not joker then
        return properties
    end
    
    -- Only extract primitive values to avoid circular references
    properties.mult = self:safe_primitive_nested_value(joker, {"ability", "mult"}, 0)
    properties.chips = self:safe_primitive_nested_value(joker, {"ability", "t_chips"}, 0)
    
    -- AVOID extracting complex 'extra' object - too likely to have circular references
    
    return properties
end

function StateExtractor:determine_blind_type_safe(blind)
    -- Determine the type of blind with CIRCULAR REFERENCE SAFE access
    if not blind then
        return "small"
    end
    
    -- Check if it's a boss blind (primitive boolean check)
    if self:safe_primitive_value(blind, "boss", false) then
        return "boss"
    end
    
    -- Check if it's a big blind by name (primitive string check)
    local blind_name = self:safe_primitive_value(blind, "name", "")
    if type(blind_name) == "string" and string.find(blind_name, "Big") then
        return "big"
    end
    
    return "small"
end

return StateExtractor