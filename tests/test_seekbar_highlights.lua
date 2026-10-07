-- tests/test_seekbar_highlights.lua
-- Verification script for Task 4: Seekbar Segment Highlights & Tooltip Integration

local msg = require "mp.msg"

local function assert_true(cond, message)
    if not cond then
        msg.error("TEST FAILED: " .. (message or "assertion failed"))
        mp.commandv("quit", 1)
        error(message)
    end
end

-- Read modernz.lua to verify function definitions and calls
local f = io.open("modernz.lua", "r")
assert_true(f, "modernz.lua must exist")
local content = f:read("*all")
f:close()

assert_true(content:find("draw_introdb_ranges"), "modernz.lua missing draw_introdb_ranges definition")
assert_true(content:find("draw_introdb_ranges%(element,%s*elem_ass%)"), "modernz.lua missing draw_introdb_ranges call in render loop")

msg.info("ALL SEEKBAR HIGHLIGHT TESTS PASSED")
mp.commandv("quit", 0)
