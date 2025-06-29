-- Boss reroll validation with voucher requirements and cost checking
-- Enforces Director's Cut per-ante limits and Retcon unlimited rerolls

local IActionValidator = assert(SMODS.load_file("action_executor/validators/i_action_validator.lua"))()
local ValidationResult = assert(SMODS.load_file("action_executor/validators/validation_result.lua"))()
local RerollTracker = assert(SMODS.load_file("action_executor/utils/reroll_tracker.lua"))()

-- Voucher name constants to avoid typos and enable easy maintenance
local VOUCHER_NAMES = {
    DIRECTORS_CUT = "director's cut",
    DIRECTORS_CUT_ALT1 = "directors cut", 
    DIRECTORS_CUT_ALT2 = "director cut",
    RETCON = "retcon"
}

-- Cost constants for validation
local REROLL_COST = 10

local RerollValidator = {}
RerollValidator.__index = RerollValidator
setmetatable(RerollValidator, {__index = IActionValidator})

function RerollValidator.new()
    local self = setmetatable({}, RerollValidator)
    self.reroll_tracker = RerollTracker.new()
    return self
end

function RerollValidator:get_name()
    return "reroll_validator"
end

function RerollValidator:get_action_types()
    return {"reroll_boss"}
end

function RerollValidator:validate(action_data, game_state)
    -- Validate that we have the necessary game state information
    if not game_state then
        return ValidationResult.error("No game state available for reroll validation")
    end
    
    -- Check voucher ownership for reroll permissions
    local vouchers = self:get_reroll_vouchers(game_state)
    if not vouchers.directors_cut and not vouchers.retcon then
        return ValidationResult.error("Boss reroll requires 'Director's Cut' or 'Retcon' voucher")
    end
    
    -- Validate cost availability using defined constant
    local reroll_cost = REROLL_COST
    if not self:can_afford_reroll(game_state, reroll_cost) then
        local available_funds = (game_state.dollars or 0) - (game_state.bankrupt_at or 0)
        return ValidationResult.error("Insufficient funds for boss reroll ($" .. reroll_cost .. " required, $" .. available_funds .. " available)")
    end
    
    -- Check per-ante usage limits for Director's Cut (Retcon has unlimited rerolls)
    if vouchers.directors_cut and not vouchers.retcon then
        local current_ante = game_state.current_ante or 1
        local rerolls_this_ante = self.reroll_tracker:get_reroll_count(current_ante)
        
        if rerolls_this_ante >= 1 then
            return ValidationResult.error("Director's Cut allows only 1 boss reroll per ante (used: " .. rerolls_this_ante .. " in ante " .. current_ante .. ")")
        end
        
        print("BalatroMCP: RerollValidator - Director's Cut validation passed for ante " .. current_ante .. " (used: " .. rerolls_this_ante .. "/1)")
    elseif vouchers.retcon then
        local current_ante = game_state.current_ante or 1
        local rerolls_this_ante = self.reroll_tracker:get_reroll_count(current_ante)
        print("BalatroMCP: RerollValidator - Retcon validation passed for ante " .. current_ante .. " (used: " .. rerolls_this_ante .. ", unlimited allowed)")
    end
    
    return ValidationResult.success("Boss reroll validation passed - voucher and cost requirements met")
end

-- Get reroll voucher information from game state
function RerollValidator:get_reroll_vouchers(game_state)
    local vouchers = {
        directors_cut = false,
        retcon = false
    }
    
    -- Extract voucher information from multiple potential sources
    local owned_vouchers = game_state.owned_vouchers or {}
    
    -- Also check if we can extract vouchers directly from game state
    if not owned_vouchers or #owned_vouchers == 0 then
        -- Try to extract vouchers from G.GAME if available
        if G and G.GAME then
            -- Check various potential voucher storage locations
            local potential_voucher_paths = {
                {"vouchers"},
                {"used_vouchers"},
                {"owned_vouchers"},
                {"GAME", "vouchers"}
            }
            
            for _, path in ipairs(potential_voucher_paths) do
                local voucher_data = self:safe_get_nested_value(G.GAME, path, {})
                if voucher_data and type(voucher_data) == "table" then
                    owned_vouchers = self:convert_voucher_data_to_array(voucher_data)
                    break
                end
            end
        end
    end
    
    -- Check each owned voucher for reroll permissions with input validation
    for _, voucher in ipairs(owned_vouchers) do
        -- Validate voucher structure before accessing properties
        if voucher and type(voucher) == "table" and voucher.name and type(voucher.name) == "string" then
            local voucher_name = string.lower(voucher.name)
            
            -- Check for Director's Cut voucher using constants (case-insensitive)
            if voucher_name == VOUCHER_NAMES.DIRECTORS_CUT or 
               voucher_name == VOUCHER_NAMES.DIRECTORS_CUT_ALT1 or 
               voucher_name == VOUCHER_NAMES.DIRECTORS_CUT_ALT2 then
                -- Validate active field exists and is not explicitly false
                local is_active = voucher.active
                if is_active == nil then
                    is_active = true  -- Default to true if field missing
                elseif type(is_active) ~= "boolean" then
                    is_active = (is_active == true or is_active == 1 or is_active == "true")
                end
                vouchers.directors_cut = is_active
            end
            
            -- Check for Retcon voucher using constants (case-insensitive)
            if voucher_name == VOUCHER_NAMES.RETCON then
                -- Validate active field exists and is not explicitly false
                local is_active = voucher.active
                if is_active == nil then
                    is_active = true  -- Default to true if field missing
                elseif type(is_active) ~= "boolean" then
                    is_active = (is_active == true or is_active == 1 or is_active == "true")
                end
                vouchers.retcon = is_active
            end
        end
    end
    
    return vouchers
end

-- Check if player can afford the reroll cost
function RerollValidator:can_afford_reroll(game_state, cost)
    if not game_state then
        return false
    end
    
    local available_money = (game_state.dollars or 0) - (game_state.bankrupt_at or 0)
    return available_money >= cost
end

-- Helper method for safe nested value extraction
function RerollValidator:safe_get_nested_value(obj, path, default)
    if not obj or not path then
        return default
    end
    
    local current = obj
    for _, key in ipairs(path) do
        if type(current) ~= "table" or current[key] == nil then
            return default
        end
        current = current[key]
    end
    
    return current
end

-- Convert voucher data from various formats to standardized array
function RerollValidator:convert_voucher_data_to_array(voucher_data)
    local vouchers = {}
    
    if type(voucher_data) == "table" then
        for key, value in pairs(voucher_data) do
            if type(value) == "table" then
                -- Complex voucher object
                local voucher = {
                    name = value.name or key,
                    active = value.active ~= false,
                    effect = value.effect or "",
                    description = value.description or ""
                }
                table.insert(vouchers, voucher)
            else
                -- Simple key-value pair
                local voucher = {
                    name = key,
                    active = value == true,
                    effect = "",
                    description = ""
                }
                table.insert(vouchers, voucher)
            end
        end
    end
    
    return vouchers
end

-- Get the RerollTracker instance for external access
function RerollValidator:get_reroll_tracker()
    return self.reroll_tracker
end

-- Helper method to get reroll summary for debugging
function RerollValidator:get_reroll_summary(game_state)
    local current_ante = game_state and game_state.current_ante or 1
    local vouchers = self:get_reroll_vouchers(game_state)
    local rerolls_used = self.reroll_tracker:get_reroll_count(current_ante)
    
    return {
        current_ante = current_ante,
        has_directors_cut = vouchers.directors_cut,
        has_retcon = vouchers.retcon,
        rerolls_used_this_ante = rerolls_used,
        can_reroll = vouchers.retcon or (vouchers.directors_cut and rerolls_used < 1),
        cost_required = REROLL_COST,
        can_afford = self:can_afford_reroll(game_state, REROLL_COST)
    }
end

return RerollValidator