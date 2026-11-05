--!strict

-- Checks that every file holding the library version agrees
-- by @vuppyan

local fs = require("@std/fs")
local process = require("@std/process")

-- { file, pattern capturing the version }
local SOURCES: { { string } } = {
    { "src/luautils/init.luau", 'Luautils%.VERSION%s*=%s*"([^"]+)"' },
    { "wally.toml", '\nversion%s*=%s*"([^"]+)"' },
    { "pesde.toml", '\nversion%s*=%s*"([^"]+)"' },
    -- first numbered heading is the latest release; Unreleased never matches
    { "CHANGELOG.md", "\n## %[v?(%d+%.%d+%.%d+[^%]]*)%]" },
}

local found: { { string } } = {}
for _, source in SOURCES do
    local path, pattern = source[1], source[2]
    local version = string.match(fs.readFileToString(path), pattern)
    if version == nil then
        print(`Could not find a version in {path}`)
        process.exit(1)
    end
    table.insert(found, { path, version })
end

local expected = found[1][2]
local ok = true
for _, entry in found do
    print(`Found {entry[1]}: {entry[2]}`)
    if entry[2] ~= expected then
        ok = false
    end
end

if not ok then
    print("Version mismatch: bump every file together")
    process.exit(1)
end
