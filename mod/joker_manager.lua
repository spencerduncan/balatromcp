-- Joker management module for Balatro MCP mod
-- Handles critical joker reordering timing for Blueprint/Brainstorm strategies

local JokerManager = {}
JokerManager.__index = JokerManager

function JokerManager.new()
    local self = setmetatable({}, JokerManager)
    self.reorder_pending = false
    self.pending_order = nil
    self.post_hand_hook_active = false
    return self
end

function JokerManager:reorder_jokers(new_order)
    -- Reorder jokers according to new_order array
    if not new_order or #new_order == 0 then
        return false, "No new order specified"
    end
    
    if not G or not G.jokers or not G.jokers.cards then
        return false, "No jokers available"
    end
    
    local current_jokers = G.jokers.cards
    local joker_count = #current_jokers
    
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
    
    -- Create new joker order
    local new_jokers = {}
    for i, old_index in ipairs(new_order) do
        new_jokers[i] = current_jokers[old_index + 1] -- Lua 1-based indexing
    end
    
    -- Apply the new order
    G.jokers.cards = new_jokers
    
    -- Update positions
    self:update_joker_positions()
    
    print("BalatroMCP: Reordered jokers successfully")
    return true, nil
end

function JokerManager:update_joker_positions()
    -- Update visual positions of jokers after reordering
    if not G or not G.jokers or not G.jokers.cards then
        return
    end
    
    for i, joker in ipairs(G.jokers.cards) do
        if joker.T then
            joker.T.x = (i - 1) * G.CARD_W * 0.85
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
    -- Set up hook to execute after hand evaluation
    self.post_hand_hook_active = true
    
    -- Hook into the end of hand evaluation
    local original_eval_hand = G.FUNCS.evaluate_play or function() end
    
    G.FUNCS.evaluate_play = function(...)
        local result = original_eval_hand(...)
        
        -- Execute pending reorder after hand evaluation
        if self.reorder_pending and self.pending_order then
            self:execute_pending_reorder()
        end
        
        return result
    end
end

function JokerManager:execute_pending_reorder()
    -- Execute the pending joker reorder
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
    -- Get current joker order as array of indices
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
    -- Find joker by its unique ID
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
    -- Analyze current jokers and suggest optimal ordering for Blueprint/Brainstorm
    if not G or not G.jokers or not G.jokers.cards then
        return {}
    end
    
    local jokers = G.jokers.cards
    local blueprint_indices = {}
    local brainstorm_indices = {}
    local other_indices = {}
    
    -- Categorize jokers
    for i, joker in ipairs(jokers) do
        local joker_key = joker.config and joker.config.center and joker.config.center.key
        if joker_key == "j_blueprint" then
            table.insert(blueprint_indices, i - 1) -- 0-based index
        elseif joker_key == "j_brainstorm" then
            table.insert(brainstorm_indices, i - 1) -- 0-based index
        else
            table.insert(other_indices, i - 1) -- 0-based index
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
    
    return optimal_order
end

function JokerManager:is_reorder_beneficial()
    -- Determine if reordering would be beneficial
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
    -- Get detailed information about all jokers
    if not G or not G.jokers or not G.jokers.cards then
        return {}
    end
    
    local joker_info = {}
    
    for i, joker in ipairs(G.jokers.cards) do
        local info = {
            index = i - 1, -- 0-based index
            id = joker.unique_val,
            key = joker.config and joker.config.center and joker.config.center.key,
            name = joker.config and joker.config.center and joker.config.center.name,
            rarity = joker.config and joker.config.center and joker.config.center.rarity,
            cost = joker.sell_cost or 0,
            edition = joker.edition and joker.edition.type
        }
        
        table.insert(joker_info, info)
    end
    
    return joker_info
end

return JokerManager