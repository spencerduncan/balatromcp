-- Emergency diagnostics to identify the source of config field nil errors
-- This will help isolate whether it's state extraction or hook interference

local NilConfigDiagnostics = {}
NilConfigDiagnostics.__index = NilConfigDiagnostics

function NilConfigDiagnostics.new()
    local self = setmetatable({}, NilConfigDiagnostics)
    self.state_access_count = 0
    self.blind_transition_count = 0
    self.last_state_access_time = 0
    self.last_blind_transition_time = 0
    self.object_access_log = {}
    return self
end

function NilConfigDiagnostics:log(message)
    local timestamp = love.timer and love.timer.getTime() or os.clock()
    print("BalatroMCP [NIL_CONFIG_DIAG] " .. string.format("%.3f", timestamp) .. ": " .. message)
end

function NilConfigDiagnostics:track_state_extraction_start()
    self.state_access_count = self.state_access_count + 1
    self.last_state_access_time = love.timer and love.timer.getTime() or os.clock()
    
    -- Log current game state at start of extraction
    local g_state = G and G.STATE or "NIL"
    self:log("STATE_EXTRACTION_START #" .. self.state_access_count .. " - G.STATE=" .. tostring(g_state))
    
    -- Check if we're in a critical transition period
    if self:is_during_critical_transition() then
        self:log("WARNING: State extraction during CRITICAL TRANSITION (blind selection)")
        return false -- Suggests we should skip extraction
    end
    
    return true -- Safe to proceed
end

function NilConfigDiagnostics:track_state_extraction_object_access(obj_type, obj, obj_path)
    -- Track every object access during state extraction
    if not obj then
        self:log("OBJECT_ACCESS: " .. obj_type .. " at " .. obj_path .. " is NIL")
        return
    end
    
    -- Check config field specifically
    if obj.config == nil then
        self:log("CONFIG_NIL_DETECTED: " .. obj_type .. " at " .. obj_path .. " has nil config field")
        self:log("CONFIG_NIL_CONTEXT: G.STATE=" .. tostring(G and G.STATE or "NIL"))
        self:log("CONFIG_NIL_TIMING: " .. string.format("%.3f", self.last_state_access_time))
        
        -- Log object properties to understand what it is
        if type(obj) == "table" then
            local props = {}
            for k, v in pairs(obj) do
                if k ~= "config" then  -- Skip the nil config
                    table.insert(props, k .. ":" .. type(v))
                end
            end
            self:log("CONFIG_NIL_OBJECT_PROPS: " .. table.concat(props, ", "))
        end
        
        return false -- Signal that this object is corrupted
    end
    
    return true -- Object is safe
end

function NilConfigDiagnostics:track_blind_transition_start(transition_type)
    self.blind_transition_count = self.blind_transition_count + 1
    self.last_blind_transition_time = love.timer and love.timer.getTime() or os.clock()
    
    self:log("BLIND_TRANSITION_START #" .. self.blind_transition_count .. " - Type: " .. transition_type)
    
    -- Check timing relationship with state extraction
    local time_since_state_access = self.last_blind_transition_time - self.last_state_access_time
    if math.abs(time_since_state_access) < 0.1 then  -- Within 100ms
        self:log("CRITICAL_TIMING: Blind transition within 100ms of state extraction (Δt=" .. string.format("%.3f", time_since_state_access) .. ")")
    end
end

function NilConfigDiagnostics:is_during_critical_transition()
    -- Check if we're currently in a blind selection transition
    if not G or not G.STATE then
        return false
    end
    
    -- Check if we're in blind selection state
    if G.STATES and G.STATE == G.STATES.BLIND_SELECT then
        return true
    end
    
    -- Check timing - if blind transition happened recently
    local current_time = love.timer and love.timer.getTime() or os.clock()
    local time_since_blind_transition = current_time - self.last_blind_transition_time
    
    if time_since_blind_transition < 2.0 then  -- Within 2 seconds of blind transition
        return true
    end
    
    return false
end

function NilConfigDiagnostics:validate_critical_objects_before_hook(hook_name)
    -- Validate objects that are likely to be accessed by button callbacks
    self:log("PRE_HOOK_VALIDATION: " .. hook_name)
    
    local objects_to_check = {
        {"G.GAME", G.GAME},
        {"G.GAME.blind", G.GAME and G.GAME.blind},
        {"G.GAME.current_blind", G.GAME and G.GAME.current_blind},
        {"G.blind_select", G.blind_select},
    }
    
    local corrupted_objects = {}
    
    for _, obj_info in ipairs(objects_to_check) do
        local name, obj = obj_info[1], obj_info[2]
        
        if obj and type(obj) == "table" then
            if obj.config == nil then
                table.insert(corrupted_objects, name)
                self:log("PRE_HOOK_CONFIG_NIL: " .. name .. ".config is nil before " .. hook_name)
            end
        end
    end
    
    if #corrupted_objects > 0 then
        self:log("PRE_HOOK_CRITICAL: " .. #corrupted_objects .. " objects have nil config before " .. hook_name)
        return false
    end
    
    return true
end

function NilConfigDiagnostics:create_safe_state_extraction_wrapper(state_extractor)
    -- Wrap state extraction with diagnostics and safety checks
    local original_extract = state_extractor.extract_current_state
    
    state_extractor.extract_current_state = function(self)
        local diagnostics = _G.BalatroMCP_NilConfigDiagnostics
        
        if not diagnostics then
            -- Fallback if diagnostics not available
            return original_extract(self)
        end
        
        -- Check if it's safe to extract state
        if not diagnostics:track_state_extraction_start() then
            diagnostics:log("SKIPPING_STATE_EXTRACTION: During critical transition")
            return nil  -- Skip extraction during critical transitions
        end
        
        -- Wrap object access
        local original_safe_check_path = self.safe_check_path
        self.safe_check_path = function(self, root, path)
            local path_str = table.concat(path, ".")
            local result = original_safe_check_path(self, root, path)
            
            -- Track the access
            diagnostics:track_state_extraction_object_access("path_check", root, path_str)
            
            return result
        end
        
        -- Execute original extraction with error handling
        local success, result = pcall(original_extract, self)
        
        -- Restore original function
        self.safe_check_path = original_safe_check_path
        
        if not success then
            diagnostics:log("STATE_EXTRACTION_ERROR: " .. tostring(result))
            return nil
        end
        
        diagnostics:log("STATE_EXTRACTION_COMPLETE")
        return result
    end
end

function NilConfigDiagnostics:create_safe_blind_hook_wrapper(original_hook, hook_name)
    -- Wrap blind selection hooks with diagnostics
    return function(...)
        local diagnostics = _G.BalatroMCP_NilConfigDiagnostics
        
        if diagnostics then
            diagnostics:track_blind_transition_start(hook_name)
            
            if not diagnostics:validate_critical_objects_before_hook(hook_name) then
                diagnostics:log("SKIPPING_HOOK: Critical objects corrupted before " .. hook_name)
                -- Still call original to avoid breaking game flow
                if original_hook then
                    return original_hook(...)
                end
                return
            end
        end
        
        -- Execute original hook
        if original_hook then
            return original_hook(...)
        end
    end
end

return NilConfigDiagnostics