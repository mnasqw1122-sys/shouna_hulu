local M = {}

local PAGE_SIZE = 80
local SLOT_SPACING = 75
local SLOT_COLUMNS = 10
local SLOT_ROWS = 8

local function BuildPageSlotPositions()
    local V3 = Vector3 or (GLOBAL and GLOBAL.Vector3)
    local slotpos = {}
    local start_x = -((SLOT_COLUMNS - 1) * SLOT_SPACING) * 0.5
    local start_y = ((SLOT_ROWS - 1) * SLOT_SPACING) * 0.5

    for row = 0, SLOT_ROWS - 1 do
        for col = 0, SLOT_COLUMNS - 1 do
            slotpos[#slotpos + 1] = V3(start_x + SLOT_SPACING * col, start_y - SLOT_SPACING * row, 0)
        end
    end

    return slotpos
end

local function BuildAllSlotPositions(total_slots, page_slotpos)
    local slotpos = {}
    local visible_count = #page_slotpos
    for i = 1, total_slots do
        slotpos[i] = page_slotpos[((i - 1) % visible_count) + 1]
    end
    return slotpos
end

-- 构造收纳葫芦专用容器定义，供服务端和客户端共用。
function M.CreateContainerData(total_slots)
    local V3 = Vector3 or (GLOBAL and GLOBAL.Vector3)
    local page_slotpos = BuildPageSlotPositions()
    return {
        widget =
        {
            slotpos = BuildAllSlotPositions(total_slots, page_slotpos),
            page_slotpos = page_slotpos,
            pagesize = PAGE_SIZE,
            paginated = true,
            shouna_hulu = true,
            animbank = "ui_fish_box_5x4",
            animbuild = "ui_fish_box_5x4",
            bgscale = V3(2.35, 2.2, 1),
            pos = V3(0, 120, 0),
            page_prev_pos = V3(-115, 355, 0),
            page_next_pos = V3(115, 355, 0),
            page_text_pos = V3(0, 355, 0),
            sort_pos = V3(-180, -360, 0),
            recycle_pos = V3(0, -360, 0),
            close_pos = V3(180, -360, 0),
        },
        type = "shouna_hulu",
        openlimit = 1,
        acceptsstacks = true,
        itemtestfn = function(container, item)
            return item ~= nil
                and not item:HasTag("shouna_hulu_item")
                and not item:HasTag("backpack")
                and not item:HasTag("portablestorage")
                and not item:HasTag("bundle")
        end,
    }
end

return M
