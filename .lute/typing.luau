--!strict

-- Type checks the typing type function tests in tests/typing
-- Usage (from repo root): lute run .lute/typing.luau
-- by @vuppyan

-- tests/typing/valid.luau must type check with no errors.
-- Every file in tests/typing/errors must fail to type check with exactly the
-- expected errors: a `-- error: <text>` comment expects an error containing
-- `<text>` on the next line of code, and any other error fails the check.

local fs = require("@std/fs")
local process = require("@std/process")

local VALID_FILE = "tests/typing/valid.luau"
local ERRORS_DIR = "tests/typing/errors"

type Expectation = {
    line: number,
    text: string,
    found: boolean,
}

type Diagnostic = {
    line: number,
    message: string,
}

local function analyze(path: string, stdio: process.StdioKind?)
    -- src is ignored since it is checked separately with ROBLOX globals
    return process.run({
        "luau-lsp",
        "analyze",
        "--platform=standard",
        "--flag:LuauSolverV2=true",
        "--ignore=src/**",
        path,
    }, { stdio = stdio })
end

-- reads the `-- error: <text>` comments in `source`, each expecting an error
-- on the next line of code
local function readExpectations(source: string): { Expectation }
    local expectations: { Expectation } = {}
    local pending: { string } = {}

    local lineNumber = 0
    for line in string.gmatch(source .. "\n", "([^\n]*)\n") do
        lineNumber += 1
        line = string.gsub(line, "\r$", "")

        local text = string.match(line, "^%s*%-%-%s*error:%s*(.-)%s*$")
        if text then
            table.insert(pending, text)
        elseif string.match(line, "^%s*$") == nil then
            for _, pendingText in pending do
                table.insert(
                    expectations,
                    { line = lineNumber, text = pendingText, found = false }
                )
            end
            table.clear(pending)
        end
    end

    if #pending > 0 then
        error(`"-- error:" comment with no code after it`, 0)
    end
    return expectations
end

-- reads `file(line,col): Kind: message` diagnostics from analyzer output
local function readDiagnostics(output: string): { Diagnostic }
    local diagnostics: { Diagnostic } = {}
    for line in string.gmatch(output, "[^\r\n]+") do
        local lineNumber, message =
            string.match(line, "%((%d+),%d+%): %a+: (.*)$")
        if lineNumber and message then
            table.insert(
                diagnostics,
                { line = tonumber(lineNumber) :: number, message = message }
            )
        end
    end
    return diagnostics
end

-- returns a list of problems with the errors in `path`
local function checkErrorsFile(path: string): { string }
    local expectations = readExpectations(fs.readFileToString(path))
    local result = analyze(path)
    local diagnostics = readDiagnostics(result.stdout .. "\n" .. result.stderr)

    local problems: { string } = {}
    if #expectations == 0 then
        table.insert(problems, `{path}: no "-- error:" comments`)
    end

    for _, diagnostic in diagnostics do
        local expected = false
        for _, expectation in expectations do
            if
                expectation.line == diagnostic.line
                and string.find(diagnostic.message, expectation.text, 1, true)
            then
                expectation.found = true
                expected = true
            end
        end
        if not expected then
            table.insert(
                problems,
                `{path}:{diagnostic.line}: unexpected error: {diagnostic.message}`
            )
        end
    end

    for _, expectation in expectations do
        if not expectation.found then
            table.insert(
                problems,
                `{path}:{expectation.line}: missing error: {expectation.text}`
            )
        end
    end

    return problems
end

local failed = false

print(`--- {VALID_FILE}`)
if not analyze(VALID_FILE, "inherit").ok then
    print(`{VALID_FILE} failed to type check`)
    failed = true
end

local errorFiles: { string } = {}
for _, entry in fs.listDirectory(ERRORS_DIR) do
    if entry.type == "file" and string.match(entry.name, "%.luau$") then
        table.insert(errorFiles, `{ERRORS_DIR}/{entry.name}`)
    end
end
table.sort(errorFiles)

for _, path in errorFiles do
    print(`--- {path}`)
    local problems = checkErrorsFile(path)
    for _, problem in problems do
        print(problem)
    end
    if #problems > 0 then
        failed = true
    end
end

if failed then
    process.exit(1)
end
print("All typing checks passed.")
