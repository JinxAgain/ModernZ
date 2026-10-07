-- tests/test_options.lua
-- Verification script for Task 1: Options & Localization

local msg = require "mp.msg"

local function assert_true(cond, message)
    if not cond then
        msg.error("TEST FAILED: " .. (message or "assertion failed"))
        mp.commandv("quit", 1)
        error(message)
    end
end

-- Read modernz.lua
local f = io.open("modernz.lua", "r")
assert_true(f, "modernz.lua must exist")
local content = f:read("*all")
f:close()

-- Read modernz.conf
local fc = io.open("modernz.conf", "r")
assert_true(fc, "modernz.conf must exist")
local conf_content = fc:read("*all")
fc:close()

-- 1. Check user_opts in modernz.lua
local required_opts = {
    "introdb_enable",
    "introdb_api_url",
    "introdb_auto_skip",
    "introdb_button_duration",
    "introdb_button_position",
    "introdb_show_highlights",
    "introdb_range_alpha",
    "introdb_intro_color",
    "introdb_recap_color",
    "introdb_outro_color",
    "introdb_post_credits_color",
    "introdb_guessit_fallback"
}

for _, opt in ipairs(required_opts) do
    assert_true(content:find(opt .. "%s*="), "modernz.lua missing option: " .. opt)
end

-- 2. Check modernz.conf
for _, opt in ipairs(required_opts) do
    assert_true(conf_content:find(opt .. "="), "modernz.conf missing option: " .. opt)
end

-- 3. Check localization keys in modernz.lua
local required_locales = {
    "skip_intro",
    "skip_recap",
    "skip_outro",
    "skip_post_credits",
    "skipped_segment"
}

for _, loc in ipairs(required_locales) do
    assert_true(content:find(loc .. "%s*="), "modernz.lua missing localization key: " .. loc)
end

msg.info("ALL OPTIONS AND LOCALIZATION TESTS PASSED")
mp.commandv("quit", 0)
