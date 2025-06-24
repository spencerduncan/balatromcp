-- Debug logging module for Balatro MCP integration testing
-- Provides comprehensive logging to diagnose integration issues

local DebugLogger = {}
DebugLogger.__index = DebugLogger

function DebugLogger.new(log_file_path, base_path)
    local self = setmetatable({}, DebugLogger)
    self.base_path = base_path or "./"
    
    -- Handle log file path based on base path
    if not log_file_path then
        if self.base_path == "." then
            self.log_file = "debug.log"
        else
            self.log_file = self.base_path .. "/debug.log"
        end
    else
        self.log_file = log_file_path
    end
    
    self.log_level = "DEBUG" -- DEBUG, INFO, WARN, ERROR
    self.session_id = "session_" .. tostring(os.time())
    
    -- Ensure log directory exists (only for subdirectories)
    if love and love.filesystem and self.base_path ~= "." then
        love.filesystem.createDirectory(self.base_path)
    end
    
    self:log("INFO", "Debug logger initialized for session: " .. self.session_id .. " (path: " .. self.base_path .. ")")
    return self
end

function DebugLogger:log(level, message, component)
    component = component or "MAIN"
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_entry = string.format("[%s] [%s] [%s] %s", timestamp, level, component, message)
    
    -- Always print to console
    print("BalatroMCP Debug: " .. log_entry)
    
    -- Write to file if possible
    if love and love.filesystem then
        local success, err = pcall(function()
            local existing_content = ""
            if love.filesystem.getInfo(self.log_file) then
                existing_content = love.filesystem.read(self.log_file) or ""
            end
            love.filesystem.write(self.log_file, existing_content .. log_entry .. "\n")
        end)
        
        if not success then
            print("BalatroMCP Debug: Failed to write to log file: " .. tostring(err))
        end
    end
end

function DebugLogger:debug(message, component)
    self:log("DEBUG", message, component)
end

function DebugLogger:info(message, component)
    self:log("INFO", message, component)
end

function DebugLogger:warn(message, component)
    self:log("WARN", message, component)
end

function DebugLogger:error(message, component)
    self:log("ERROR", message, component)
end

function DebugLogger:test_environment()
    self:info("=== ENVIRONMENT TESTING ===", "ENV")
    
    -- Test Lua version
    self:info("Lua version: " .. (_VERSION or "unknown"), "ENV")
    
    -- Test love.filesystem
    if love and love.filesystem then
        self:info("love.filesystem available", "ENV")
        local success, version = pcall(function() return love.getVersion() end)
        if success then
            self:info("Love2D version: " .. tostring(version), "ENV")
        end
    else
        self:error("love.filesystem NOT available", "ENV")
    end
    
    -- Test JSON library
    local json_success, json = pcall(require, "json")
    if json_success then
        self:info("JSON library available", "ENV")
        
        -- Test JSON encode/decode
        local test_data = {test = "value", number = 42}
        local encode_success, encoded = pcall(json.encode, test_data)
        if encode_success then
            self:info("JSON encode test: SUCCESS", "ENV")
            local decode_success, decoded = pcall(json.decode, encoded)
            if decode_success and decoded.test == "value" then
                self:info("JSON decode test: SUCCESS", "ENV")
            else
                self:error("JSON decode test: FAILED", "ENV")
            end
        else
            self:error("JSON encode test: FAILED", "ENV")
        end
    else
        self:error("JSON library NOT available: " .. tostring(json), "ENV")
    end
    
    -- Test global G object
    if G then
        self:info("Global G object available", "ENV")
        self:log_g_object_structure()
    else
        self:error("Global G object NOT available", "ENV")
    end
    
    -- Test Steammodded
    if SMODS then
        self:info("SMODS object available", "ENV")
        if SMODS.INIT then
            self:info("SMODS.INIT available", "ENV")
        else
            self:warn("SMODS.INIT NOT available", "ENV")
        end
    else
        self:warn("SMODS object NOT available", "ENV")
    end
end

function DebugLogger:log_g_object_structure()
    self:info("=== G OBJECT STRUCTURE ANALYSIS ===", "G_STRUCT")
    
    if not G then
        self:error("G object is nil", "G_STRUCT")
        return
    end
    
    -- Log top-level G properties
    local g_keys = {}
    for key, _ in pairs(G) do
        table.insert(g_keys, key)
    end
    table.sort(g_keys)
    self:info("G object keys: " .. table.concat(g_keys, ", "), "G_STRUCT")
    
    -- Test specific properties we need
    local properties_to_test = {
        "STATE", "STATES", "GAME", "hand", "jokers", "consumeables", 
        "shop_jokers", "FUNCS", "CARD_W"
    }
    
    for _, prop in ipairs(properties_to_test) do
        if G[prop] ~= nil then
            self:info("G." .. prop .. " exists (type: " .. type(G[prop]) .. ")", "G_STRUCT")
            
            -- Log deeper structure for important objects
            if prop == "STATES" and type(G[prop]) == "table" then
                local states = {}
                for key, _ in pairs(G[prop]) do
                    table.insert(states, key)
                end
                self:info("G.STATES keys: " .. table.concat(states, ", "), "G_STRUCT")
            elseif prop == "FUNCS" and type(G[prop]) == "table" then
                local funcs = {}
                for key, _ in pairs(G[prop]) do
                    table.insert(funcs, key)
                end
                self:info("G.FUNCS keys: " .. table.concat(funcs, ", "), "G_STRUCT")
            elseif prop == "hand" and type(G[prop]) == "table" then
                self:log_card_area_structure(G[prop], "hand")
            elseif prop == "jokers" and type(G[prop]) == "table" then
                self:log_card_area_structure(G[prop], "jokers")
            elseif prop == "GAME" and type(G[prop]) == "table" then
                self:log_game_object_structure(G[prop])
            end
        else
            self:warn("G." .. prop .. " does NOT exist", "G_STRUCT")
        end
    end
end

function DebugLogger:log_card_area_structure(area, area_name)
    self:info("=== " .. string.upper(area_name) .. " AREA STRUCTURE ===", "CARD_AREA")
    
    if not area then
        self:error(area_name .. " area is nil", "CARD_AREA")
        return
    end
    
    -- Log area properties
    local area_keys = {}
    for key, _ in pairs(area) do
        table.insert(area_keys, key)
    end
    self:info(area_name .. " keys: " .. table.concat(area_keys, ", "), "CARD_AREA")
    
    -- Check for cards array
    if area.cards then
        self:info(area_name .. ".cards exists (type: " .. type(area.cards) .. ", length: " .. #area.cards .. ")", "CARD_AREA")
        
        -- Log first card structure if available
        if #area.cards > 0 then
            self:log_card_structure(area.cards[1], area_name .. "[0]")
        end
    else
        self:warn(area_name .. ".cards does NOT exist", "CARD_AREA")
    end
end

function DebugLogger:log_card_structure(card, card_name)
    self:info("=== " .. string.upper(card_name) .. " CARD STRUCTURE ===", "CARD")
    
    if not card then
        self:error(card_name .. " is nil", "CARD")
        return
    end
    
    local card_keys = {}
    for key, _ in pairs(card) do
        table.insert(card_keys, key)
    end
    self:info(card_name .. " keys: " .. table.concat(card_keys, ", "), "CARD")
    
    -- Check specific properties we need
    local properties_to_check = {"base", "ability", "edition", "seal", "unique_val", "config"}
    for _, prop in ipairs(properties_to_check) do
        if card[prop] then
            self:info(card_name .. "." .. prop .. " exists (type: " .. type(card[prop]) .. ")", "CARD")
            
            if prop == "base" and type(card[prop]) == "table" then
                local base_keys = {}
                for key, _ in pairs(card[prop]) do
                    table.insert(base_keys, key)
                end
                self:info(card_name .. ".base keys: " .. table.concat(base_keys, ", "), "CARD")
                
                if card[prop].value then
                    self:info(card_name .. ".base.value = " .. tostring(card[prop].value), "CARD")
                end
                if card[prop].suit then
                    self:info(card_name .. ".base.suit = " .. tostring(card[prop].suit), "CARD")
                end
            end
        else
            self:warn(card_name .. "." .. prop .. " does NOT exist", "CARD")
        end
    end
end

function DebugLogger:log_game_object_structure(game)
    self:info("=== GAME OBJECT STRUCTURE ===", "GAME")
    
    local game_keys = {}
    for key, _ in pairs(game) do
        table.insert(game_keys, key)
    end
    self:info("G.GAME keys: " .. table.concat(game_keys, ", "), "GAME")
    
    -- Check specific properties
    local properties_to_check = {"dollars", "current_round", "round_resets", "blind"}
    for _, prop in ipairs(properties_to_check) do
        if game[prop] then
            self:info("G.GAME." .. prop .. " exists (type: " .. type(game[prop]) .. ")", "GAME")
            if prop == "dollars" then
                self:info("G.GAME.dollars = " .. tostring(game[prop]), "GAME")
            end
        else
            self:warn("G.GAME." .. prop .. " does NOT exist", "GAME")
        end
    end
end

function DebugLogger:test_file_communication()
    self:info("=== FILE COMMUNICATION TEST ===", "FILE_IO")
    
    -- Test directory creation (only for subdirectories)
    if love and love.filesystem then
        if self.base_path == "." then
            self:info("Directory creation: SKIPPED (using current directory)", "FILE_IO")
        else
            local success = love.filesystem.createDirectory(self.base_path)
            if success then
                self:info("Directory creation: SUCCESS", "FILE_IO")
            else
                self:error("Directory creation: FAILED", "FILE_IO")
            end
        end
        
        -- Test file write
        local test_data = {test = "file_write", timestamp = os.time()}
        local json_success, json = pcall(require, "json")
        if json_success then
            local encode_success, encoded = pcall(json.encode, test_data)
            if encode_success then
                -- Handle path construction for current directory vs subdirectory
                local test_filepath
                if self.base_path == "." then
                    test_filepath = "test_write.json"
                else
                    test_filepath = self.base_path .. "/test_write.json"
                end
                
                local write_success = love.filesystem.write(test_filepath, encoded)
                if write_success then
                    self:info("File write test: SUCCESS", "FILE_IO")
                    
                    -- Test file read
                    local content, size = love.filesystem.read(test_filepath)
                    if content then
                        self:info("File read test: SUCCESS (size: " .. (size or 0) .. ")", "FILE_IO")
                        
                        -- Test JSON decode
                        local decode_success, decoded = pcall(json.decode, content)
                        if decode_success and decoded.test == "file_write" then
                            self:info("File JSON decode test: SUCCESS", "FILE_IO")
                        else
                            self:error("File JSON decode test: FAILED", "FILE_IO")
                        end
                    else
                        self:error("File read test: FAILED", "FILE_IO")
                    end
                else
                    self:error("File write test: FAILED", "FILE_IO")
                end
            else
                self:error("JSON encode for file test: FAILED", "FILE_IO")
            end
        else
            self:error("JSON library required for file test: FAILED", "FILE_IO")
        end
    else
        self:error("love.filesystem required for file test: NOT AVAILABLE", "FILE_IO")
    end
end

function DebugLogger:test_transport_communication(transport)
    if not transport then
        self:error("No transport provided for communication test", "TRANSPORT_IO")
        return
    end
    
    self:info("=== TRANSPORT COMMUNICATION TEST ===", "TRANSPORT_IO")
    
    -- Test transport availability
    local available = transport:is_available()
    if available then
        self:info("Transport availability: SUCCESS", "TRANSPORT_IO")
    else
        self:error("Transport availability: FAILED", "TRANSPORT_IO")
        return
    end
    
    -- Test message write (only for non-actions message types)
    local test_message = {
        test = "transport_write",
        timestamp = os.time(),
        sequence_id = 1
    }
    
    local json_success, json_lib = pcall(function()
        if SMODS then
            local json_loader = SMODS.load_file("libs/json.lua")
            return json_loader()
        else
            return require("json")
        end
    end)
    
    if json_success and json_lib then
        local encode_success, encoded = pcall(json_lib.encode, test_message)
        if encode_success then
            local write_success = transport:write_message(encoded, "debug_test")
            if write_success then
                self:info("Transport write test: SUCCESS", "TRANSPORT_IO")
                
                -- Test message verification
                local verify_success = transport:verify_message(encoded, "debug_test")
                if verify_success then
                    self:info("Transport verify test: SUCCESS", "TRANSPORT_IO")
                else
                    self:warn("Transport verify test: FAILED", "TRANSPORT_IO")
                end
            else
                self:error("Transport write test: FAILED", "TRANSPORT_IO")
            end
        else
            self:error("JSON encode for transport test: FAILED", "TRANSPORT_IO")
        end
    else
        self:error("JSON library required for transport test: FAILED", "TRANSPORT_IO")
    end
end

return DebugLogger