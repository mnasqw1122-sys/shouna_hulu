PrefabFiles =
{
    "shouna_hulu",
}

local ShouNaHuluConfig = require("shouna_hulu_config")
local ShouNaHuluAssets = require("shouna_hulu_assets")
local ShouNaHuluContainer = require("shouna_hulu_container")
local containers = require("containers")

GLOBAL.TUNING.SHOUNA_HULU_CONFIG = {
    page_count = GetModConfigData("page_count"),
    recipe_mode = GetModConfigData("recipe_mode"),
    recipe_gold = GetModConfigData("recipe_gold"),
    recipe_boards = GetModConfigData("recipe_boards"),
    recipe_cutstone = GetModConfigData("recipe_cutstone"),
    recipe_papyrus = GetModConfigData("recipe_papyrus"),
    recipe_rope = GetModConfigData("recipe_rope"),
}

local RPC_NAMESPACE = "shouna_hulu"
local MAX_PAGE_COUNT = 8
local MAX_TOTAL_SLOTS = MAX_PAGE_COUNT * ShouNaHuluConfig.GetPageSize()

local default_container_data = ShouNaHuluContainer.CreateContainerData(MAX_TOTAL_SLOTS)
containers.params.shouna_hulu = default_container_data
containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS, #default_container_data.widget.slotpos)

if GLOBAL.TheNet ~= nil and not GLOBAL.TheNet:IsDedicated() then
    local ShouNaHuluUI = require("shouna_hulu_ui")
    ShouNaHuluUI.InstallContainerWidgetPatch(RPC_NAMESPACE, AddClassPostConstruct)
    ShouNaHuluAssets.RegisterInventoryAtlas()
end

local recipe_image = ShouNaHuluAssets.GetInventoryImageName()
local recipe_atlas = ShouNaHuluAssets.GetInventoryAtlasPath()

GLOBAL.STRINGS.NAMES.SHOUNA_HULU = "收纳葫芦"
GLOBAL.STRINGS.CHARACTERS.GENERIC.DESCRIBE.SHOUNA_HULU = "一只翻页就能继续装的大葫芦。"
GLOBAL.STRINGS.RECIPE_DESC.SHOUNA_HULU = "一只随身携带的大容量葫芦。"

AddRecipe2(
    "shouna_hulu",
    ShouNaHuluConfig.BuildRecipeIngredients(GLOBAL.Ingredient, GetModConfigData),
    GLOBAL.TECH.NONE,
    {
        nounlock = true,
        atlas = recipe_atlas,
        image = recipe_image,
    },
    { "CONTAINERS" }
)

-- 服务端：拦截制作消耗和材料检查，让收纳葫芦里的物品可直接用于制作
AddClassPostConstruct("components/inventory", function(self)
    local old_Has = self.Has
    function self:Has(item, amount, checkallcontainers)
        local has, count = old_Has(self, item, amount, checkallcontainers)
        if count >= amount or not checkallcontainers then return has, count end
        
        for k, v in pairs(self.itemslots) do
            if v and v.prefab == "shouna_hulu" and v.components.container then
                local hulu_has, hulu_count = v.components.container:Has(item, amount, true)
                count = count + hulu_count
            end
        end
        return count >= amount, count
    end
    
    local old_GetItemByName = self.GetItemByName
    if old_GetItemByName then
        function self:GetItemByName(item, amount, checkallcontainers)
            local items = old_GetItemByName(self, item, amount, checkallcontainers)
            if not checkallcontainers then return items end
            
            local total_num_found = 0
            for k, v in pairs(items) do
                total_num_found = total_num_found + v
            end
            
            if total_num_found < amount then
                for k, v in pairs(self.itemslots) do
                    if v and v.prefab == "shouna_hulu" and v.components.container then
                        local hulu_items = v.components.container:GetItemByName(item, amount - total_num_found)
                        for hk, hv in pairs(hulu_items) do
                            items[hk] = hv
                            total_num_found = total_num_found + hv
                        end
                    end
                    if total_num_found >= amount then break end
                end
            end
            return items
        end
    end
    
    local old_GetCraftingIngredient = self.GetCraftingIngredient
    if old_GetCraftingIngredient then
        function self:GetCraftingIngredient(item, amount)
            local items = old_GetCraftingIngredient(self, item, amount)
            local total_num_found = 0
            for k, v in pairs(items) do
                total_num_found = total_num_found + v
            end
            
            if total_num_found < amount then
                for k, v in pairs(self.itemslots) do
                    if v and v.prefab == "shouna_hulu" and v.components.container then
                        local hulu_items = v.components.container:GetCraftingIngredient(item, amount - total_num_found, true)
                        for hk, hv in pairs(hulu_items) do
                            items[hk] = hv
                            total_num_found = total_num_found + hv
                        end
                    end
                    if total_num_found >= amount then break end
                end
            end
            return items
        end
    end

    local old_RemoveItem = self.RemoveItem
    function self:RemoveItem(item, wholestack, checkallcontainers, keepoverstacked)
        local removed_item = old_RemoveItem(self, item, wholestack, checkallcontainers, keepoverstacked)
        
        if removed_item == item and checkallcontainers and type(item) == "table" and item:IsValid() and item.components and item.components.inventoryitem then
            local owner = item.components.inventoryitem.owner
            if owner and owner.prefab == "shouna_hulu" and owner.components.container then
                local has_gourd = false
                for k, v in pairs(self.itemslots) do
                    if v == owner then
                        has_gourd = true
                        break
                    end
                end
                if has_gourd then
                    return owner.components.container:RemoveItem(item, wholestack, nil, keepoverstacked) or removed_item
                end
            end
        end
        return removed_item
    end
end)

-- 客户端：拦截制作配方的材料检查（依赖网络同步的数据）
AddPrefabPostInit("inventory_classified", function(inst)
    local old_Has = inst.Has
    if old_Has then
        inst.Has = function(self, prefab, amount, checkallcontainers)
            local has, count = old_Has(self, prefab, amount, checkallcontainers)
            if count >= amount or not checkallcontainers then return has, count end
            
            local items = self._itemspreview or self._items
            if items then
                for i, v in ipairs(items) do
                    local item = self._itemspreview and v or v:value()
                    if item ~= nil and item.prefab == "shouna_hulu" and item.hulu_contents ~= nil then
                        count = count + (item.hulu_contents[prefab] or 0)
                    end
                end
            end
            return count >= amount, count
        end
    end

    local old_HasItemWithTag = inst.HasItemWithTag
    if old_HasItemWithTag then
        inst.HasItemWithTag = function(self, tag, amount)
            local has, count = old_HasItemWithTag(self, tag, amount)
            return count >= amount, count
        end
    end
end)

-- 处理整理按钮的服务端逻辑。
AddModRPCHandler(RPC_NAMESPACE, "sort", function(player, container, page)
    if player ~= nil and container ~= nil and container.prefab == "shouna_hulu" and container.DoShouNaHuluSort ~= nil then
        container:DoShouNaHuluSort(player, page)
    end
end)

-- 处理回收按钮的服务端逻辑。
AddModRPCHandler(RPC_NAMESPACE, "recycle", function(player, container)
    if player ~= nil and container ~= nil and container.prefab == "shouna_hulu" and container.DoShouNaHuluRecycle ~= nil then
        container:DoShouNaHuluRecycle(player)
    end
end)

-- 处理关闭按钮的服务端逻辑。
AddModRPCHandler(RPC_NAMESPACE, "close", function(player, container)
    if player ~= nil and container ~= nil and container.prefab == "shouna_hulu" and container.DoShouNaHuluClose ~= nil then
        container:DoShouNaHuluClose(player)
    end
end)
