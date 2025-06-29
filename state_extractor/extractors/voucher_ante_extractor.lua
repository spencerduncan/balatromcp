-- Voucher and ante information extraction module
-- Handles extraction of owned vouchers, shop vouchers, current ante, and skip vouchers

local IExtractor = assert(SMODS.load_file("state_extractor/extractors/i_extractor.lua"))()
local StateExtractorUtils = assert(SMODS.load_file("state_extractor/utils/state_extractor_utils.lua"))()

local VoucherAnteExtractor = {}
VoucherAnteExtractor.__index = VoucherAnteExtractor
setmetatable(VoucherAnteExtractor, {__index = IExtractor})

-- Module-level cache for successful path discovery optimization
local _successful_voucher_path = nil

function VoucherAnteExtractor.new()
    local self = setmetatable({}, VoucherAnteExtractor)
    return self
end

function VoucherAnteExtractor:get_name()
    return "voucher_ante_extractor"
end

function VoucherAnteExtractor:extract()
    local success, result = pcall(function()
        local voucher_data = {
            current_ante = self:get_current_ante(),
            ante_requirements = self:get_ante_requirements(),
            owned_vouchers = self:extract_owned_vouchers(),
            shop_vouchers = self:extract_shop_vouchers(),
            skip_vouchers = self:extract_skip_vouchers()
        }
        return voucher_data
    end)
    
    if success then
        return {vouchers_ante = result}
    else
        return {vouchers_ante = {
            current_ante = 1,
            ante_requirements = {},
            owned_vouchers = {},
            shop_vouchers = {},
            skip_vouchers = {}
        }}
    end
end

function VoucherAnteExtractor:get_current_ante()
    -- Extract current ante from G.GAME.round_resets.ante following existing pattern
    return StateExtractorUtils.safe_get_nested_value(G, {"GAME", "round_resets", "ante"}, 1)
end

function VoucherAnteExtractor:get_ante_requirements()
    -- Extract ante progression requirements
    local ante_requirements = {}
    local current_ante = self:get_current_ante()
    
    -- Basic ante requirement structure - could be enhanced with actual game logic
    ante_requirements.next_ante = current_ante + 1
    ante_requirements.blinds_remaining = StateExtractorUtils.safe_get_nested_value(G, {"GAME", "round_resets", "blind"}, 0)
    
    return ante_requirements
end

function VoucherAnteExtractor:extract_owned_vouchers()
    -- Extract vouchers that the player owns/has used
    local owned_vouchers = {}
    
    -- Optimized path checking with caching and early returns
    local potential_paths = {
        {"GAME", "owned_vouchers"},    -- Most likely path first
        {"GAME", "vouchers"},
        {"GAME", "used_vouchers"}
    }
    
    -- If we have a cached successful path, try it first
    if _successful_voucher_path and StateExtractorUtils.safe_check_path(G, _successful_voucher_path) then
        local voucher_data = StateExtractorUtils.safe_get_nested_value(G, _successful_voucher_path, {})
        
        if type(voucher_data) == "table" and next(voucher_data) then
            -- Process vouchers from cached path
            for voucher_name, voucher_info in pairs(voucher_data) do
                if type(voucher_info) == "table" then
                    local safe_voucher = {
                        name = StateExtractorUtils.safe_primitive_value(voucher_info, "name", voucher_name),
                        effect = StateExtractorUtils.safe_primitive_value(voucher_info, "effect", ""),
                        description = StateExtractorUtils.safe_primitive_value(voucher_info, "description", ""),
                        active = StateExtractorUtils.safe_primitive_value(voucher_info, "active", true)
                    }
                    table.insert(owned_vouchers, safe_voucher)
                else
                    -- Simple case: voucher name as key, boolean as value
                    local safe_voucher = {
                        name = voucher_name,
                        effect = "",
                        description = "",
                        active = voucher_info == true
                    }
                    table.insert(owned_vouchers, safe_voucher)
                end
            end
            return owned_vouchers -- Early return when cached path successful
        end
    end
    
    -- Fallback: try all paths and cache the successful one
    for _, path in ipairs(potential_paths) do
        if StateExtractorUtils.safe_check_path(G, path) then
            local voucher_data = StateExtractorUtils.safe_get_nested_value(G, path, {})
            
            -- If it's a table of vouchers, extract each one
            if type(voucher_data) == "table" and next(voucher_data) then
                -- Cache this successful path for future calls
                _successful_voucher_path = path
                
                for voucher_name, voucher_info in pairs(voucher_data) do
                    if type(voucher_info) == "table" then
                        local safe_voucher = {
                            name = StateExtractorUtils.safe_primitive_value(voucher_info, "name", voucher_name),
                            effect = StateExtractorUtils.safe_primitive_value(voucher_info, "effect", ""),
                            description = StateExtractorUtils.safe_primitive_value(voucher_info, "description", ""),
                            active = StateExtractorUtils.safe_primitive_value(voucher_info, "active", true)
                        }
                        table.insert(owned_vouchers, safe_voucher)
                    else
                        -- Simple case: voucher name as key, boolean as value
                        local safe_voucher = {
                            name = voucher_name,
                            effect = "",
                            description = "",
                            active = voucher_info == true
                        }
                        table.insert(owned_vouchers, safe_voucher)
                    end
                end
                break -- Found vouchers, stop checking other paths
            end
        end
    end
    
    return owned_vouchers
end

function VoucherAnteExtractor:extract_shop_vouchers()
    -- Extract vouchers available for purchase in shop
    local shop_vouchers = {}
    
    if not StateExtractorUtils.safe_check_path(G, {"shop_vouchers", "cards"}) then
        return shop_vouchers
    end
    
    for i, voucher in ipairs(G.shop_vouchers.cards) do
        if voucher and voucher.ability then
            local safe_voucher = {
                index = i - 1, -- 0-based indexing for consistency
                name = StateExtractorUtils.safe_primitive_nested_value(voucher, {"ability", "name"}, "Unknown"),
                cost = StateExtractorUtils.safe_primitive_value(voucher, "cost", 0),
                effect = StateExtractorUtils.safe_primitive_nested_value(voucher, {"ability", "effect"}, ""),
                description = StateExtractorUtils.safe_primitive_nested_value(voucher, {"ability", "description"}, ""),
                available = true
            }
            table.insert(shop_vouchers, safe_voucher)
        end
    end
    
    return shop_vouchers
end

function VoucherAnteExtractor:extract_skip_vouchers()
    -- Extract skip vouchers/consumables that can skip antes or blinds
    local skip_vouchers = {}
    
    -- Check consumables for skip-related items
    if StateExtractorUtils.safe_check_path(G, {"consumeables", "cards"}) then
        for i, consumable in ipairs(G.consumeables.cards) do
            if consumable and consumable.ability then
                local consumable_name = StateExtractorUtils.safe_primitive_nested_value(consumable, {"ability", "name"}, "")
                local consumable_set = StateExtractorUtils.safe_primitive_nested_value(consumable, {"ability", "set"}, "")
                
                -- Check if this consumable is skip-related (looking for skip in name or effect)
                if self:is_skip_consumable(consumable_name, consumable_set, consumable) then
                    local safe_skip_voucher = {
                        id = StateExtractorUtils.safe_primitive_value(consumable, "unique_val", "skip_" .. i),
                        name = consumable_name,
                        type = consumable_set,
                        quantity = 1 -- Each card represents one use
                    }
                    table.insert(skip_vouchers, safe_skip_voucher)
                end
            end
        end
    end
    
    -- Check for skip vouchers in owned vouchers that provide skip effects
    local owned_vouchers = self:extract_owned_vouchers()
    for _, voucher in ipairs(owned_vouchers) do
        if self:is_skip_voucher_effect(voucher.name, voucher.effect) then
            local safe_skip_voucher = {
                id = "voucher_" .. voucher.name,
                name = voucher.name,
                type = "voucher",
                quantity = voucher.active and 1 or 0
            }
            table.insert(skip_vouchers, safe_skip_voucher)
        end
    end
    
    return skip_vouchers
end

function VoucherAnteExtractor:is_skip_consumable(name, set, consumable)
    -- Check if a consumable is related to skipping antes or blinds
    if not name then return false end
    
    local name_lower = string.lower(name)
    
    -- Look for skip-related keywords in name
    local skip_keywords = {"skip", "pass", "bypass", "ignore"}
    for _, keyword in ipairs(skip_keywords) do
        if string.find(name_lower, keyword) then
            return true
        end
    end
    
    -- Check specific card sets that might contain skip effects
    if set == "Spectral" or set == "Tarot" then
        -- Some spectral or tarot cards might have skip effects
        return false -- For now, return false unless we find specific patterns
    end
    
    return false
end

function VoucherAnteExtractor:is_skip_voucher_effect(name, effect)
    -- Check if a voucher provides skip-related effects
    if not name and not effect then return false end
    
    local search_text = string.lower((name or "") .. " " .. (effect or ""))
    
    -- Look for skip-related keywords in voucher name or effect
    local skip_keywords = {"skip", "pass", "bypass", "ignore", "ante"}
    for _, keyword in ipairs(skip_keywords) do
        if string.find(search_text, keyword) then
            return true
        end
    end
    
    return false
end

return VoucherAnteExtractor