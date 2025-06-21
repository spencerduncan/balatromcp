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
    local log_msg = "BalatroMCP [" .. self.component_name .. "]: " .. message
    print(log_msg)
end

function StateExtractor:validate_g_object()
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
            -- Only log critical errors
            if extraction.name == "current_phase" or extraction.name == "money" then
                self:log("ERROR extracting " .. extraction.name .. ": " .. tostring(result))
            end
            state[extraction.name] = nil -- Ensure it's explicitly nil
        end
    end
    
    -- Only log if there are errors
    if #extraction_errors > 0 then
        self:log("STATE EXTRACTION: " .. #extraction_errors .. " errors")
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
    if not self:safe_check_path(G, {"STATE"}) then
        self:log("WARNING: G.STATE not accessible, returning default phase")
        return "hand_selection"
    end
    
    if not self:safe_check_path(G, {"STATES"}) then
        self:log("WARNING: G.STATES not accessible, returning default phase")
        return "hand_selection"
    end
    
    -- CRITICAL FIX: Force fresh access to global G object, don't cache reference
    local current_state = _G.G.STATE  -- Direct global access
    local states = _G.G.STATES       -- Direct global access
    
    -- Safe state comparison with fallback
    if current_state == self:safe_get_value(states, "SELECTING_HAND", nil) then
        return "hand_selection"
    elseif current_state == self:safe_get_value(states, "SHOP", nil) then
        return "shop"
    elseif current_state == self:safe_get_value(states, "BLIND_SELECT", nil) then
        return "blind_selection"
    elseif current_state == self:safe_get_value(states, "DRAW_TO_HAND", nil) then
        return "hand_selection"
    else
        return "hand_selection" -- Default
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
        else
            self:log("WARNING: Null joker found at position " .. i)
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
        else
            self:log("WARNING: Null consumable found at position " .. i)
        end
    end
    
    return consumables
end

function StateExtractor:extract_current_blind()
    -- Extract current blind information with CIRCULAR REFERENCE SAFE access
    if not self:safe_check_path(G, {"GAME", "blind"}) then
        return nil
    end
    
    local blind = G.GAME.blind
    return {
        name = self:safe_primitive_value(blind, "name", "Unknown"),
        blind_type = self:determine_blind_type_safe(blind),
        requirement = self:safe_primitive_value(blind, "chips", 0),
        reward = self:safe_primitive_value(blind, "dollars", 0),
        -- AVOID CIRCULAR REFERENCE: Don't extract complex config object
        properties = {}
    }
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
            else
                self:log("WARNING: Shop item at position " .. i .. " missing ability.set")
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
    
    -- Log extraction results for debugging with detailed collection info
    if #shop_contents > 0 then
        self:log("Extracted " .. #shop_contents .. " shop items")
        
        -- Debug log: Check which collections have items
        local jokers_count = (self:safe_check_path(G, {"shop_jokers", "cards"}) and #G.shop_jokers.cards) or 0
        local consumables_count = (self:safe_check_path(G, {"shop_consumables", "cards"}) and #G.shop_consumables.cards) or 0
        local boosters_count = (self:safe_check_path(G, {"shop_booster", "cards"}) and #G.shop_booster.cards) or 0
        local vouchers_count = (self:safe_check_path(G, {"shop_vouchers", "cards"}) and #G.shop_vouchers.cards) or 0
        
        self:log("Shop collection counts: jokers=" .. jokers_count ..
                ", consumables=" .. consumables_count ..
                ", boosters=" .. boosters_count ..
                ", vouchers=" .. vouchers_count)
    else
        self:log("WARNING: No shop items found in any shop arrays")
        
        -- Debug log: Check which collections exist when empty
        local collections_debug = {}
        if G then
            table.insert(collections_debug, "shop_jokers=" .. (G.shop_jokers and "exists" or "nil"))
            table.insert(collections_debug, "shop_consumables=" .. (G.shop_consumables and "exists" or "nil"))
            table.insert(collections_debug, "shop_booster=" .. (G.shop_booster and "exists" or "nil"))
            table.insert(collections_debug, "shop_vouchers=" .. (G.shop_vouchers and "exists" or "nil"))
        end
        
        if #collections_debug > 0 then
            self:log("Shop collections status: " .. table.concat(collections_debug, ", "))
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
        self:log("WARNING: Blind object is nil, returning default type")
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