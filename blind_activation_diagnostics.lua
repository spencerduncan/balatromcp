-- Diagnostic module for blind activation sequence issues
-- Focuses on what happens AFTER select_blind succeeds

local BlindActivationDiagnostics = {}
BlindActivationDiagnostics.__index = BlindActivationDiagnostics

function BlindActivationDiagnostics.new()
    local self = setmetatable({}, BlindActivationDiagnostics)
    return self
end

function BlindActivationDiagnostics:log(message)
    local timestamp = 0
    if love and love.timer and love.timer.getTime then
        timestamp = love.timer.getTime()
    elseif os and os.clock then
        timestamp = os.clock()
    end
    
    local prefix = "BalatroMCP [BLIND_ACT] " .. string.format("%.3f", timestamp) .. ": "
    if print then
        print(prefix .. message)
    end
end

function BlindActivationDiagnostics:diagnose_blind_activation_state()
    self:log("=== BLIND ACTIVATION STATE DIAGNOSIS ===")
    
    -- Check the current blind object in detail
    self:log("--- CURRENT BLIND DETAILED ANALYSIS ---")
    if G and G.GAME and G.GAME.blind then
        local blind = G.GAME.blind
        
        -- Log key properties that should be set during activation
        self:log("Blind name: " .. tostring(blind.name))
        self:log("Blind chips (requirement): " .. tostring(blind.chips))
        self:log("Blind dollars (reward): " .. tostring(blind.dollars))
        self:log("Blind mult: " .. tostring(blind.mult))
        self:log("Blind boss status: " .. tostring(blind.boss))
        
        -- Check blind config in detail
        if blind.config then
            self:log("--- BLIND CONFIG ANALYSIS ---")
            self:log("Config type: " .. type(blind.config))
            
            -- Look for initialization-related config values
            local important_config_keys = {"blind", "type", "id", "chips", "dollars", "boss"}
            for _, key in ipairs(important_config_keys) do
                if blind.config[key] ~= nil then
                    self:log("Config." .. key .. " = " .. tostring(blind.config[key]) .. " (type: " .. type(blind.config[key]) .. ")")
                else
                    self:log("Config." .. key .. " is NIL")
                end
            end
        else
            self:log("Blind config is nil - this could be the problem!")
        end
        
        -- Check if blind has proper initialization
        if blind.set_blind then
            self:log("Blind has set_blind method")
        else
            self:log("ERROR: Blind missing set_blind method")
        end
        
        if blind.defeat then
            self:log("Blind has defeat method")  
        else
            self:log("ERROR: Blind missing defeat method")
        end
    else
        self:log("No current blind object found")
    end
    
    -- Check blind_on_deck vs active blind discrepancy  
    self:log("--- BLIND QUEUE VS ACTIVE ANALYSIS ---")
    if G and G.GAME then
        self:log("blind_on_deck: " .. tostring(G.GAME.blind_on_deck))
        
        -- Check if there's a mismatch between queued and active
        if G.GAME.blind and G.GAME.blind_on_deck then
            local active_name = tostring(G.GAME.blind.name or "nil")
            local queued_name = tostring(G.GAME.blind_on_deck)
            self:log("Active blind name: " .. active_name)
            self:log("Queued blind name: " .. queued_name)
            
            if active_name ~= queued_name then
                self:log("MISMATCH: Active blind (" .. active_name .. ") != Queued blind (" .. queued_name .. ")")
            else
                self:log("Match: Active and queued blind names are consistent")
            end
        end
    end
    
    -- Check round state for blind activation
    self:log("--- ROUND STATE FOR BLIND ACTIVATION ---")
    if G and G.GAME and G.GAME.current_round then
        local round = G.GAME.current_round
        self:log("hands_left: " .. tostring(round.hands_left))
        self:log("discards_left: " .. tostring(round.discards_left))
        
        -- Check if round was properly initialized for this blind
        if round.hands_left == 0 or round.discards_left == 0 then
            self:log("WARNING: Round may not be properly initialized (zero hands/discards)")
        end
    end
    
    -- Check for blind selection UI state
    self:log("--- BLIND SELECTION UI STATE ---")
    if G.blind_select then
        self:log("G.blind_select exists")
        if G.blind_select.children then
            self:log("G.blind_select has " .. #G.blind_select.children .. " children")
            
            -- Look for blind selection buttons
            for i, child in ipairs(G.blind_select.children) do
                if child and child.config and child.config.blind then
                    local blind_info = child.config.blind
                    self:log("Blind option " .. i .. ": " .. tostring(blind_info.name or "nil") .. " (chips: " .. tostring(blind_info.chips or "nil") .. ")")
                end
            end
        end
    end
    
    self:log("=== ACTIVATION DIAGNOSIS COMPLETE ===")
end

function BlindActivationDiagnostics:check_blind_database()
    self:log("=== BLIND DATABASE CHECK ===")
    
    -- Check if the blind definitions exist in the game database
    if G and G.P_BLINDS then
        self:log("G.P_BLINDS exists with " .. self:table_size(G.P_BLINDS) .. " blind definitions")
        
        -- Check small blind definition
        if G.P_BLINDS.bl_small then
            local small_blind = G.P_BLINDS.bl_small
            self:log("Small blind definition found:")
            self:log("  name: " .. tostring(small_blind.name))
            self:log("  mult: " .. tostring(small_blind.mult))
            if small_blind.dollars then
                self:log("  dollars: " .. tostring(small_blind.dollars))
            end
            if small_blind.ante_scaling then
                self:log("  ante_scaling: " .. tostring(small_blind.ante_scaling))
            end
        else
            self:log("ERROR: Small blind definition not found in G.P_BLINDS")
        end
    else
        self:log("ERROR: G.P_BLINDS not available")
    end
end

function BlindActivationDiagnostics:table_size(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

return BlindActivationDiagnostics