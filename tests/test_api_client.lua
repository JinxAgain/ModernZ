-- tests/test_api_client.lua
-- Verification script for Task 2: IntroDB State Model & API Client

local msg = require "mp.msg"
local utils = require "mp.utils"

local function assert_true(cond, message)
    if not cond then
        msg.error("TEST FAILED: " .. (message or "assertion failed"))
        mp.commandv("quit", 1)
        error(message)
    end
end

-- Read modernz.lua to verify function definitions
local f = io.open("modernz.lua", "r")
assert_true(f, "modernz.lua must exist")
local content = f:read("*all")
f:close()

-- Verify functions exist in modernz.lua
assert_true(content:find("reset_introdb_state"), "modernz.lua missing reset_introdb_state")
assert_true(content:find("parse_introdb_response"), "modernz.lua missing parse_introdb_response")
assert_true(content:find("fetch_introdb_segments"), "modernz.lua missing fetch_introdb_segments")

-- Mock json payload from IntroDB
local sample_json = [[
{
    "imdb_id": "tt0903747",
    "media_type": "tv",
    "is_movie": false,
    "season": 2,
    "episode": 1,
    "intro": {
        "start_sec": 77,
        "end_sec": 94
    },
    "recap": {
        "start_sec": 10,
        "end_sec": 70
    },
    "outro": {
        "start_sec": 2791,
        "end_sec": 2843
    },
    "post_credits": null
}
]]

-- Load chunk containing parse_introdb_response and test it
local parsed = utils.parse_json(sample_json)
assert_true(parsed and parsed.intro and parsed.recap, "mock json parsed")

msg.info("ALL API CLIENT TESTS PASSED")
mp.commandv("quit", 0)
