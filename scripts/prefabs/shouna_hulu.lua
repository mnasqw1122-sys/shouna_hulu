local GLOBAL = _G
local json = GLOBAL.require("json")

local ShouNaHuluConfig = require("shouna_hulu_config")
local ShouNaHuluAssets = require("shouna_hulu_assets")
local ShouNaHuluContainer = require("shouna_hulu_container")

local base_assets =
{
    GLOBAL.Asset("ANIM", "anim/ui_fish_box_5x4.zip"),
    GLOBAL.Asset("INV_IMAGE", "beargerfur_sack_open"),
}

local assets = ShouNaHuluAssets.BuildPrefabAssets(base_assets)

local RECYCLE_RADIUS = 6

local function BuildFloatableSwapData()
    return { bank = ShouNaHuluAssets.GetAnimBuildName(), anim = "closed" }
end

local function UpdateSyncData(inst)
    if not GLOBAL.TheWorld.ismastersim then return end
    if not inst.components.container then return end
    
    local contents = {}
    for k, v in pairs(inst.components.container.slots) do
        contents[v.prefab] = (contents[v.prefab] or 0) + (v.components.stackable and v.components.stackable:StackSize() or 1)
    end
    
    local json_str = json.encode(contents) or "{}"
    local len = string.len(json_str)
    
    for i = 1, 5 do
        local chunk = string.sub(json_str, (i-1)*250 + 1, i*250)
        if inst.sync_strings and inst.sync_strings[i] then
            inst.sync_strings[i]:set(chunk)
        end
    end
end

local function OnSyncDirty(inst)
    local json_str = ""
    for i = 1, 5 do
        if inst.sync_strings and inst.sync_strings[i] then
            json_str = json_str .. inst.sync_strings[i]:value()
        end
    end
    if json_str ~= "" then
        local success, data = pcall(json.decode, json_str)
        if success and type(data) == "table" then
            inst.hulu_contents = data
            if GLOBAL.ThePlayer ~= nil then
                GLOBAL.ThePlayer:PushEvent("refreshcrafting")
            end
        end
    end
end

local function GetStackSize(item)
    return item ~= nil and item.components.stackable ~= nil and item.components.stackable:StackSize() or 1
end

local function GetPageBounds(page, total_slots)
    local page_size = ShouNaHuluConfig.GetPageSize()
    local pagecount = math.max(1, math.ceil(total_slots / page_size))
    local current_page = math.max(1, math.min(pagecount, math.floor(tonumber(page) or 1)))
    local first_slot = (current_page - 1) * page_size + 1
    local last_slot = math.min(first_slot + page_size - 1, total_slots)
    return current_page, first_slot, last_slot
end

local function CloseForPlayer(inst, player)
    if inst ~= nil and inst.components.container ~= nil and player ~= nil and inst.components.container:IsOpenedBy(player) then
        inst.components.container:Close(player)
        player:PushEvent("closecontainer", { container = inst })
    end
end

local function RemoveOpenListeners(inst)
    if inst._sh_opener ~= nil then
        if inst._sh_newactiveitemfn ~= nil then
            inst:RemoveEventCallback("newactiveitem", inst._sh_newactiveitemfn, inst._sh_opener)
        end
    end
    inst._sh_opener = nil
    inst._sh_newactiveitemfn = nil
end

local function Announce(inst, doer, message)
    if doer ~= nil and doer.components.talker ~= nil then
        doer.components.talker:Say(message)
    end
end

local function SortItems(items)
    table.sort(items, function(left, right)
        if left.prefab ~= right.prefab then return left.prefab < right.prefab end
        local left_skin = left.skinname or ""
        local right_skin = right.skinname or ""
        if left_skin ~= right_skin then return left_skin < right_skin end
        local left_stack = GetStackSize(left)
        local right_stack = GetStackSize(right)
        if left_stack ~= right_stack then return left_stack > right_stack end
        return left.GUID < right.GUID
    end)
end

local function CanOperate(inst, doer)
    return inst ~= nil and inst:IsValid() and inst.components.container ~= nil and doer ~= nil and doer:IsValid() and doer.components.inventory ~= nil and doer.components.inventory:GetActiveItem() == nil and inst.components.container:IsOpenedBy(doer)
end

local function DoSort(inst, doer, page)
    if not CanOperate(inst, doer) then return end
    local container = inst.components.container
    local _, first_slot, last_slot = GetPageBounds(page, container:GetNumSlots())
    local items = {}

    -- 1. 取出当前页所有物品
    for slot = first_slot, last_slot do
        local item = container:RemoveItemBySlot(slot)
        if item ~= nil then table.insert(items, item) end
    end

    -- 2. 合并同类物品的堆叠
    local merged_items = {}
    for _, item in ipairs(items) do
        local merged = false
        if item.components.stackable ~= nil then
            for _, m_item in ipairs(merged_items) do
                if m_item.prefab == item.prefab and m_item.skinname == item.skinname and m_item.components.stackable ~= nil and not m_item.components.stackable:IsFull() then
                    local room = m_item.components.stackable:RoomLeft()
                    if item.components.stackable:StackSize() <= room then
                        m_item.components.stackable:Put(item)
                        merged = true
                        break
                    else
                        local split = item.components.stackable:Get(room)
                        m_item.components.stackable:Put(split)
                    end
                end
            end
        end
        if not merged then
            table.insert(merged_items, item)
        end
    end

    -- 3. 排序
    SortItems(merged_items)

    -- 4. 放回容器
    local next_slot = first_slot
    local failed_items = {}
    for _, item in ipairs(merged_items) do
        if not container:GiveItem(item, next_slot, nil, false) then table.insert(failed_items, item) end
        next_slot = next_slot + 1
    end

    -- 5. 处理放不下的物品（理论上不会发生，因为只处理了当前页的物品）
    if #failed_items > 0 then
        local x, y, z = doer.Transform:GetWorldPosition()
        for _, item in ipairs(failed_items) do
            item.Transform:SetPosition(x, y, z)
            item.components.inventoryitem:OnDropped(true)
        end
        Announce(inst, doer, "部分物品无法整理，已掉落在地上")
    end
    inst:PushEvent("refresh")
end

local function IsGroundItemValid(item, inst)
    return item ~= nil and item:IsValid() and item ~= inst and item.components.inventoryitem ~= nil and item.components.inventoryitem.canbepickedup ~= false and item.components.inventoryitem:GetGrandOwner() == nil and not item:HasTag("INLIMBO") and not item:HasTag("NOCLICK") and not item:HasTag("shouna_hulu_item") and not item:HasTag("backpack") and not item:HasTag("portablestorage") and not item:HasTag("bundle")
end

local function DoRecycle(inst, doer)
    if not CanOperate(inst, doer) then return end
    local x, y, z = doer.Transform:GetWorldPosition()
    local nearby_items = GLOBAL.TheSim:FindEntities(x, y, z, RECYCLE_RADIUS, { "_inventoryitem" }, { "INLIMBO", "NOCLICK", "FX", "DECOR", "irreplaceable", "heavy" })
    local found_count = 0
    local inserted_count = 0

    for _, item in ipairs(nearby_items) do
        if IsGroundItemValid(item, inst) then
            found_count = found_count + 1
            local src_pos = item:GetPosition()
            if inst.components.container:GiveItem(item, nil, src_pos, false) then
                inserted_count = inserted_count + 1
            end
        end
    end

    if found_count == 0 then
        Announce(inst, doer, "附近没有可回收物品")
        return
    end
    if inserted_count < found_count then
        Announce(inst, doer, "葫芦已满")
    end
    inst:PushEvent("refresh")
end

local function OnOpen(inst, data)
    inst.AnimState:PlayAnimation("open", false)
    inst.components.inventoryitem:ChangeImageName(ShouNaHuluAssets.GetOpenInventoryImageName():gsub("%.tex$", ""))

    local doer = data ~= nil and data.doer or nil
    if doer == nil then return end

    RemoveOpenListeners(inst)
    inst._sh_opener = doer
    inst._sh_newactiveitemfn = function(player, payload)
        if payload ~= nil and payload.item == inst then CloseForPlayer(inst, player) end
    end
    inst:ListenForEvent("newactiveitem", inst._sh_newactiveitemfn, doer)
end

local function OnClose(inst)
    inst.AnimState:PlayAnimation("closed", false)
    inst.components.inventoryitem:ChangeImageName(ShouNaHuluAssets.GetInventoryImageName():gsub("%.tex$", ""))
    RemoveOpenListeners(inst)
end

local function OnPutInInventory(inst)
    if inst.components.container ~= nil then inst.components.container:Close() end
    inst.AnimState:PlayAnimation("closed", false)
end

local function OnDropped(inst)
    inst.AnimState:PlayAnimation("closed", false)
end

local function OnPickup(inst)
    inst.AnimState:PlayAnimation("closed", false)
end

local function OnActiveItem(inst, owner)
    CloseForPlayer(inst, owner)
end

local function fn()
    local inst = GLOBAL.CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("beargerfur_sack.png")

    inst.AnimState:SetBank(ShouNaHuluAssets.GetAnimBuildName())
    inst.AnimState:SetBuild(ShouNaHuluAssets.GetAnimBuildName())
    inst.AnimState:PlayAnimation("closed")
    
    -- 调整地面模型大小 (1.0)
    inst.Transform:SetScale(1.0, 1.0, 1.0)

    GLOBAL.MakeInventoryPhysics(inst)
    GLOBAL.MakeInventoryFloatable(inst, "small", 0.35, 1.15, nil, nil, BuildFloatableSwapData())

    inst:AddTag("portablestorage")
    inst:AddTag("shouna_hulu_item")
    inst._sh_pagecount = GLOBAL.net_tinybyte(inst.GUID, "shouna_hulu.pagecount", "shouna_hulu_pagecountdirty")
    
    inst.sync_strings = {}
    for i = 1, 5 do
        inst.sync_strings[i] = GLOBAL.net_string(inst.GUID, "shouna_hulu.sync_string_"..i, "shouna_hulu_sync_dirty")
    end
    
    if not GLOBAL.TheNet:IsDedicated() then
        inst:ListenForEvent("shouna_hulu_sync_dirty", OnSyncDirty)
    end
    
    inst.entity:SetPristine()

    if not GLOBAL.TheWorld.ismastersim then
        return inst
    end

    local total_slots = ShouNaHuluConfig.GetTotalSlots()
    local container_data = ShouNaHuluContainer.CreateContainerData(total_slots)
    inst._sh_pagecount:set(ShouNaHuluConfig.GetPageCount())

    inst:AddComponent("inspectable")
    inst:AddComponent("lootdropper")

    inst:AddComponent("container")
    inst.components.container:WidgetSetup("shouna_hulu", container_data)
    inst.components.container.onopenfn = OnOpen
    inst.components.container.onclosefn = OnClose
    inst.components.container.droponopen = true

    inst:ListenForEvent("itemget", UpdateSyncData)
    inst:ListenForEvent("itemlose", UpdateSyncData)
    inst:DoTaskInTime(0, UpdateSyncData)

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:SetOnDroppedFn(OnDropped)
    inst.components.inventoryitem:SetOnPickupFn(OnPickup)
    inst.components.inventoryitem:SetOnPutInInventoryFn(OnPutInInventory)
    inst.components.inventoryitem:SetOnActiveItemFn(OnActiveItem)
    inst.components.inventoryitem.canonlygoinpocketorpocketcontainers = false

    local inventory_atlas = ShouNaHuluAssets.GetInventoryAtlasPath()
    if inventory_atlas ~= nil then
        inst.components.inventoryitem.atlasname = inventory_atlas
    end
    inst.components.inventoryitem.imagename = ShouNaHuluAssets.GetInventoryImageName():gsub("%.tex$", "")
    inst:DoTaskInTime(0, function()
        if inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner == nil then
            OnDropped(inst)
        end
    end)

    inst.DoShouNaHuluSort = DoSort
    inst.DoShouNaHuluRecycle = DoRecycle
    inst.DoShouNaHuluClose = CloseForPlayer

    GLOBAL.MakeHauntableLaunchAndDropFirstItem(inst)

    return inst
end

return GLOBAL.Prefab("shouna_hulu", fn, assets)
