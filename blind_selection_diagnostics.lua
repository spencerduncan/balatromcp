-- Comprehensive diagnostics for blind selection config nil issue
-- This will help us understand what's really happening with the config error

local BlindSelectionDiagnostics = {}
BlindSelectionDiagnostics.__index = BlindSelectionDiagnostics

function BlindSelectionDiagnostics.new()
    local self = setmetatable({}, BlindSelectionDiagnostics)
    return self
end

function BlindSelectionDiagnostics:log(message)
    -- Handle both Love2D and standalone environments
    local timestamp = 0
    if love and love.timer and love.timer.getTime then
        timestamp = love.timer.getTime()
    elseif os and os.clock then
        timestamp = os.clock()
    end
    
    local prefix = "BalatroMCP [BLIND_DIAG] " .. string.format("%.3f", timestamp) .. ": "
    if print then
        print(prefix .. message)
    end
end

function BlindSelectionDiagnostics:log_complete_game_structure()
    self:log("=== COMPLETE G.GAME STRUCTURE ANALYSIS ===")
    
    if not G then
        self:log("G is NIL - critical error")
        return
    end
    
    if not G.GAME then
        self:log("G.GAME is NIL - critical error")
        return
    end
    
    self:log("G.GAME exists, analyzing structure...")
    
    -- Log all properties of G.GAME
    local game_props = {}
    for key, value in pairs(G.GAME) do
        local value_type = type(value)
        local value_desc = tostring(value)
        if value_type == "table" then
            local table_size = 0
            for _ in pairs(value) do table_size = table_size + 1 end
            value_desc = "table[" .. table_size .. "]"
        end
        game_props[key] = value_type .. ":" .. value_desc
    end
    
    -- Sort for consistent output
    local sorted_keys = {}
    for key in pairs(game_props) do
        table.insert(sorted_keys, key)
    end
    table.sort(sorted_keys)
    
    for _, key in ipairs(sorted_keys) do
        local is_config = (key == "config") and " *** CONFIG FIELD ***" or ""
        self:log("G.GAME." .. key .. " = " .. game_props[key] .. is_config)
    end
    
    -- Special analysis of config field if it exists
    if G.GAME.config then
        self:log("=== G.GAME.config DETAILED ANALYSIS ===")
        self:log("G.GAME.config type: " .. type(G.GAME.config))
        
        if type(G.GAME.config) == "table" then
            local config_size = 0
            for key, value in pairs(G.GAME.config) do
                config_size = config_size + 1
                self:log("G.GAME.config." .. key .. " = " .. type(value) .. ":" .. tostring(value))
            end
            self:log("G.GAME.config has " .. config_size .. " properties")
        end
    else
        self:log("G.GAME.config is NIL - this is the source of our timeout!")
    end
end

function BlindSelectionDiagnostics:log_blind_objects_structure()
    self:log("=== BLIND OBJECTS STRUCTURE ANALYSIS ===")
    
    -- Check all blind-related objects
    local blind_objects = {
        {"G.GAME.blind", G.GAME and G.GAME.blind},
        {"G.GAME.current_blind", G.GAME and G.GAME.current_blind},
        {"G.blind_select", G.blind_select},
        {"G.GAME.round_resets", G.GAME and G.GAME.round_resets},
        {"G.GAME.current_round", G.GAME and G.GAME.current_round},
    }
    
    for _, obj_info in ipairs(blind_objects) do
        local name, obj = obj_info[1], obj_info[2]
        
        if not obj then
            self:log(name .. " is NIL")
        else
            self:log(name .. " exists (type: " .. type(obj) .. ")")
            
            if type(obj) == "table" then
                -- Check if it has config
                if obj.config ~= nil then
                    self:log(name .. ".config exists (type: " .. type(obj.config) .. ")")
                else
                    self:log(name .. ".config is NIL")
                end
                
                -- Log a few key properties
                local key_count = 0
                for key, value in pairs(obj) do
                    key_count = key_count + 1
                    if key_count <= 5 then  -- Only log first 5 properties
                        self:log(name .. "." .. key .. " = " .. type(value) .. ":" .. tostring(value))
                    end
                end
                if key_count > 5 then
                    self:log(name .. " has " .. (key_count - 5) .. " more properties...")
                end
            end
        end
    end
end

function BlindSelectionDiagnostics:analyze_select_blind_function()
    self:log("=== SELECT BLIND FUNCTION ANALYSIS ===")
    
    if not G.FUNCS then
        self:log("G.FUNCS is NIL - critical error")
        return
    end
    
    if not G.FUNCS.select_blind then
        self:log("G.FUNCS.select_blind is NIL - function not available")
        return
    end
    
    self:log("G.FUNCS.select_blind exists")
    self:log("G.FUNCS.select_blind type: " .. type(G.FUNCS.select_blind))
    
    -- Try to get function info (if possible)
    if debug and debug.getinfo then
        local success, func_info = pcall(debug.getinfo, G.FUNCS.select_blind)
        if success and func_info then
            self:log("Function source: " .. (func_info.source or "unknown"))
            self:log("Function line: " .. (func_info.linedefined or "unknown"))
        else
            self:log("Function debug info not available")
        end
    else
        self:log("Debug module not available")
    end
end

function BlindSelectionDiagnostics:test_blind_selection_arguments()
    self:log("=== TESTING BLIND SELECTION ARGUMENT PATTERNS ===")
    
    local blind_type = "small"  -- Test with small blind
    
    -- Test different argument patterns to see what works
    local test_patterns = {
        {name = "direct_string", args = {blind_type}},
        {name = "type_table", args = {{type = blind_type}}},
        {name = "config_table", args = {{config = {blind = {type = blind_type}}}}},
        {name = "button_like", args = {{config = {id = blind_type}}}},
        {name = "complex_button", args = {{config = {blind = blind_type, id = blind_type}}}},
    }
    
    for _, pattern in ipairs(test_patterns) do
        self:log("Testing pattern: " .. pattern.name)
        
        -- Log what we're about to pass
        local args_desc = "args: "
        for i, arg in ipairs(pattern.args) do
            if type(arg) == "table" then
                args_desc = args_desc .. "table[" .. self:table_size(arg) .. "] "
            else
                args_desc = args_desc .. type(arg) .. ":" .. tostring(arg) .. " "
            end
        end
        self:log(args_desc)
        
        -- Test the call (but don't actually execute - just validate structure)
        if pattern.args[1] and type(pattern.args[1]) == "table" then
            local arg_table = pattern.args[1]
            if arg_table.config then
                self:log("Argument has config field (type: " .. type(arg_table.config) .. ")")
                if type(arg_table.config) == "table" then
                    for key, value in pairs(arg_table.config) do
                        self:log("Argument.config." .. key .. " = " .. type(value) .. ":" .. tostring(value))
                    end
                end
            else
                self:log("Argument has NO config field")
            end
        end
    end
end

function BlindSelectionDiagnostics:table_size(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

function BlindSelectionDiagnostics:investigate_button_callbacks_error()
    self:log("=== INVESTIGATING BUTTON CALLBACKS ERROR ===")
    
    -- The error happens at functions/button_callbacks.lua:2583
    -- Let's see if we can understand the context
    
    -- Check if we can access the button callbacks
    if G.FUNCS then
        local func_count = 0
        for name, func in pairs(G.FUNCS) do
            func_count = func_count + 1
        end
        self:log("G.FUNCS has " .. func_count .. " functions")
        
        -- Look for blind-related functions
        local blind_funcs = {}
        for name, func in pairs(G.FUNCS) do
            if string.find(string.lower(name), "blind") then
                table.insert(blind_funcs, name)
            end
        end
        
        if #blind_funcs > 0 then
            self:log("Blind-related functions: " .. table.concat(blind_funcs, ", "))
        else
            self:log("No blind-related functions found in G.FUNCS")
        end
    end
    
    -- Check current game state context
    self:log("Current context when error occurs:")
    self:log("G.STATE = " .. tostring(G and G.STATE or "NIL"))
    if G and G.STATES then
        for name, value in pairs(G.STATES) do
            local current = (G.STATE == value) and " <- CURRENT" or ""
            self:log("G.STATES." .. name .. " = " .. tostring(value) .. current)
        end
    end
end

function BlindSelectionDiagnostics:run_complete_diagnosis()
    self:log("=== STARTING COMPLETE BLIND SELECTION DIAGNOSIS ===")
    
    self:log_complete_game_structure()
    self:log_blind_objects_structure()
    self:analyze_select_blind_function()
    self:test_blind_selection_arguments()
    self:investigate_button_callbacks_error()
    
    self:log("=== DIAGNOSIS COMPLETE ===")
    
    -- Summary of findings
    self:log("SUMMARY:")
    if G and G.GAME then
        local has_config = G.GAME.config ~= nil
        self:log("- G.GAME.config exists: " .. tostring(has_config))
        
        if not has_config then
            self:log("- HYPOTHESIS: G.GAME.config is supposed to be nil during blind selection")
            self:log("- HYPOTHESIS: Error is about argument object's config, not G.GAME.config")
        end
    end
    
    local has_select_blind = G and G.FUNCS and G.FUNCS.select_blind
    self:log("- G.FUNCS.select_blind available: " .. tostring(has_select_blind))
    
    self:log("RECOMMENDED NEXT STEPS:")
    self:log("1. Stop waiting for G.GAME.config (it may never initialize)")
    self:log("2. Focus on constructing proper button argument object")
    self:log("3. Test argument patterns with actual blind selection calls")
end

return BlindSelectionDiagnostics