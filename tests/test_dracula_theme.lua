-- tests/test_dracula_theme.lua
-- Verification test for Dracula Theme configuration

local msg = require "mp.msg"

local function assert_true(cond, message)
    if not cond then
        msg.error("TEST FAILED: " .. (message or "assertion failed"))
        mp.commandv("quit", 1)
        error(message)
    end
end

-- 1. Verify modernz-dracula.conf exists
local f = io.open("modernz-dracula.conf", "r")
assert_true(f ~= nil, "modernz-dracula.conf must exist")
local content = f:read("*all")
f:close()

-- 2. Verify themes/dracula.conf exists
local ft = io.open("themes/dracula.conf", "r")
assert_true(ft ~= nil, "themes/dracula.conf must exist")
local themes_content = ft:read("*all")
ft:close()

-- 3. Verify Dracula Theme color mappings
local expected_colors = {
    osc_color = "#282A36",
    window_title_color = "#F8F8F2",
    window_controls_color = "#F8F8F2",
    windowcontrols_close_hover = "#FF5555",
    windowcontrols_max_hover = "#50FA7B",
    windowcontrols_min_hover = "#F1FA8C",
    title_color = "#F8F8F2",
    cache_info_color = "#6272A4",
    seekbar_cache_color = "#6272A4",
    seekbarfg_color = "#BD93F9",
    seekbarbg_color = "#44475A",
    seek_handle_color = "#FF79C6",
    seek_handle_border_color = "#BD93F9",
    time_color = "#F8F8F2",
    chapter_title_color = "#8BE9FD",
    side_buttons_color = "#F8F8F2",
    middle_buttons_color = "#F8F8F2",
    playpause_color = "#50FA7B",
    held_element_color = "#6272A4",
    hover_effect_color = "#FF79C6",
    thumbnail_box_color = "#21222C",
    thumbnail_box_outline = "#44475A",
    nibble_color = "#FF79C6",
    nibble_current_color = "#50FA7B",
    ab_loop_color = "#8BE9FD",
    introdb_intro_color = "#50FA7B",
    introdb_recap_color = "#8BE9FD",
    introdb_outro_color = "#FFB86C",
    introdb_post_credits_color = "#FF79C6"
}

for opt, color in pairs(expected_colors) do
    local pattern = opt .. "%s*=%s*" .. color:gsub("%-", "%%-")
    assert_true(content:find(pattern) ~= nil, "modernz-dracula.conf missing or wrong " .. opt .. "=" .. color)
    assert_true(themes_content:find(pattern) ~= nil, "themes/dracula.conf missing or wrong " .. opt .. "=" .. color)
end

msg.info("ALL DRACULA THEME TESTS PASSED!")
mp.commandv("quit", 0)
