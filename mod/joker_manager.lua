-- Joker management module for Balatro MCP mod
-- Handles critical joker reordering timing for Blueprint/Brainstorm strategies

local JokerManager = {}
JokerManager.__index = JokerManager

function JokerManager.new()
    local self = setmetatable({}, JokerManager)
    self.reorder_pending = false
    self.pending_order = nil
    self.post_hand_hook_active = false
    self.crash_diagnostics = nil -- Will be injected by main mod
    return self
end

function JokerManager:set_crash_diagnostics(crash_diagnostics)
    self.crash_diagnostics = crash_diagnostics
end

function JokerManager:safe_validate_joker(joker, joker_index, operation)
    if not joker then
        if self.crash_diagnostics then
            self.crash_diagnostics:log("ERROR: Joker at index " .. tostring(joker_index) .. " is nil during " .. operation)
        end
        return false
    end
    
    if not joker.config then
        if self.crash_diagnostics then
            self.crash_diagnostics:log("ERROR: Joker at index " .. tostring(joker_index) .. " has nil config during " .. operation)
            self.crash_diagnostics:validate_object_config(joker, "joker[" .. joker_index .. "]", operation)
        end
        return false
    end
    
    if not joker.config.center then
        if self.crash_diagnostics then
            self.crash_diagnostics:log("ERROR: Joker at index " .. tostring(joker_index) .. " has nil config.center during " .. operation)
        end
        return false
    end
    
    return true
end

function JokerManager:safe_get_joker_key(joker, joker_index, operation)
    if not self:safe_validate_joker(joker, joker_index, operation) then
        return nil
    end
    
    local key = joker.config.center.key
    if not key then
        if self.crash_diagnostics then
            self.crash_diagnostics:log("ERROR: Joker at index " .. tostring(joker_index) .. " has nil config.center.key during " .. operation)
        end
        return nil
    end
    
    return key
end

function JokerManager:reorder_jokers(new_order)
    -- Reorder jokers according to new_order array with crash diagnostics
    if not new_order or #new_order == 0 then
        return false, "No new order specified"
    end
    
    if not G or not G.jokers or not G.jokers.cards then
        if self.crash_diagnostics then
            self.crash_diagnostics:log("ERROR: G.jokers.cards not available for reordering")
        end
        return false, "No jokers available"
    end
    
    local current_jokers = G.jokers.cards
    local joker_count = #current_jokers
    
    -- CRASH FIX: Validate all jokers before reordering
    if self.crash_diagnostics then
        self.crash_diagnostics:log("PRE_REORDER: Validating " .. joker_count .. " jokers")
    end
    
    for i, joker in ipairs(current_jokers) do
        if not self:safe_validate_joker(joker, i, "reorder_jokers_pre_validation") then
            return false, "Joker " .. i .. " is corrupted, cannot safely reorder"
        end
    end
    
    -- Validate new order
    if #new_order ~= joker_count then
        return false, "New order length doesn't match joker count"
    end
    
    -- Validate indices
    for _, index in ipairs(new_order) do
        if index < 0 or index >= joker_count then
            return false, "Invalid joker index in new order: " .. index
        end
    end
    
    -- Check for duplicates
    local seen = {}
    for _, index in ipairs(new_order) do
        if seen[index] then
            return false, "Duplicate index in new order: " .. index
        end
        seen[index] = true
    end
    
    -- Create new joker order with additional validation
    local new_jokers = {}
    for i, old_index in ipairs(new_order) do
        local joker = current_jokers[old_index + 1] -- Lua 1-based indexing
        if not self:safe_validate_joker(joker, old_index + 1, "reorder_jokers_during_reorder") then
            return false, "Joker became corrupted during reordering"
        end
        new_jokers[i] = joker
    end
    
    -- Apply the new order
    G.jokers.cards = new_jokers
    
    -- Update positions
    self:update_joker_positions()
    
    if self.crash_diagnostics then
        self.crash_diagnostics:log("SUCCESS: Reordered jokers successfully")
    end
    print("BalatroMCP: Reordered jokers successfully")
    return true, nil
end

function JokerManager:update_joker_positions()
    if not G or not G.jokers or not G.jokers.cards then
        return
    end
    
    -- Use global CARD_W constant with fallback to G.CARD_W or default
    local card_width = _G.CARD_W or G.CARD_W or 71
    
    for i, joker in ipairs(G.jokers.cards) do
        if joker.T then
            joker.T.x = (i - 1) * card_width * 0.85
        end
    end
end

function JokerManager:schedule_post_hand_reorder(new_order)
    -- Schedule a joker reorder to happen after hand evaluation
    -- This is critical for Blueprint/Brainstorm strategies
    self.reorder_pending = true
    self.pending_order = new_order
    
    -- Set up post-hand hook if not already active
    if not self.post_hand_hook_active then
        self:setup_post_hand_hook()
    end
    
    print("BalatroMCP: Scheduled post-hand joker reorder")
end

function JokerManager:setup_post_hand_hook()
    -- Set up hook to execute after hand evaluation with crash diagnostics
    self.post_hand_hook_active = true
    
    -- Hook into the end of hand evaluation
    local original_eval_hand = G.FUNCS.evaluate_play or function() end
    
    -- Apply crash diagnostics protection if available
    if self.crash_diagnostics then
        G.FUNCS.evaluate_play = self.crash_diagnostics:create_safe_hook(
            function(...)
                self.crash_diagnostics:track_hook_chain("evaluate_play")
                self.crash_diagnostics:validate_game_state("evaluate_play")
                local result = original_eval_hand(...)
                
                -- Execute pending reorder after hand evaluation
                if self.reorder_pending and self.pending_order then
                    self:execute_pending_reorder()
                end
                
                return result
            end,
            "evaluate_play"
        )
        print("JokerManager: Applied crash diagnostics protection to evaluate_play")
    else
        -- Fallback without crash diagnostics
        G.FUNCS.evaluate_play = function(...)
            local result = original_eval_hand(...)
            
            -- Execute pending reorder after hand evaluation
            if self.reorder_pending and self.pending_order then
                self:execute_pending_reorder()
            end
            
            return result
        end
        print("JokerManager: WARNING - No crash diagnostics available for evaluate_play hook")
    end
end

function JokerManager:execute_pending_reorder()
    if not self.reorder_pending or not self.pending_order then
        return
    end
    
    print("BalatroMCP: Executing pending joker reorder")
    
    local success, error_message = self:reorder_jokers(self.pending_order)
    
    if success then
        print("BalatroMCP: Post-hand reorder completed successfully")
    else
        print("BalatroMCP: Post-hand reorder failed: " .. (error_message or "Unknown error"))
    end
    
    -- Clear pending state
    self.reorder_pending = false
    self.pending_order = nil
end

function JokerManager:get_joker_order()
    if not G or not G.jokers or not G.jokers.cards then
        return {}
    end
    
    local order = {}
    for i, joker in ipairs(G.jokers.cards) do
        -- Use joker's unique identifier or index
        order[i] = joker.unique_val or (i - 1)
    end
    
    return order
end

function JokerManager:find_joker_by_id(joker_id)
    if not G or not G.jokers or not G.jokers.cards then
        return nil, -1
    end
    
    for i, joker in ipairs(G.jokers.cards) do
        if joker.unique_val == joker_id then
            return joker, i - 1 -- Return 0-based index
        end
    end
    
    return nil, -1
end

function JokerManager:get_blueprint_brainstorm_optimization()
    -- Analyze current jokers and suggest optimal ordering for Blueprint/Brainstorm with crash safety
    if not G or not G.jokers or not G.jokers.cards then
        if self.crash_diagnostics then
            self.crash_diagnostics:log("ERROR: G.jokers.cards not available for optimization")
        end
        return {}
    end
    
    local jokers = G.jokers.cards
    local blueprint_indices = {}
    local brainstorm_indices = {}
    local other_indices = {}
    
    if self.crash_diagnostics then
        self.crash_diagnostics:log("OPTIMIZATION: Analyzing " .. #jokers .. " jokers for Blueprint/Brainstorm optimization")
    end
    
    -- Categorize jokers with safe config access
    for i, joker in ipairs(jokers) do
        local joker_key = self:safe_get_joker_key(joker, i, "get_blueprint_brainstorm_optimization")
        
        if joker_key == "j_blueprint" then
            table.insert(blueprint_indices, i - 1) -- 0-based index
            if self.crash_diagnostics then
                self.crash_diagnostics:log("OPTIMIZATION: Found Blueprint at index " .. (i - 1))
            end
        elseif joker_key == "j_brainstorm" then
            table.insert(brainstorm_indices, i - 1) -- 0-based index
            if self.crash_diagnostics then
                self.crash_diagnostics:log("OPTIMIZATION: Found Brainstorm at index " .. (i - 1))
            end
        elseif joker_key then
            table.insert(other_indices, i - 1) -- 0-based index
        else
            if self.crash_diagnostics then
                self.crash_diagnostics:log("WARNING: Joker at index " .. i .. " has no valid key, skipping from optimization")
            end
        end
    end
    
    -- Optimal order: high-value jokers first, then Blueprint/Brainstorm to copy them
    local optimal_order = {}
    
    -- Add high-value jokers first
    for _, index in ipairs(other_indices) do
        table.insert(optimal_order, index)
    end
    
    -- Add Blueprint and Brainstorm at the end to copy the valuable effects
    for _, index in ipairs(blueprint_indices) do
        table.insert(optimal_order, index)
    end
    
    for _, index in ipairs(brainstorm_indices) do
        table.insert(optimal_order, index)
    end
    
    if self.crash_diagnostics then
        self.crash_diagnostics:log("OPTIMIZATION: Generated order with " .. #optimal_order .. " jokers")
    end
    
    return optimal_order
end

function JokerManager:is_reorder_beneficial()
    local current_order = self:get_joker_order()
    local optimal_order = self:get_blueprint_brainstorm_optimization()
    
    -- Compare orders
    if #current_order ~= #optimal_order then
        return false
    end
    
    for i, current_index in ipairs(current_order) do
        if current_index ~= optimal_order[i] then
            return true -- Orders differ, reordering could be beneficial
        end
    end
    
    return false -- Orders are the same
end

function JokerManager:get_joker_info()
    -- Get detailed information about all jokers with crash safety
    if not G or not G.jokers or not G.jokers.cards then
        if self.crash_diagnostics then
            self.crash_diagnostics:log("ERROR: G.jokers.cards not available for get_joker_info")
        end
        return {}
    end
    
    local joker_info = {}
    
    if self.crash_diagnostics then
        self.crash_diagnostics:log("INFO: Extracting info for " .. #G.jokers.cards .. " jokers")
    end
    
    for i, joker in ipairs(G.jokers.cards) do
        local info = {
            index = i - 1, -- 0-based index
            id = joker and joker.unique_val or nil,
            key = nil,
            name = nil,
            rarity = nil,
            cost = joker and joker.sell_cost or 0,
            edition = joker and joker.edition and joker.edition.type or nil
        }
        
        -- Safely extract config-dependent fields
        if self:safe_validate_joker(joker, i, "get_joker_info") then
            info.key = joker.config.center.key
            info.name = joker.config.center.name
            info.rarity = joker.config.center.rarity
        else
            if self.crash_diagnostics then
                self.crash_diagnostics:log("WARNING: Joker " .. i .. " has corrupted config, using safe defaults")
            end
            info.key = "unknown"
            info.name = "Corrupted Joker"
            info.rarity = "unknown"
        end
        
        table.insert(joker_info, info)
    end
    
    if self.crash_diagnostics then
        self.crash_diagnostics:log("SUCCESS: Extracted info for " .. #joker_info .. " jokers")
    end
    
    return joker_info
end

return JokerManager