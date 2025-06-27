-- Shop contents extraction module
-- Handles shop contents extraction

local IExtractor = assert(SMODS.load_file("state_extractor/extractors/i_extractor.lua"))()
local StateExtractorUtils = assert(SMODS.load_file("state_extractor/utils/state_extractor_utils.lua"))()
local CardUtils = assert(SMODS.load_file("state_extractor/utils/card_utils.lua"))()

local ShopExtractor = {}
ShopExtractor.__index = ShopExtractor
setmetatable(ShopExtractor, {__index = IExtractor})

function ShopExtractor.new()
    local self = setmetatable({}, ShopExtractor)
    return self
end

function ShopExtractor:get_name()
    return "shop_extractor"
end

function ShopExtractor:extract()
    local success, result = pcall(function()
        return self:extract_shop_contents()
    end)
    
    if success then
        return {shop_contents = result}
    else
        return {shop_contents = {}}
    end
end

function ShopExtractor:extract_shop_contents()
    -- Extract shop contents with CIRCULAR REFERENCE SAFE access
    local shop_contents = {}
    
    -- Extract jokers from G.shop_jokers.cards with proper ability.set filtering
    if StateExtractorUtils.safe_check_path(G, {"shop_jokers", "cards"}) then
        for i, item in ipairs(G.shop_jokers.cards) do
            if item and item.ability and item.ability.set then
                local item_type = "unknown"
                local ability_set = StateExtractorUtils.safe_primitive_nested_value(item, {"ability", "set"}, "")
                
                -- Classify item based on ability.set
                if ability_set == "Joker" then
                    item_type = "joker"
                elseif ability_set == "Planet" then
                    item_type = "planet"
                elseif ability_set == "Tarot" then
                    item_type = "tarot"
                elseif ability_set == "Spectral" then
                    item_type = "spectral"
                elseif ability_set == "Booster" then
                    item_type = "booster"
                else
                    -- Use the raw ability.set value if unknown
                    item_type = string.lower(ability_set)
                end
                
                local safe_item = {
                    index = i - 1, -- 0-based indexing
                    item_type = item_type,
                    name = StateExtractorUtils.safe_primitive_nested_value(item, {"ability", "name"}, "Unknown"),
                    cost = StateExtractorUtils.safe_primitive_value(item, "cost", 0),
                    -- AVOID CIRCULAR REFERENCE: Don't extract complex properties object
                    properties = {}
                }
                table.insert(shop_contents, safe_item)
            end
        end
    end
    
    -- Extract consumables from G.shop_consumables.cards if it exists
    if StateExtractorUtils.safe_check_path(G, {"shop_consumables", "cards"}) then
        for i, item in ipairs(G.shop_consumables.cards) do
            if item and item.ability and item.ability.set then
                local ability_set = StateExtractorUtils.safe_primitive_nested_value(item, {"ability", "set"}, "")
                local item_type = string.lower(ability_set)
                
                local safe_item = {
                    index = (#shop_contents), -- Continue indexing from jokers
                    item_type = item_type,
                    name = StateExtractorUtils.safe_primitive_nested_value(item, {"ability", "name"}, "Unknown"),
                    cost = StateExtractorUtils.safe_primitive_value(item, "cost", 0),
                    properties = {}
                }
                table.insert(shop_contents, safe_item)
            end
        end
    end
    
    -- Extract boosters from G.shop_booster.cards if it exists
    if StateExtractorUtils.safe_check_path(G, {"shop_booster", "cards"}) then
        for i, item in ipairs(G.shop_booster.cards) do
            if item and item.ability and item.ability.set then
                local ability_set = StateExtractorUtils.safe_primitive_nested_value(item, {"ability", "set"}, "")
                local item_type = string.lower(ability_set)
                
                local safe_item = {
                    index = (#shop_contents), -- Continue indexing
                    item_type = item_type,
                    name = StateExtractorUtils.safe_primitive_nested_value(item, {"ability", "name"}, "Unknown"),
                    cost = StateExtractorUtils.safe_primitive_value(item, "cost", 0),
                    properties = {}
                }
                table.insert(shop_contents, safe_item)
            end
        end
    end
    
    -- Extract vouchers from G.shop_vouchers.cards if it exists
    if StateExtractorUtils.safe_check_path(G, {"shop_vouchers", "cards"}) then
        for i, item in ipairs(G.shop_vouchers.cards) do
            if item and item.ability and item.ability.set then
                local ability_set = StateExtractorUtils.safe_primitive_nested_value(item, {"ability", "set"}, "")
                local item_type = string.lower(ability_set)
                
                local safe_item = {
                    index = (#shop_contents), -- Continue indexing
                    item_type = item_type,
                    name = StateExtractorUtils.safe_primitive_nested_value(item, {"ability", "name"}, "Unknown"),
                    cost = StateExtractorUtils.safe_primitive_value(item, "cost", 0),
                    properties = {}
                }
                table.insert(shop_contents, safe_item)
            end
        end
    end
    
    
    return shop_contents
end

return ShopExtractor