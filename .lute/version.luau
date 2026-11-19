--!strict

-- Checks that every file holding the library version agrees
-- Usage (from repo root): lute run .lute/version.luau [expected version]
-- With an expected version (for example 1.2.3), also checks that the files
-- hold that version and that no `@since [UNRELEASED]` or
-- `@deprecated [UNRELEASED]` tags are left in src, which is run before tagging a
-- release
-- by @vuppyan

local fs = require("@std/fs")
local process = require("@std/process")

-- { file, pattern capturing the version }
local SOURCES: { { string } } = {
    { "src/luautils/init.luau", 'Luautils%.VERSION%s*=%s*"([^"]+)"' },
    { "wally.toml", '\nversion%s*=%s*"([^"]+)"' },
    { "pesde.toml", '\nversion%s*=%s*"([^"]+)"' },
    -- first numbered heading is the latest release; UNRELEASED never matches
    { "CHANGELOG.md", "\n## %[v?(%d+%.%d+%.%d+[^%]]*)%]" },
}

-- docs tags for API added or deprecated since the last release, replaced with
-- the version when releasing
local UNRELEASED_TAGS = { "@since", "@deprecated" }
local SRC_DIR = "src"

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

-- process.args[1] is this script's path
local argument: string? = process.args[2]
if argument ~= nil then
    -- accept both 1.2.3 and v1.2.3
    argument = string.gsub(argument, "^v", "")
end
local expected = argument or found[1][2]
local ok = true
for _, entry in found do
    print(`Found {entry[1]}: {entry[2]}`)
    if entry[2] ~= expected then
        ok = false
    end
end

if not ok then
    if argument ~= nil then
        print(`Version mismatch: expected {expected} in every file`)
    else
        print("Version mismatch: bump every file together")
    end
    process.exit(1)
end

local function luauFiles(directory: string, files: { string })
    for _, entry in fs.listDirectory(directory) do
        local path = `{directory}/{entry.name}`
        if entry.type == "dir" then
            luauFiles(path, files)
        elseif entry.type == "file" and string.match(entry.name, "%.luau$") then
            table.insert(files, path)
        end
    end
end

-- only checked for a release, since feature branches add these tags
if argument ~= nil then
    local files: { string } = {}
    luauFiles(SRC_DIR, files)
    table.sort(files)

    local leftover = 0
    for _, path in files do
        local lines = string.split(fs.readFileToString(path), "\n")
        for lineNumber, line in lines do
            for _, tag in UNRELEASED_TAGS do
                if string.find(line, `{tag} [UNRELEASED]`, 1, true) then
                    print(`{path}:{lineNumber}: {tag} [UNRELEASED]`)
                    leftover += 1
                end
            end
        end
    end

    if leftover > 0 then
        print(
            `Found {leftover} [UNRELEASED] tags: replace them with v{expected}`
        )
        process.exit(1)
    end
end
