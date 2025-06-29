-- Per-ante boss reroll usage tracking for Director's Cut voucher limitations
-- Tracks reroll usage per ante with automatic reset logic

local RerollTracker = {}
RerollTracker.__index = RerollTracker

function RerollTracker.new()
    local self = setmetatable({}, RerollTracker)
    return self
end

-- Initialize reroll tracking structure in game state
function RerollTracker:initialize_tracking()
    if not G or not G.GAME then
        print("BalatroMCP: Warning - Cannot initialize reroll tracking, G.GAME not available")
        return false
    end
    
    if not G.GAME.balatromcp_reroll_tracking then
        G.GAME.balatromcp_reroll_tracking = {}
        print("BalatroMCP: Initialized reroll tracking structure")
    end
    
    return true
end

-- Increment reroll usage for the current ante
function RerollTracker:increment_reroll_usage(current_ante)
    if not self:initialize_tracking() then
        return false, "Failed to initialize tracking"
    end
    
    if not current_ante or current_ante < 1 then
        return false, "Invalid ante number: " .. tostring(current_ante)
    end
    
    local ante_key = tostring(current_ante)
    local current_count = G.GAME.balatromcp_reroll_tracking[ante_key] or 0
    G.GAME.balatromcp_reroll_tracking[ante_key] = current_count + 1
    
    local new_count = G.GAME.balatromcp_reroll_tracking[ante_key]
    print("BalatroMCP: Boss reroll used. Count for ante " .. current_ante .. ": " .. new_count)
    
    -- Optional: Cleanup old ante data to prevent memory bloat
    self:cleanup_old_antes(current_ante)
    
    return true, "Reroll usage incremented for ante " .. current_ante
end

-- Get reroll usage count for a specific ante
function RerollTracker:get_reroll_count(current_ante)
    if not current_ante or current_ante < 1 then
        return 0
    end
    
    if not G or not G.GAME or not G.GAME.balatromcp_reroll_tracking then
        return 0
    end
    
    local ante_key = tostring(current_ante)
    return G.GAME.balatromcp_reroll_tracking[ante_key] or 0
end

-- Check if reroll limit has been reached for the current ante
function RerollTracker:is_reroll_limit_reached(current_ante, limit)
    local current_count = self:get_reroll_count(current_ante)
    return current_count >= (limit or 1)
end

-- Get reroll usage for multiple antes (for debugging/monitoring)
function RerollTracker:get_reroll_history(max_antes)
    if not G or not G.GAME or not G.GAME.balatromcp_reroll_tracking then
        return {}
    end
    
    local history = {}
    local current_ante = self:get_current_ante()
    local start_ante = math.max(1, current_ante - (max_antes or 5))
    
    for ante = start_ante, current_ante do
        local ante_key = tostring(ante)
        history[ante] = G.GAME.balatromcp_reroll_tracking[ante_key] or 0
    end
    
    return history
end

-- Get current ante from game state
function RerollTracker:get_current_ante()
    if not G or not G.GAME then
        return 1
    end
    
    if G.GAME.round_resets and G.GAME.round_resets.ante then
        return G.GAME.round_resets.ante
    end
    
    return 1
end

-- Cleanup tracking data for old antes to prevent memory bloat
function RerollTracker:cleanup_old_antes(current_ante, keep_count)
    if not G or not G.GAME or not G.GAME.balatromcp_reroll_tracking then
        return
    end
    
    local cleanup_threshold = current_ante - (keep_count or 5)
    if cleanup_threshold <= 0 then
        return -- Don't cleanup if we haven't progressed far enough
    end
    
    local cleaned_count = 0
    for ante_key, _ in pairs(G.GAME.balatromcp_reroll_tracking) do
        local ante_num = tonumber(ante_key)
        if ante_num and ante_num < cleanup_threshold then
            G.GAME.balatromcp_reroll_tracking[ante_key] = nil
            cleaned_count = cleaned_count + 1
        end
    end
    
    if cleaned_count > 0 then
        print("BalatroMCP: Cleaned up reroll tracking for " .. cleaned_count .. " old antes")
    end
end

-- Reset tracking for a specific ante (useful for testing or debugging)
function RerollTracker:reset_ante_tracking(ante)
    if not self:initialize_tracking() then
        return false, "Failed to initialize tracking"
    end
    
    if not ante or ante < 1 then
        return false, "Invalid ante number: " .. tostring(ante)
    end
    
    local ante_key = tostring(ante)
    local old_count = G.GAME.balatromcp_reroll_tracking[ante_key] or 0
    G.GAME.balatromcp_reroll_tracking[ante_key] = 0
    
    print("BalatroMCP: Reset reroll tracking for ante " .. ante .. " (was: " .. old_count .. ")")
    return true, "Ante tracking reset"
end

-- Clear all tracking data (useful for testing or fresh starts)
function RerollTracker:clear_all_tracking()
    if not G or not G.GAME then
        return false, "G.GAME not available"
    end
    
    G.GAME.balatromcp_reroll_tracking = {}
    print("BalatroMCP: Cleared all reroll tracking data")
    return true, "All tracking data cleared"
end

-- Get summary of tracking state for debugging
function RerollTracker:get_tracking_summary()
    local summary = {
        current_ante = self:get_current_ante(),
        tracking_initialized = G and G.GAME and G.GAME.balatromcp_reroll_tracking ~= nil,
        total_antes_tracked = 0,
        current_ante_usage = 0
    }
    
    if summary.tracking_initialized then
        for ante_key, count in pairs(G.GAME.balatromcp_reroll_tracking) do
            summary.total_antes_tracked = summary.total_antes_tracked + 1
        end
        summary.current_ante_usage = self:get_reroll_count(summary.current_ante)
    end
    
    return summary
end

return RerollTracker