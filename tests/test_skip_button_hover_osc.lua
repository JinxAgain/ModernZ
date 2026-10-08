-- tests/test_skip_button_hover_osc.lua
-- Test that hovering/moving near Skip button does not cause OSC flickering/oscillation

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

content = content .. "\n_G._modernz_test = { state = state, user_opts = user_opts, osc_param = osc_param, render = render, process_event = process_event }\n"
local fn, err = (loadstring or load)(content)
assert_true(fn ~= nil, "failed to compile modernz.lua: " .. tostring(err))
fn()

local m_state = _G._modernz_test.state
local m_opts = _G._modernz_test.user_opts
local m_osc_param = _G._modernz_test.osc_param
local m_render = _G._modernz_test.render
local m_process_event = _G._modernz_test.process_event

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

-- Initially OSC is hidden
m_state.osc_visible = false

-- Render with OSC hidden
m_render()
assert_true(m_state.introdb.capsule_hitbox ~= nil, "capsule_hitbox must exist")
local hb_hidden = {
    x1 = m_state.introdb.capsule_hitbox.x1,
    y1 = m_state.introdb.capsule_hitbox.y1,
    x2 = m_state.introdb.capsule_hitbox.x2,
    y2 = m_state.introdb.capsule_hitbox.y2,
}

-- Render with OSC visible
m_state.osc_visible = true
m_render()
local hb_visible = {
    x1 = m_state.introdb.capsule_hitbox.x1,
    y1 = m_state.introdb.capsule_hitbox.y1,
    x2 = m_state.introdb.capsule_hitbox.x2,
    y2 = m_state.introdb.capsule_hitbox.y2,
}

-- Test 1: Button position stability (must NOT jump when OSC visibility toggles!)
msg.info("Checking Skip button position stability...")
assert_true(hb_hidden.y1 == hb_visible.y1 and hb_hidden.y2 == hb_visible.y2,
    string.format("Skip button Y position must remain stable! hidden: y1=%.1f y2=%.1f, visible: y1=%.1f y2=%.1f",
        hb_hidden.y1, hb_hidden.y2, hb_visible.y1, hb_visible.y2))

-- Test 2: Moving mouse over Skip button when OSC is hidden should NOT force OSC to open
m_state.osc_visible = false
mock_mouse_x = hb_hidden.x1 + 10
mock_mouse_y = hb_hidden.y1 + 10
m_state.last_mouseX = 0
m_state.last_mouseY = 0

m_process_event("mouse_move", nil)
assert_true(m_state.osc_visible == false, "Hovering over Skip button should not force OSC to open!")

msg.info("ALL HOVER & OSC STABILITY TESTS PASSED!")
mp.commandv("quit", 0)
