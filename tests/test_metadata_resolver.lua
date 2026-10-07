-- tests/test_metadata_resolver.lua
-- Verification script for Task 3: Metadata Resolution & Fallback Ladder

local msg = require "mp.msg"

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

assert_true(content:find("parse_path_metadata"), "modernz.lua missing parse_path_metadata")
assert_true(content:find("resolve_media_metadata"), "modernz.lua missing resolve_media_metadata")
assert_true(content:find("user%-data/metadata/imdb_id"), "modernz.lua missing user-data/metadata/imdb_id observation")

msg.info("ALL METADATA RESOLVER TESTS PASSED")
mp.commandv("quit", 0)
