--!strict

-- Formats documentation prose: Moonwave doc comments (`--[=[ ... ]=]`) in src,
-- and the Markdown files in the repository root
-- Usage (from repo root): lute run .lute/docs.luau [--check]
-- With --check, nothing is written, and the script fails if any file would
-- change (CI runs it this way)
-- by @vuppyan

-- Paragraphs fill each line up to MAX_WIDTH columns, instead of starting each
-- sentence on a new line, and wrapped list items line up with the item's text.
-- Code blocks, tables, headings, Moonwave `@` tags, and lines ending in a hard
-- break are left as they are, and blockquotes are formatted inside the quote.
-- A wrapped line never starts with a token that Markdown or Moonwave would
-- read differently there, such as `*`, `1.`, `#`, `>`, `|`, or `@param`

local fs = require("@std/fs")
local process = require("@std/process")

local MAX_WIDTH = 80
local SRC_DIR = "src"
local MARKDOWN_FILES = { "README.md", "CONTRIBUTING.md", "CHANGELOG.md" }

-- process.args[1] is this script's path
local argument: string? = process.args[2]
if argument ~= nil and argument ~= "--check" then
    error(`unknown argument "{argument}"`, 0)
end
local checkOnly = argument == "--check"

-- whether `token` would change meaning at the start of a line
local function isRisky(token: string): boolean
    return token == "*"
        or token == "+"
        or token == "-"
        or token == ">"
        or token == "|"
        or string.match(token, "^%d+[%.%)]$") ~= nil
        or string.match(token, "^#+$") ~= nil
        or string.match(token, "^@") ~= nil
        or string.match(token, "^```") ~= nil
        or string.match(token, "^~~~") ~= nil
        or string.match(token, "^=+$") ~= nil
        or string.match(token, "^%-%-+$") ~= nil
end

-- splits text into words, keeping `code spans` that contain spaces together
local function tokenize(text: string): { string }
    local words: { string } = {}
    local current = ""
    local inCode = false
    for i = 1, #text do
        local char = string.sub(text, i, i)
        if char == "`" then
            inCode = not inCode
            current ..= char
        elseif char == " " and not inCode then
            if current ~= "" then
                table.insert(words, current)
            end
            current = ""
        else
            current ..= char
        end
    end
    if current ~= "" then
        table.insert(words, current)
    end
    return words
end

-- fills `words` into lines of at most `width` columns, starting the first
-- line with `first` and the rest with `rest`
local function fill(
    words: { string },
    first: string,
    rest: string,
    width: number
): { string }
    local lines: { string } = {}
    local current: { string } = {}
    local prefix = first
    local length = #prefix

    for _, word in words do
        if #current > 0 and length + 1 + #word > width then
            -- move the previous word down too, so a risky token never starts
            -- a line
            local carried: string? = nil
            if isRisky(word) and #current > 1 then
                carried = table.remove(current)
            end
            table.insert(lines, prefix .. table.concat(current, " "))
            prefix = rest
            current = if carried then { carried, word } else { word }
            length = #prefix + #table.concat(current, " ")
        else
            length += (if #current > 0 then 1 else 0) + #word
            table.insert(current, word)
        end
    end
    if #current > 0 then
        table.insert(lines, prefix .. table.concat(current, " "))
    end
    return lines
end

-- whether `line` must be kept as it is
local function isVerbatim(line: string): boolean
    local text = string.gsub(line, "^%s+", "")
    return string.match(text, "^[@|#<]") ~= nil
        or string.match(text, "^```") ~= nil
        or string.match(text, "^~~~") ~= nil
        or string.match(text, "^%[[^%]]+%]:%s") ~= nil
        or string.match(text, "^%-%-%-+%s*$") ~= nil
        or string.match(text, "^%*%*%*+%s*$") ~= nil
        or string.match(text, "^___+%s*$") ~= nil
        or string.match(line, "  $") ~= nil
        or string.match(line, "\\$") ~= nil
end

local LIST_ITEM_PATTERNS = {
    "^(%s*)([%*%+%-]%s+)(.*)$",
    "^(%s*)(%d+[%.%)]%s+)(.*)$",
}

-- the indent, marker with its spacing, and text of a list item line
local function matchListItem(line: string): (string?, string?, string?)
    for _, pattern in LIST_ITEM_PATTERNS do
        local indent, marker, text = string.match(line, pattern)
        if indent ~= nil then
            return indent, marker, text
        end
    end
    return nil, nil, nil
end

-- formats `lines`, which have no shared indent, to `width` columns
local function format(lines: { string }, width: number): { string }
    local out: { string } = {}
    local words: { string } = {}
    local first, rest = "", ""
    local fence: string? = nil

    local function flush()
        if #words > 0 then
            for _, line in fill(words, first, rest, width) do
                table.insert(out, line)
            end
            words = {}
        end
    end

    local i = 1
    while i <= #lines do
        local line = lines[i]
        local trimmed = string.gsub(line, "^%s+", "")
        trimmed = string.gsub(trimmed, "%s+$", "")

        if fence ~= nil then
            table.insert(out, line)
            if trimmed == fence then
                fence = nil
            end
            i += 1
        elseif
            string.match(trimmed, "^```") or string.match(trimmed, "^~~~")
        then
            flush()
            fence = string.match(trimmed, "^([`~]+)")
            table.insert(out, line)
            i += 1
        elseif trimmed == "" then
            flush()
            table.insert(out, "")
            i += 1
        elseif string.match(line, "^%s*>") then
            -- blockquote: format its contents, then quote them again
            flush()
            local indent = string.match(line, "^(%s*)") :: string
            local inner: { string } = {}
            while i <= #lines do
                local quoted = lines[i]
                if
                    string.sub(quoted, 1, #indent) ~= indent
                    or string.sub(quoted, #indent + 1, #indent + 1) ~= ">"
                then
                    break
                end
                local content = string.sub(quoted, #indent + 2)
                content = string.gsub(content, "^ ", "")
                table.insert(inner, content)
                i += 1
            end
            for _, quotedLine in format(inner, width - #indent - 2) do
                table.insert(
                    out,
                    if quotedLine == ""
                        then `{indent}>`
                        else `{indent}> {quotedLine}`
                )
            end
        elseif isVerbatim(line) then
            flush()
            table.insert(out, line)
            i += 1
        else
            local indent, marker, text = matchListItem(line)
            if indent ~= nil and marker ~= nil and text ~= nil then
                -- list item: wrapped lines line up with the item's text
                flush()
                first = indent .. marker
                rest = string.rep(" ", #first)
                words = tokenize(text)
            else
                if #words == 0 then
                    -- paragraph: keeps its own indent
                    local own = string.match(line, "^(%s*)") :: string
                    first, rest = own, own
                end
                for _, word in tokenize(trimmed) do
                    table.insert(words, word)
                end
            end
            i += 1
        end
    end
    flush()
    return out
end

-- formats every `--[=[ ... ]=]` block in a Luau file
local function formatLuau(lines: { string }): { string }
    local out: { string } = {}
    local i = 1
    while i <= #lines do
        local line = lines[i]
        table.insert(out, line)
        i += 1
        if string.match(line, "%-%-%[=%[%s*$") then
            local block: { string } = {}
            while i <= #lines and not string.match(lines[i], "^%s*%]=%]") do
                table.insert(block, lines[i])
                i += 1
            end

            -- the block's shared indent
            local shared: number? = nil
            for _, blockLine in block do
                if string.match(blockLine, "%S") then
                    local indent = #(string.match(blockLine, "^( *)") :: string)
                    if shared == nil or indent < shared then
                        shared = indent
                    end
                end
            end
            local indent = string.rep(" ", shared or 0)

            local inner: { string } = {}
            for _, blockLine in block do
                table.insert(
                    inner,
                    if string.match(blockLine, "%S")
                        then string.sub(blockLine, #indent + 1)
                        else ""
                )
            end
            for _, formatted in format(inner, MAX_WIDTH - #indent) do
                table.insert(
                    out,
                    if formatted == "" then "" else indent .. formatted
                )
            end
        end
    end
    return out
end

local function splitLines(contents: string): { string }
    contents = string.gsub(contents, "\r\n", "\n")
    local lines: { string } = {}
    for line in string.gmatch(contents, "([^\n]*)\n") do
        table.insert(lines, line)
    end
    -- a last line with no newline after it
    local last = string.match(contents, "([^\n]+)$")
    if last ~= nil then
        table.insert(lines, last)
    end
    return lines
end

local function luauFiles(directory: string, found: { string })
    for _, entry in fs.listDirectory(directory) do
        local path = `{directory}/{entry.name}`
        if entry.type == "dir" then
            luauFiles(path, found)
        elseif entry.type == "file" and string.match(entry.name, "%.luau$") then
            table.insert(found, path)
        end
    end
end

local files: { string } = table.clone(MARKDOWN_FILES)
luauFiles(SRC_DIR, files)
table.sort(files)

local changed: { string } = {}
for _, path in files do
    local original = fs.readFileToString(path)
    local lines = splitLines(original)
    local formatted = if string.match(path, "%.md$")
        then format(lines, MAX_WIDTH)
        else formatLuau(lines)
    local result = table.concat(formatted, "\n") .. "\n"

    if result ~= string.gsub(original, "\r\n", "\n") then
        table.insert(changed, path)
        if not checkOnly then
            fs.writeStringToFile(path, result)
        end
    end
end

if checkOnly then
    if #changed > 0 then
        print("Docs need formatting (run `lute run .lute/docs.luau`):")
        for _, path in changed do
            print(`  {path}`)
        end
        process.exit(1)
    end
    print("Docs are formatted.")
else
    for _, path in changed do
        print(`Formatted {path}`)
    end
    print(`{#changed} file(s) formatted.`)
end
