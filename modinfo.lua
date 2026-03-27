name = "收纳葫芦"
description = "支持分页的大容量便携收纳容器，右键即可打开。"
author = "liuan"
version = "0.2.1"
forumthread = ""
icon_atlas = "modicon.xml"
icon = "modicon.tex"
api_version = 10
dst_compatible = true
dont_starve_compatible = false
all_clients_require_mod = true
client_only_mod = false
server_filter_tags = { "container", "storage", "portable" }

local NUMBER_OPTIONS =
{
    { description = "0", data = 0 },
    { description = "1", data = 1 },
    { description = "2", data = 2 },
    { description = "3", data = 3 },
    { description = "4", data = 4 },
    { description = "5", data = 5 },
    { description = "6", data = 6 },
    { description = "7", data = 7 },
    { description = "8", data = 8 },
    { description = "9", data = 9 },
    { description = "10", data = 10 },
    { description = "11", data = 11 },
    { description = "12", data = 12 },
    { description = "13", data = 13 },
    { description = "14", data = 14 },
    { description = "15", data = 15 },
    { description = "16", data = 16 },
    { description = "17", data = 17 },
    { description = "18", data = 18 },
    { description = "19", data = 19 },
    { description = "20", data = 20 },
}

configuration_options =
{
    {
        name = "page_count",
        label = "页数",
        hover = "每页固定 80 格，总容量 = 页数 × 80。",
        options =
        {
            { description = "1 页（80 格）", data = 1 },
            { description = "2 页（160 格）", data = 2 },
            { description = "3 页（240 格）", data = 3 },
            { description = "4 页（320 格）", data = 4 },
            { description = "5 页（400 格）", data = 5 },
            { description = "6 页（480 格）", data = 6 },
            { description = "7 页（560 格）", data = 7 },
            { description = "8 页（640 格）", data = 8 },
        },
        default = 5,
    },
    {
        name = "recipe_mode",
        label = "制作方式",
        hover = "可免费制作，或按下方材料配置制作。",
        options =
        {
            { description = "按材料制作", data = "custom" },
            { description = "免费制作", data = "free" },
        },
        default = "custom",
    },
    {
        name = "recipe_gold",
        label = "金块需求",
        hover = "按材料制作时生效；如果所有材料都设为 0，会自动至少保留 1 个金块。",
        options = NUMBER_OPTIONS,
        default = 1,
    },
    {
        name = "recipe_boards",
        label = "木板需求",
        hover = "按材料制作时生效。",
        options = NUMBER_OPTIONS,
        default = 2,
    },
    {
        name = "recipe_cutstone",
        label = "石砖需求",
        hover = "按材料制作时生效。",
        options = NUMBER_OPTIONS,
        default = 1,
    },
    {
        name = "recipe_papyrus",
        label = "莎草纸需求",
        hover = "按材料制作时生效。",
        options = NUMBER_OPTIONS,
        default = 0,
    },
    {
        name = "recipe_rope",
        label = "绳子需求",
        hover = "按材料制作时生效。",
        options = NUMBER_OPTIONS,
        default = 0,
    },
}
