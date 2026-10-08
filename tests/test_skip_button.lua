-- tests/test_skip_button.lua
-- Verification script for Task 5: Floating Skip Capsule Button & Hotkey

local msg = require "mp.msg"

local function assert_true(cond, message)
    if not cond then
        msg.error("TEST FAILED: " .. (message or "assertion failed"))
        mp.commandv("quit", 1)
        error(message)
    end
end

-- Read modernz.lua to verify function definitions and bindings
local f = io.open("modernz.lua", "r")
assert_true(f, "modernz.lua must exist")
local content = f:read("*all")
f:close()

assert_true(content:find("draw_skip_capsule_button"), "modernz.lua missing draw_skip_capsule_button")
assert_true(content:find("check_introdb_segment_tick"), "modernz.lua missing check_introdb_segment_tick")
assert_true(content:find("introdb%-skip"), "modernz.lua missing introdb-skip script-binding")
assert_true(content:find('"introdb_button"'), 'modernz.lua missing "introdb_button" keybindings section')

msg.info("ALL SKIP BUTTON TESTS PASSED")
mp.commandv("quit", 0)
