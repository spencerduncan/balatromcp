-- Consumable cards extraction module
-- Handles consumable cards extraction

local IExtractor = assert(SMODS.load_file("state_extractor/extractors/i_extractor.lua"))()
local StateExtractorUtils = assert(SMODS.load_file("state_extractor/utils/state_extractor_utils.lua"))()
local CardUtils = assert(SMODS.load_file("state_extractor/utils/card_utils.lua"))()

local ConsumableExtractor = {}
ConsumableExtractor.__index = ConsumableExtractor
setmetatable(ConsumableExtractor, {__index = IExtractor})

function ConsumableExtractor.new()
    local self = setmetatable({}, ConsumableExtractor)
    return self
end

function ConsumableExtractor:get_name()
    return "consumable_extractor"
end

function ConsumableExtractor:extract()
    local success, result = pcall(function()
        return self:extract_consumables()
    end)
    
    if success then
        return {consumables = result}
    else
        return {consumables = {}}
    end
end

function ConsumableExtractor:validate_card_areas()
    local areas = {
        {name = "hand", object = G.hand},
        {name = "jokers", object = G.jokers},
        {name = "consumeables", object = G.consumeables},
        {name = "shop_jokers", object = G.shop_jokers}
    }
    
    for _, area in ipairs(areas) do
        if area.object and area.object.cards and #area.object.cards > 0 then
            self:validate_card_structure(area.object.cards[1], area.name .. "[1]")
        end
    end
end

function ConsumableExtractor:validate_card_structure(card, card_name)
    if not card then
        return
    end
end

function ConsumableExtractor:extract_consumables()
    -- Extract consumable cards with CIRCULAR REFERENCE SAFE access
    local consumables = {}
    
    if not StateExtractorUtils.safe_check_path(G, {"consumeables", "cards"}) then
        return consumables
    end
    
    for i, consumable in ipairs(G.consumeables.cards) do
        if consumable then
            local safe_consumable = {
                id = StateExtractorUtils.safe_primitive_value(consumable, "unique_val", "consumable_" .. i),
                name = StateExtractorUtils.safe_primitive_nested_value(consumable, {"ability", "name"}, "Unknown"),
                card_type = StateExtractorUtils.safe_primitive_nested_value(consumable, {"ability", "set"}, "Tarot"),
                -- AVOID CIRCULAR REFERENCE: Don't extract complex properties object
                properties = {}
            }
            table.insert(consumables, safe_consumable)
        end
    end
    
    return consumables
end

return ConsumableExtractor