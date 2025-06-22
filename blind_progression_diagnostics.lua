-- Diagnostic module for blind progression issues
-- Specifically for investigating why blinds don't advance properly

local BlindProgressionDiagnostics = {}
BlindProgressionDiagnostics.__index = BlindProgressionDiagnostics

function BlindProgressionDiagnostics.new()
    local self = setmetatable({}, BlindProgressionDiagnostics)
    return self
end

function BlindProgressionDiagnostics:log(message)
    local timestamp = 0
    if love and love.timer and love.timer.getTime then
        timestamp = love.timer.getTime()
    elseif os and os.clock then
        timestamp = os.clock()
    end
    
    local prefix = "BalatroMCP [BLIND_PROG] " .. string.format("%.3f", timestamp) .. ": "
    if print then
        print(prefix .. message)
    end
end

function BlindProgressionDiagnostics:diagnose_blind_state()
    self:log("=== BLIND PROGRESSION STATE DIAGNOSIS ===")
    
    -- Check current blind information
    self:log("--- CURRENT BLIND ANALYSIS ---")
    if G and G.GAME and G.GAME.blind then
        local blind = G.GAME.blind
        self:log("G.GAME.blind exists")
        self:log("Blind name: " .. tostring(blind.name or "nil"))
        self:log("Blind chips requirement: " .. tostring(blind.chips or "nil"))
        self:log("Blind dollars reward: " .. tostring(blind.dollars or "nil"))
        self:log("Blind boss status: " .. tostring(blind.boss or "nil"))
        
        -- Check if blind has config
        if blind.config then
            self:log("Blind.config exists (type: " .. type(blind.config) .. ")")
            for key, value in pairs(blind.config) do
                self:log("Blind.config." .. key .. " = " .. tostring(value))
            end
        else
            self:log("Blind.config is nil")
        end
        
        -- Check blind type indicators
        local blind_type = "unknown"
        if blind.boss then
            blind_type = "boss"
        elseif blind.name and string.find(tostring(blind.name), "Big") then
            blind_type = "big"
        else
            blind_type = "small"
        end
        self:log("Detected blind type: " .. blind_type)
    else
        self:log("G.GAME.blind is nil or inaccessible")
    end
    
    -- Check round progression information
    self:log("--- ROUND PROGRESSION ANALYSIS ---")
    if G and G.GAME then
        if G.GAME.current_round then
            self:log("G.GAME.current_round exists")
            self:log("Hands left: " .. tostring(G.GAME.current_round.hands_left or "nil"))
            self:log("Discards left: " .. tostring(G.GAME.current_round.discards_left or "nil"))
            
            -- Check other round properties
            for key, value in pairs(G.GAME.current_round) do
                if key ~= "hands_left" and key ~= "discards_left" then
                    self:log("G.GAME.current_round." .. key .. " = " .. tostring(value))
                end
            end
        else
            self:log("G.GAME.current_round is nil")
        end
        
        if G.GAME.round_resets then
            self:log("G.GAME.round_resets exists")
            self:log("Ante: " .. tostring(G.GAME.round_resets.ante or "nil"))
            self:log("Blind ante: " .. tostring(G.GAME.round_resets.blind_ante or "nil"))
            
            -- Check other round_resets properties
            for key, value in pairs(G.GAME.round_resets) do
                if key ~= "ante" and key ~= "blind_ante" then
                    self:log("G.GAME.round_resets." .. key .. " = " .. tostring(value))
                end
            end
        else
            self:log("G.GAME.round_resets is nil")
        end
        
        -- Check general game progression
        self:log("G.GAME.dollars: " .. tostring(G.GAME.dollars or "nil"))
        self:log("G.GAME.hands: " .. tostring(G.GAME.hands or "nil"))
        self:log("G.GAME.discards: " .. tostring(G.GAME.discards or "nil"))
    end
    
    -- Check current game state
    self:log("--- GAME STATE ANALYSIS ---")
    if G and G.STATE and G.STATES then
        local current_state_name = "UNKNOWN"
        for name, value in pairs(G.STATES) do
            if value == G.STATE then
                current_state_name = name
                break
            end
        end
        self:log("Current state: " .. current_state_name .. " (" .. tostring(G.STATE) .. ")")
    end
    
    -- Check blind selection objects
    self:log("--- BLIND SELECTION OBJECTS ---")
    if G.blind_select then
        self:log("G.blind_select exists")
        -- Try to get blind options
        if G.blind_select.children then
            self:log("G.blind_select has " .. #G.blind_select.children .. " children")
        end
    else
        self:log("G.blind_select is nil")
    end
    
    self:log("=== DIAGNOSIS COMPLETE ===")
end

function BlindProgressionDiagnostics:log_hand_result_processing()
    self:log("=== HAND RESULT PROCESSING ANALYSIS ===")
    
    -- Check if there are any pending hand results or scoring
    if G and G.hand_text_area then
        self:log("G.hand_text_area exists")
    end
    
    if G and G.GAME and G.GAME.current_round then
        local round = G.GAME.current_round
        if round.current_hand then
            self:log("Current hand info exists")
            if round.current_hand.chips then
                self:log("Hand chips: " .. tostring(round.current_hand.chips))
            end
            if round.current_hand.mult then
                self:log("Hand mult: " .. tostring(round.current_hand.mult))
            end
        end
    end
end

return BlindProgressionDiagnostics