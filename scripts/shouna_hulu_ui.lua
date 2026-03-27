local M = {}
local ShouNaHuluContainer = require("shouna_hulu_container")
local Image = require("widgets/image")
local Text = require("widgets/text")
local InvSlot = require("widgets/invslot")
local ImageButton = require("widgets/imagebutton")
local ItemTile = require("widgets/itemtile")

-- 引入全局变量
local GLOBAL = _G or GLOBAL

local PAGE_SIZE = 80

local function ClampPage(page, pagecount)
    page = math.floor(tonumber(page) or 1)
    if page < 1 then return 1 end
    if page > pagecount then return pagecount end
    return page
end

function M.CreateContainerData(total_slots)
    return ShouNaHuluContainer.CreateContainerData(total_slots)
end

local function CreateButton(parent, label, pos, onclick)
    local button = parent:AddChild(ImageButton("images/ui.xml", "button_small.tex", "button_small_over.tex", "button_small_disabled.tex", nil, nil, { 1, 1 }, { 0, 0 }))
    button.image:SetScale(1.07)
    button.text:SetPosition(2, -2)
    button:SetPosition(pos)
    button:SetText(label)
    button:SetFont(GLOBAL.BUTTONFONT)
    button:SetDisabledFont(GLOBAL.BUTTONFONT)
    button:SetTextSize(33)
    button.text:SetVAlign(GLOBAL.ANCHOR_MIDDLE)
    button.text:SetColour(0, 0, 0, 1)
    button:SetOnClick(onclick)
    return button
end

local function GetPageCountForWidget(self, widget)
    local net_pagecount = self.container ~= nil and self.container._sh_pagecount ~= nil and self.container._sh_pagecount:value() or 0
    if net_pagecount > 0 then
        return net_pagecount
    end
    local total_slots = self.container ~= nil and self.container.replica.container:GetNumSlots() or widget.pagesize
    return math.max(1, math.ceil(total_slots / widget.pagesize))
end

local function GetVisibleSlotRange(self)
    local start_slot = ((self._sh_page or 1) - 1) * self._sh_pagesize + 1
    local total_slots = self._sh_pagecount * self._sh_pagesize
    local end_slot = math.min(start_slot + self._sh_pagesize - 1, total_slots)
    return start_slot, end_slot
end

local function UpdatePageLabel(self)
    local hide_buttons = GLOBAL.TheInput:ControllerAttached()
        or (self.container ~= nil and self.container.replica.container:IsReadOnlyContainer())

    if self._sh_page_text ~= nil then
        self._sh_page_text:SetString(string.format("%d / %d", self._sh_page, self._sh_pagecount))
    end
    if self._sh_prev_button ~= nil then
        if hide_buttons then self._sh_prev_button:Hide() else self._sh_prev_button:Show() end
        if self._sh_page > 1 then self._sh_prev_button:Enable() else self._sh_prev_button:Disable() end
    end
    if self._sh_next_button ~= nil then
        if hide_buttons then self._sh_next_button:Hide() else self._sh_next_button:Show() end
        if self._sh_page < self._sh_pagecount then self._sh_next_button:Enable() else self._sh_next_button:Disable() end
    end
    if self._sh_sort_button ~= nil then
        if hide_buttons then self._sh_sort_button:Hide() else self._sh_sort_button:Show() end
    end
    if self._sh_recycle_button ~= nil then
        if hide_buttons then self._sh_recycle_button:Hide() else self._sh_recycle_button:Show() end
    end
    if self._sh_close_button ~= nil then
        if hide_buttons then self._sh_close_button:Hide() else self._sh_close_button:Show() end
    end
end

local function UpdateVisibleSlots(self)
    local start_slot, end_slot = GetVisibleSlotRange(self)
    for i, slot in pairs(self.inv) do
        if i >= start_slot and i <= end_slot then
            slot:Show()
        else
            slot:Hide()
        end
    end
    UpdatePageLabel(self)
end

local function ChangePage(self, delta)
    if self.container == nil then return end

    local active_item = self.owner ~= nil and self.owner.replica.inventory ~= nil and self.owner.replica.inventory:GetActiveItem() or nil
    if active_item ~= nil then return end

    local new_page = ClampPage((self._sh_page or 1) + delta, self._sh_pagecount)
    if new_page == self._sh_page then return end

    self._sh_page = new_page
    UpdateVisibleSlots(self)
end

local function SendContainerRPC(namespace, name, container, page)
    if container ~= nil and container:IsValid() and container.replica.container ~= nil and not container.replica.container:IsBusy() then
        GLOBAL.SendModRPCToServer(GLOBAL.GetModRPC(namespace, name), container, page or 1)
    end
end

function M.InstallContainerWidgetPatch(namespace, AddClassPostConstruct_fn)
    AddClassPostConstruct_fn("widgets/containerwidget", function(self)
        local base_open = self.Open
        local base_close = self.Close

        local function IsShouNaHulu(widget)
            return widget ~= nil and widget.shouna_hulu == true
        end

        local function BuildCustomControls(widget)
            self._sh_page_text = self:AddChild(Text(GLOBAL.BUTTONFONT, 34, "1 / 1"))
            self._sh_page_text:SetPosition(widget.page_text_pos)

            self._sh_prev_button = CreateButton(self, "<", widget.page_prev_pos, function() ChangePage(self, -1) end)
            self._sh_next_button = CreateButton(self, ">", widget.page_next_pos, function() ChangePage(self, 1) end)
            self._sh_sort_button = CreateButton(self, "整理", widget.sort_pos, function() SendContainerRPC(namespace, "sort", self.container, self._sh_page) end)
            self._sh_recycle_button = CreateButton(self, "回收", widget.recycle_pos, function() SendContainerRPC(namespace, "recycle", self.container, self._sh_page) end)
            self._sh_close_button = CreateButton(self, "关闭", widget.close_pos, function() SendContainerRPC(namespace, "close", self.container, self._sh_page) end)
        end

        local function ClearCustomControls()
            if self._sh_page_text ~= nil then self._sh_page_text:Kill() self._sh_page_text = nil end
            if self._sh_prev_button ~= nil then self._sh_prev_button:Kill() self._sh_prev_button = nil end
            if self._sh_next_button ~= nil then self._sh_next_button:Kill() self._sh_next_button = nil end
            if self._sh_sort_button ~= nil then self._sh_sort_button:Kill() self._sh_sort_button = nil end
            if self._sh_recycle_button ~= nil then self._sh_recycle_button:Kill() self._sh_recycle_button = nil end
            if self._sh_close_button ~= nil then self._sh_close_button:Kill() self._sh_close_button = nil end
            self._sh_pagesize = nil
            self._sh_page = nil
            self._sh_pagecount = nil
            self._sh_pagecountdirtyfn = nil
        end

        function self:Open(container, doer)
            local widget = container.replica.container:GetWidget()
            
            -- MUST CALL BASE FIRST
            base_open(self, container, doer)

            if not IsShouNaHulu(widget) then
                return
            end

            -- Ensure background scale is applied
            if widget.bgscale ~= nil then
                self.bganim:SetScale(widget.bgscale.x, widget.bgscale.y, widget.bgscale.z)
            end

            self._sh_pagesize = widget.pagesize or PAGE_SIZE
            self._sh_pagecount = GetPageCountForWidget(self, widget)
            self._sh_page = 1

            BuildCustomControls(widget)
            UpdateVisibleSlots(self)

            self._sh_pagecountdirtyfn = function()
                local new_pagecount = GetPageCountForWidget(self, widget)
                if new_pagecount ~= self._sh_pagecount then
                    self._sh_pagecount = new_pagecount
                    self._sh_page = ClampPage(self._sh_page, self._sh_pagecount)
                    UpdateVisibleSlots(self)
                else
                    UpdatePageLabel(self)
                end
            end
            self.inst:ListenForEvent("shouna_hulu_pagecountdirty", self._sh_pagecountdirtyfn, container)
        end

        function self:Close()
            local widget = self.container ~= nil and self.container.replica.container:GetWidget() or nil
            
            if self.isopen and IsShouNaHulu(widget) then
                if self.container ~= nil and self._sh_pagecountdirtyfn ~= nil then
                    self.inst:RemoveEventCallback("shouna_hulu_pagecountdirty", self._sh_pagecountdirtyfn, self.container)
                end
                ClearCustomControls()
            end

            base_close(self)
        end
    end)
end

return M
