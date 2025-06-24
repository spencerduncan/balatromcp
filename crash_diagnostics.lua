-- Crash Diagnostics Module for BalatroMCP
-- Adds logging to identify the source of config field nil errors

local CrashDiagnostics = {}
CrashDiagnostics.__index = CrashDiagnostics

function CrashDiagnostics.new()
    local self = setmetatable({}, CrashDiagnostics)
    self.hook_call_count = 0
    self.object_access_count = 0
    self.last_hook_called = "none"
    self.last_object_accessed = "none"
    return self
end

function CrashDiagnostics:log(message)
    local timestamp = os.date("%H:%M:%S")
    print("BalatroMCP [CRASH_DIAG] " .. timestamp .. ": " .. message)
end

function CrashDiagnostics:validate_object_config(obj, obj_name, access_location)
    self.object_access_count = self.object_access_count + 1
    self.last_object_accessed = obj_name .. " at " .. access_location

    if not obj then
        self:log("ERROR: " .. obj_name .. " is nil (accessed from " .. access_location .. ")")
        return false
    end

    if not obj.config then
        self:log("ERROR: " .. obj_name .. ".config is nil (accessed from " .. access_location .. ")")
        self:log("DIAGNOSTIC: " .. obj_name .. " type: " .. type(obj))

        -- Log available properties
        if type(obj) == "table" then
            local props = {}
            for k, v in pairs(obj) do
                table.insert(props, k .. ":" .. type(v))
            end
            self:log("DIAGNOSTIC: " .. obj_name .. " properties: " .. table.concat(props, ", "))
        end
        return false
    end

    return true
end

function CrashDiagnostics:pre_hook_validation(hook_name)
    self.hook_call_count = self.hook_call_count + 1
    self.last_hook_called = hook_name

    self:log("PRE_HOOK: " .. hook_name .. " (call #" .. self.hook_call_count .. ")")

    -- Validate critical game state before hook execution
    if not G then
        self:log("ERROR: G object is nil before " .. hook_name)
        return false
    end

    if not G.STATE then
        self:log("ERROR: G.STATE is nil before " .. hook_name)
        return false
    end

    self:log("PRE_HOOK: G.STATE = " .. tostring(G.STATE) .. " before " .. hook_name)

    -- Validate specific objects based on hook type
    if hook_name:find("cards") then
        if not G.hand or not G.hand.cards then
            self:log("ERROR: G.hand.cards invalid before " .. hook_name)
            return false
        end

        -- Check each card object
        for i, card in ipairs(G.hand.cards) do
            if not self:validate_object_config(card, "hand_card[" .. i .. "]", hook_name) then
                return false
            end
        end
    elseif hook_name:find("joker") or hook_name:find("shop") then
        if G.jokers and G.jokers.cards then
            for i, joker in ipairs(G.jokers.cards) do
                if not self:validate_object_config(joker, "joker[" .. i .. "]", hook_name) then
                    return false
                end
            end
        end
    end

    return true
end

function CrashDiagnostics:post_hook_validation(hook_name)
    self:log("POST_HOOK: " .. hook_name .. " completed")

    -- Check if game state changed unexpectedly
    if not G then
        self:log("ERROR: G object became nil after " .. hook_name)
        return false
    end

    if not G.STATE then
        self:log("ERROR: G.STATE became nil after " .. hook_name)
        return false
    end

    self:log("POST_HOOK: G.STATE = " .. tostring(G.STATE) .. " after " .. hook_name)
    return true
end

function CrashDiagnostics:create_safe_hook(original_func, hook_name)
    -- Create a wrapped version of the hook with diagnostics
    return function(...)
        local args = {...}  -- Capture varargs in local variable

        -- Pre-hook validation
        if not self:pre_hook_validation(hook_name) then
            self:log("CRITICAL: Pre-hook validation failed for " .. hook_name .. " - SKIPPING HOOK")
            if original_func then
                return original_func(unpack(args))
            end
            return nil
        end

        -- Execute original function with error handling
        local success, result = pcall(function()
            if original_func then
                return original_func(unpack(args))
            end
        end)

        if not success then
            self:log("ERROR: Hook " .. hook_name .. " failed: " .. tostring(result))
            self:log("CONTEXT: Last object accessed: " .. self.last_object_accessed)
            self:log("CONTEXT: Hook call count: " .. self.hook_call_count)
        end

        -- Post-hook validation
        self:post_hook_validation(hook_name)

        if success then
            return result
        else
            return nil
        end
    end
end

function CrashDiagnostics:monitor_joker_operations()
    -- Add specific monitoring for joker operations that access config
    if G and G.jokers and G.jokers.cards then
       -- self:log("MONITORING: Scanning " .. #G.jokers.cards .. " jokers for config validity")


        for i, joker in ipairs(G.jokers.cards) do
            if not self:validate_object_config(joker, "monitored_joker[" .. i .. "]", "monitor_joker_operations") then
                self:log("CRITICAL: Found corrupted joker during monitoring!")

                -- Log detailed joker state
                if joker then
                    self:log("DETAIL: Joker " .. i .. " exists but config is nil")
                    if joker.ability then
                        self:log("DETAIL: Joker " .. i .. " has ability object")
                    end
                    if joker.unique_val then
                        self:log("DETAIL: Joker " .. i .. " unique_val: " .. tostring(joker.unique_val))
                    end
                else
                    self:log("DETAIL: Joker " .. i .. " is completely nil")
                end
            end
        end
    end
end

function CrashDiagnostics:validate_game_state(operation)
    -- Comprehensive game state validation before critical operations
    self:log("STATE_VALIDATION: Starting for operation: " .. operation)

    if not G then
        self:log("CRITICAL: Global G object is nil during " .. operation)
        return false
    end

    if not G.STATE then
        self:log("CRITICAL: G.STATE is nil during " .. operation)
        return false
    end

    if type(G.STATE) ~= "number" then
        self:log("WARNING: G.STATE is not a number (type: " .. type(G.STATE) .. ") during " .. operation)
    end

    -- Validate critical game objects
    local critical_objects = {
        {"G.hand", G.hand},
        {"G.jokers", G.jokers},
        {"G.deck", G.deck},
        {"G.FUNCS", G.FUNCS}
    }

    for _, obj_info in ipairs(critical_objects) do
        local name, obj = obj_info[1], obj_info[2]
        if not obj then
            self:log("WARNING: " .. name .. " is nil during " .. operation)
        end
    end

    self:log("STATE_VALIDATION: Completed for " .. operation)
    return true
end

function CrashDiagnostics:track_hook_chain(hook_name)
    -- Track the chain of hooks being called to identify patterns before crashes
    if not self.hook_chain then
        self.hook_chain = {}
    end

    table.insert(self.hook_chain, {
        hook = hook_name,
        timestamp = love.timer and love.timer.getTime() or os.clock(),
        state = G and G.STATE or "NIL"
    })

    -- Keep only the last 10 hooks to avoid memory issues
    if #self.hook_chain > 10 then
        table.remove(self.hook_chain, 1)
    end

    self:log("HOOK_CHAIN: Added " .. hook_name .. " (chain length: " .. #self.hook_chain .. ")")
end

function CrashDiagnostics:analyze_hook_chain()
    -- Analyze the hook chain for patterns that might lead to crashes
    if not self.hook_chain or #self.hook_chain == 0 then
        return "No hook chain data available"
    end

    local analysis = "Hook chain analysis:\n"
    for i, hook_data in ipairs(self.hook_chain) do
        analysis = analysis .. string.format("  %d: %s (state=%s, time=%.3f)\n",
            i, hook_data.hook, tostring(hook_data.state), hook_data.timestamp)
    end

    -- Look for rapid hook calls (potential infinite loops)
    if #self.hook_chain >= 3 then
        local recent_hooks = {}
        for i = math.max(1, #self.hook_chain - 2), #self.hook_chain do
            recent_hooks[self.hook_chain[i].hook] = (recent_hooks[self.hook_chain[i].hook] or 0) + 1
        end

        for hook, count in pairs(recent_hooks) do
            if count >= 2 then
                analysis = analysis .. "WARNING: Rapid calls to " .. hook .. " detected (" .. count .. " times)\n"
            end
        end
    end

    return analysis
end

function CrashDiagnostics:emergency_state_dump()
    -- Emergency dump of critical game state when crash is detected
    self:log("EMERGENCY_DUMP: Starting critical state dump")

    -- Dump G object structure
    if G then
        self:log("EMERGENCY_DUMP: G object exists")
        self:log("EMERGENCY_DUMP: G.STATE = " .. tostring(G.STATE))

        if G.jokers then
            local joker_count = G.jokers.cards and #G.jokers.cards or 0
            self:log("EMERGENCY_DUMP: Joker count = " .. joker_count)

            if G.jokers.cards then
                for i, joker in ipairs(G.jokers.cards) do
                    local joker_status = "unknown"
                    if joker then
                        if joker.config and joker.config.center and joker.config.center.key then
                            joker_status = joker.config.center.key
                        else
                            joker_status = "corrupted_config"
                        end
                    else
                        joker_status = "nil_joker"
                    end
                    self:log("EMERGENCY_DUMP: Joker[" .. i .. "] = " .. joker_status)
                end
            end
        else
            self:log("EMERGENCY_DUMP: G.jokers is nil")
        end

        if G.hand then
            local hand_count = G.hand.cards and #G.hand.cards or 0
            self:log("EMERGENCY_DUMP: Hand card count = " .. hand_count)
        else
            self:log("EMERGENCY_DUMP: G.hand is nil")
        end
    else
        self:log("EMERGENCY_DUMP: G object is nil")
    end

    -- Dump hook chain
    self:log("EMERGENCY_DUMP: Hook chain analysis:")
    self:log(self:analyze_hook_chain())

    self:log("EMERGENCY_DUMP: Completed")
end

function CrashDiagnostics:get_crash_context()
    -- Return context information for crash analysis
    return {
        last_hook_called = self.last_hook_called,
        hook_call_count = self.hook_call_count,
        last_object_accessed = self.last_object_accessed,
        object_access_count = self.object_access_count,
        hook_chain = self.hook_chain or {},
        timestamp = os.time(),
        emergency_dump = function() return self:emergency_state_dump() end
    }
end

function CrashDiagnostics:create_safe_state_extraction_wrapper(state_extractor)
    -- Create a safe wrapper around state extraction to prevent crashes
    if not state_extractor then
        self:log("ERROR: Cannot wrap nil state_extractor")
        return
    end
    
    self:log("INFO: Creating safe state extraction wrapper")
    
    -- Store original method
    local original_extract = state_extractor.extract_current_state
    if not original_extract then
        self:log("ERROR: state_extractor missing extract_current_state method")
        return
    end
    
    -- Create wrapped version with crash protection
    state_extractor.extract_current_state = function(self_extractor)
        local success, result = pcall(function()
            return original_extract(self_extractor)
        end)
        
        if success then
            return result
        else
            self:log("ERROR: State extraction failed: " .. tostring(result))
            self:emergency_state_dump()
            -- Return minimal safe state
            return {
                current_phase = "error",
                extraction_errors = {"State extraction crashed: " .. tostring(result)}
            }
        end
    end
    
    self:log("INFO: Safe state extraction wrapper created successfully")
end

return CrashDiagnostics