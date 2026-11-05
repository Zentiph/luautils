--!strict

-- Runs every check that CI runs in the same order
-- Usage (from repo root): lute run .lute/ci.luau
-- by @vuppyan

local fs = require("@std/fs")
local process = require("@std/process")

type Step = {
    name: string,
    args: { string },
}

-- ROBLOX type definitions are downloaded for the luau-lsp version pinned in
-- rokit.toml, so they always match the type checker
-- They are cached in .cache/ (gitignored) and only downloaded when the version
-- changes
local DEFINITIONS_FILE = "globalTypes.None.d.luau"
local CACHE_DIR = ".cache"

local function luauLspVersion(): string
    local rokit = fs.readFileToString("rokit.toml")
    local version = string.match(rokit, 'luau%-lsp%s*=%s*"[^"@]*@([^"]+)"')
    if version == nil then
        error("could not find luau-lsp version in rokit.toml", 0)
    end
    return version
end

local function ensureDefinitions(): string
    local version = luauLspVersion()
    local path = `{CACHE_DIR}/globalTypes-{version}.d.luau`
    if fs.exists(path) then
        return path
    end

    local url = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/"
        .. `{version}/scripts/{DEFINITIONS_FILE}`
    print(`Downloading ROBLOX type definitions for luau-lsp {version}`)
    local result = process.run(
        { "curl", "-fsSL", "--create-dirs", "-o", path, url },
        { stdio = "inherit" }
    )
    if not result.ok then
        error(`Failed to download {url}`, 0)
    end
    return path
end

local definitions = ensureDefinitions()

-- Keep this list in sync with the CI section of CONTRIBUTING.md
-- CI runs this script, plus a separate docs job (moonwave build) that this
-- script does not cover
local STEPS: { Step } = {
    {
        name = "version",
        args = { "lute", "run", ".lute/version.luau" },
    },
    {
        name = "format",
        args = { "stylua", "--check", "src", "tests" },
    },
    {
        name = "lint",
        args = { "selene", "src" },
    },
    {
        name = "sourcemap",
        args = {
            "rojo",
            "sourcemap",
            "default.project.json",
            "-o",
            "sourcemap.json",
        },
    },
    {
        -- src uses ROBLOX globals so it is checked
        -- against ROBLOX's type definitions
        name = "typecheck (src)",
        args = {
            "luau-lsp",
            "analyze",
            "--platform=roblox",
            "--sourcemap=sourcemap.json",
            `--definitions={definitions}`,
            "--flag:LuauSolverV2=true",
            "src",
        },
    },
    {
        -- tests run under Lute, so they are checked without ROBLOX globals
        -- src is ignored since it is checked above with ROBLOX globals, and
        -- would otherwise fail here on globals like task through requires
        name = "typecheck (tests)",
        args = {
            "luau-lsp",
            "analyze",
            "--platform=standard",
            "--flag:LuauSolverV2=true",
            "--ignore=src/**",
            "tests",
        },
    },
    {
        name = "test",
        args = { "lute", "test" },
    },
}

local failed: { string } = {}

for _, step in STEPS do
    print(`\n=== {step.name} ===`)
    local result = process.run(step.args, { stdio = "inherit" })
    if not result.ok then
        print(`--- {step.name} failed (exit code {result.exitcode})`)
        table.insert(failed, step.name)
    end
end

print("")
if #failed > 0 then
    print(`FAILED: {table.concat(failed, ", ")}`)
    process.exit(1)
end
print("All checks passed.")
