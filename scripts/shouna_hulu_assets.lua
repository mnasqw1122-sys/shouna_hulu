local M = {}

local CUSTOM_IMAGE_NAME = "shouna_hulu.tex"
local CUSTOM_ATLAS_PATH = "images/inventoryimages/shouna_hulu.xml"
local CUSTOM_TEX_PATH = "images/inventoryimages/shouna_hulu.tex"
local CUSTOM_ANIM_PATH = "anim/shouna_hulu.zip"

local FALLBACK_IMAGE_NAME = "beargerfur_sack.tex"
local FALLBACK_OPEN_IMAGE_NAME = "beargerfur_sack_open"
local FALLBACK_ANIM_BUILD = "beargerfur_sack"

local function FileExists(path)
    local fn = softresolvefilepath or (GLOBAL and GLOBAL.softresolvefilepath)
    return fn ~= nil and fn(path) ~= nil
end

-- 判断是否已放入自定义物品栏图标成品资源。
function M.HasCustomInventoryImage()
    return FileExists(CUSTOM_ATLAS_PATH) and FileExists(CUSTOM_TEX_PATH)
end

-- 返回收纳葫芦当前应使用的图标名。
function M.GetInventoryImageName()
    return M.HasCustomInventoryImage() and CUSTOM_IMAGE_NAME or FALLBACK_IMAGE_NAME
end

-- 返回收纳葫芦打开时应使用的背包图标名；自定义图标未区分开合时复用同一张。
function M.GetOpenInventoryImageName()
    if M.HasCustomInventoryImage() then
        return CUSTOM_IMAGE_NAME
    end
    return FALLBACK_OPEN_IMAGE_NAME .. ".tex"
end

-- 返回收纳葫芦当前应使用的图标图集路径。
function M.GetInventoryAtlasPath()
    if M.HasCustomInventoryImage() then
        return CUSTOM_ATLAS_PATH
    end
    return GetInventoryItemAtlas ~= nil and GetInventoryItemAtlas(FALLBACK_IMAGE_NAME) or nil
end

-- 判断是否已放入自定义动画包。
function M.HasCustomAnim()
    return FileExists(CUSTOM_ANIM_PATH)
end

-- 返回当前应使用的动画 bank/build 名。
function M.GetAnimBuildName()
    return M.HasCustomAnim() and "shouna_hulu" or FALLBACK_ANIM_BUILD
end

-- 生成 prefab 需要声明的资源列表，并在存在自定义图标时自动追加图集资源。
function M.BuildPrefabAssets(base_assets)
    local assets = {}

    for _, asset in ipairs(base_assets) do
        table.insert(assets, asset)
    end

    if M.HasCustomAnim() then
        table.insert(assets, Asset("ANIM", CUSTOM_ANIM_PATH))
    else
        table.insert(assets, Asset("ANIM", "anim/beargerfur_sack.zip"))
    end

    if M.HasCustomInventoryImage() then
        table.insert(assets, Asset("ATLAS", CUSTOM_ATLAS_PATH))
        table.insert(assets, Asset("IMAGE", CUSTOM_TEX_PATH))
        table.insert(assets, Asset("INV_IMAGE", "shouna_hulu"))
    else
        table.insert(assets, Asset("INV_IMAGE", "beargerfur_sack"))
    end

    return assets
end

-- 在自定义图集存在时注册 atlas，便于配方和背包栏直接取图。
function M.RegisterInventoryAtlas()
    if M.HasCustomInventoryImage() then
        local fn = RegisterInventoryItemAtlas or (GLOBAL and GLOBAL.RegisterInventoryItemAtlas)
        if fn ~= nil then
            fn(CUSTOM_ATLAS_PATH, CUSTOM_IMAGE_NAME)
        end
    end
end

return M
