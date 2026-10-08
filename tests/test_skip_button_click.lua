-- tests/test_skip_button_click.lua
-- Reproduction & verification test for Skip button mouse clickability

local msg = require "mp.msg"

local function assert_true(cond, message)
    if not cond then
        msg.error("TEST FAILED: " .. (message or "assertion failed"))
        mp.commandv("quit", 1)
        error(message)
    end
end

-- Capture mouse areas and keybindings
local mouse_areas = {}
local registered_bindings = {}
local enabled_bindings = {}

local orig_set_mouse_area = mp.set_mouse_area
mp.set_mouse_area = function(x0, y0, x1, y1, name)
    mouse_areas[name] = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
    if orig_set_mouse_area then
        orig_set_mouse_area(x0, y0, x1, y1, name)
    end
end

local orig_set_key_bindings = mp.set_key_bindings
mp.set_key_bindings = function(bindings, name, flags)
    registered_bindings[name] = bindings
    if orig_set_key_bindings then
        orig_set_key_bindings(bindings, name, flags)
    end
end

local orig_enable_key_bindings = mp.enable_key_bindings
mp.enable_key_bindings = function(name, flags)
    enabled_bindings[name] = true
    if orig_enable_key_bindings then
        orig_enable_key_bindings(name, flags)
    end
end

local orig_disable_key_bindings = mp.disable_key_bindings
mp.disable_key_bindings = function(name)
    enabled_bindings[name] = false
    if orig_disable_key_bindings then
        orig_disable_key_bindings(name)
    end
end

-- Track commands like seek
local executed_commands = {}
local orig_commandv = mp.commandv
mp.commandv = function(...)
    local args = {...}
    table.insert(executed_commands, args)
    if orig_commandv and args[1] == "quit" then
        orig_commandv(...)
    end
end

-- Mock mouse pos for test simulation
local mock_mouse_x, mock_mouse_y = 1000, 650
mp.get_mouse_pos = function()
    return mock_mouse_x, mock_mouse_y
end

-- Read modernz.lua and expose test table
local f = io.open("modernz.lua", "r")
assert_true(f, "modernz.lua must exist")
local content = f:read("*all")
f:close()

content = content .. "\n_G._modernz_test = { state = state, osc_param = osc_param, render = render, skip_current_segment = skip_current_segment, process_event = process_event }\n"
local fn, err = (loadstring or load)(content)
assert_true(fn ~= nil, "failed to compile modernz.lua: " .. tostring(err))
fn()

local m_state = _G._modernz_test.state
local m_osc_param = _G._modernz_test.osc_param
local m_render = _G._modernz_test.render

-- Set virtual canvas size
m_osc_param.playresx = 1280
m_osc_param.playresy = 720
m_state.osd_dimensions = { w = 1280, h = 720, aspect = 1.7777 }

-- Trigger an active intro segment
m_state.introdb.segments = {
    { type = "intro", label = "Intro", start_sec = 10, end_sec = 40 }
}
m_state.introdb.active_segment = m_state.introdb.segments[1]
m_state.introdb.button_visible = true

-- Render once so capsule button is drawn and areas updated
m_render()

msg.info("Step 1: Checking if capsule hitbox exists...")
assert_true(m_state.introdb.capsule_hitbox ~= nil, "capsule_hitbox should be computed")
local hb = m_state.introdb.capsule_hitbox
msg.info(string.format("Capsule hitbox: x1=%.1f, y1=%.1f, x2=%.1f, y2=%.1f", hb.x1, hb.y1, hb.x2, hb.y2))
assert_true(hb.x1 > 0 and hb.y1 > 0 and hb.x2 > hb.x1 and hb.y2 > hb.y1, "hitbox coordinates must be positive and valid")

-- Verify mouse area is set for introdb_button
msg.info("Step 2: Checking if introdb_button mouse area is set...")
local mb_area = mouse_areas["introdb_button"]
assert_true(mb_area ~= nil, "mouse_areas['introdb_button'] must exist")
assert_true(mb_area.x1 > mb_area.x0 and mb_area.y1 > mb_area.y0, "mouse area must have non-zero size")

-- Verify keybindings for introdb_button exist and are enabled
msg.info("Step 3: Checking if introdb_button keybindings are registered and enabled...")
local btn_bindings = registered_bindings["introdb_button"]
assert_true(btn_bindings ~= nil, "registered_bindings['introdb_button'] must exist")
assert_true(enabled_bindings["introdb_button"] == true, "introdb_button bindings must be enabled")

-- Step 4: Simulate clicking on the capsule button
msg.info("Step 4: Simulating mouse click on capsule button...")
local click_x = hb.x1 + 10
local click_y = hb.y1 + 10
mock_mouse_x = click_x
mock_mouse_y = click_y

-- Find mbtn_left handler in registered_bindings["introdb_button"]
local mbtn_up_fn, mbtn_down_fn = nil, nil
for _, b in ipairs(btn_bindings) do
    if b[1] == "mbtn_left" then
        mbtn_up_fn = b[2]
        mbtn_down_fn = b[3]
    end
end
assert_true(type(mbtn_up_fn) == "function", "mbtn_left up function must exist")
assert_true(type(mbtn_down_fn) == "function", "mbtn_left down function must exist")

-- Simulate mbtn_left down
mbtn_down_fn()
assert_true(m_state.active_introdb_click == true, "active_introdb_click should be true after mbtn_left down")

-- Simulate mbtn_left up
mbtn_up_fn()
assert_true(m_state.active_introdb_click == false, "active_introdb_click should be reset to false after up")
assert_true(m_state.introdb.active_segment == nil, "active_segment should be cleared after skip")
assert_true(m_state.introdb.button_visible == false, "button_visible should be false after skip")

-- Check if mp.commandv("seek", 40, "absolute+exact") was issued
local seek_found = false
for _, cmd in ipairs(executed_commands) do
    if cmd[1] == "seek" and cmd[2] == 40 and cmd[3] == "absolute+exact" then
        seek_found = true
        break
    end
end
assert_true(seek_found, "seek command to end_sec must be executed upon clicking skip button")

msg.info("ALL CLICK SIMULATION TESTS PASSED!")
mp.commandv("quit", 0)
