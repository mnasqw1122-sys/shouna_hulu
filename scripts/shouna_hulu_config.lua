local M = {}

local PAGE_SIZE = 80

local RECIPE_ITEMS =
{
    { key = "recipe_gold", prefab = "goldnugget" },
    { key = "recipe_boards", prefab = "boards" },
    { key = "recipe_cutstone", prefab = "cutstone" },
    { key = "recipe_papyrus", prefab = "papyrus" },
    { key = "recipe_rope", prefab = "rope" },
}

local function ClampNumber(value, min_value, max_value, fallback)
    value = tonumber(value) or fallback
    if value < min_value then
        return min_value
    end
    if value > max_value then
        return max_value
    end
    return value
end

-- 读取模组页数配置，并限制在安全范围内。
function M.GetPageCount(get_config_fn)
    local value
    if get_config_fn then
        value = get_config_fn("page_count")
    elseif TUNING and TUNING.SHOUNA_HULU_CONFIG then
        value = TUNING.SHOUNA_HULU_CONFIG["page_count"]
    elseif GLOBAL and GLOBAL.TUNING and GLOBAL.TUNING.SHOUNA_HULU_CONFIG then
        value = GLOBAL.TUNING.SHOUNA_HULU_CONFIG["page_count"]
    end
    return ClampNumber(value, 1, 8, 5)
end

-- 返回单页固定格子数量，供界面和容器共用。
function M.GetPageSize()
    return PAGE_SIZE
end

-- 计算容器总格子数量。
function M.GetTotalSlots(get_config_fn)
    return M.GetPageCount(get_config_fn) * PAGE_SIZE
end

-- 按配置构造配方材料；若启用免费制作则返回空表。
function M.BuildRecipeIngredients(Ingredient_func, get_config_fn)
    local function GetConfigData(key)
        if get_config_fn then
            return get_config_fn(key)
        elseif TUNING and TUNING.SHOUNA_HULU_CONFIG then
            return TUNING.SHOUNA_HULU_CONFIG[key]
        elseif GLOBAL and GLOBAL.TUNING and GLOBAL.TUNING.SHOUNA_HULU_CONFIG then
            return GLOBAL.TUNING.SHOUNA_HULU_CONFIG[key]
        end
        return nil
    end

    if GetConfigData("recipe_mode") == "free" then
        return {}
    end

    local ingredients = {}
    local total_cost = 0

    for _, entry in ipairs(RECIPE_ITEMS) do
        local count = math.max(0, tonumber(GetConfigData(entry.key)) or 0)
        if count > 0 then
            table.insert(ingredients, Ingredient_func(entry.prefab, count))
            total_cost = total_cost + count
        end
    end

    if total_cost == 0 then
        table.insert(ingredients, Ingredient_func("goldnugget", 1))
    end

    return ingredients
end

return M
