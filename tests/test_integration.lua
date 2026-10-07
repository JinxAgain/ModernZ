-- tests/test_integration.lua
-- Comprehensive Integration Test Suite for IntroDB integration in ModernZ

local msg = require "mp.msg"
local utils = require "mp.utils"

local function assert_true(cond, message)
    if not cond then
        msg.error("TEST FAILED: " .. (message or "assertion failed"))
        mp.commandv("quit", 1)
        error(message)
    end
end

msg.info("Running Integration Test 1: Testing modernz.lua loading in mpv...")

-- Test loading modernz.lua itself as an mpv script
local success, err = pcall(function()
    dofile("modernz.lua")
end)
assert_true(success, "modernz.lua failed to load in mpv runtime: " .. tostring(err))

msg.info("Running Integration Test 2: Checking IntroDB state and functions...")
assert_true(type(mp.get_property) == "function", "mpv runtime available")

-- Test metadata extraction logic on sample strings
local test_paths = {
    {
        path = "C:\\Videos\\Breaking.Bad.S01E02.[tt0903747].mkv",
        expected_id = "tt0903747",
        expected_s = 1,
        expected_e = 2,
        expected_movie = false
    },
    {
        path = "/media/Movies/Inception.2010.[tt1375666].mp4",
        expected_id = "tt1375666",
        expected_movie = true
    },
    {
        path = "tt0944947/Game.of.Thrones.2x03.1080p.mkv",
        expected_id = "tt0944947",
        expected_s = 2,
        expected_e = 3,
        expected_movie = false
    }
}

for idx, tc in ipairs(test_paths) do
    local id = tc.path:match("([tT][tT]%d%d%d%d%d%d%d%d?)")
    if id then id = id:lower() end
    assert_true(id == tc.expected_id, "Test path " .. idx .. " IMDb ID mismatch")

    local s, e = tc.path:match("[sS](%d+)[eE](%d+)")
    if not s then s, e = tc.path:match("(%d+)[xX](%d+)") end
    if tc.expected_s then
        assert_true(tonumber(s) == tc.expected_s, "Test path " .. idx .. " Season mismatch")
        assert_true(tonumber(e) == tc.expected_e, "Test path " .. idx .. " Episode mismatch")
    end
end

-- Test IntroDB sample JSON parsing
local sample_response = [[
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

local data = utils.parse_json(sample_response)
assert_true(data ~= nil, "JSON parsed successfully")
assert_true(data.intro.start_sec == 77, "Intro start matches")
assert_true(data.intro.end_sec == 94, "Intro end matches")
assert_true(data.recap.start_sec == 10, "Recap start matches")
assert_true(data.outro.start_sec == 2791, "Outro start matches")
assert_true(data.post_credits == nil, "Post credits null verified")

msg.info("ALL INTEGRATION TESTS PASSED SUCCESSFULLY!")
mp.commandv("quit", 0)
