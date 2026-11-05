# Contributing to luautils

## Setup

All commands are run from the repository root.

1. Install the pinned tools from `rokit.toml`:

```bash
rokit install
```

2. Generate Lute's `@std` and `@lute` type definitions, which `.luaurc` points
   to and the type checker needs for the test files:

```bash
lute setup
```

The first run of `lute run .lute/ci.luau` downloads ROBLOX's type definitions
(see ROBLOX type definitions), so it needs internet connection once.

## Development commands

```bash
# pull the latest changes without leaving stray merge commits
# master only changes through pull requests, so local master should only
# fast-forward
git pull --ff-only
# or set it once in your config
git config pull.ff only
```

```bash
# run every CI check
lute run .lute/ci.luau
```

```bash
# run the whole test suite (discovers every *.test.luau file under tests/)
lute test

# run a single test file
lute test tests/Core/Result.test.luau
```

```bash
# check formatting, then fix it
stylua --check src tests
stylua src tests
```

```bash
# lint (selene.toml uses the roblox std, so only src is linted)
selene src
```

```bash
# type check src against ROBLOX's definitions, and tests without them
# (run the CI script once first, so .cache/ holds the definitions)
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze \
    --platform=roblox \
    --sourcemap=sourcemap.json \
    --definitions=.cache/globalTypes-<luau-lsp version>.d.luau \
    --flag:LuauSolverV2=true \
    src
luau-lsp analyze \
    --platform=standard \
    --flag:LuauSolverV2=true \
    --ignore="src/**" \
    tests
```

`--flag:LuauSolverV2=true` is required.
Without it, `luau-lsp analyze` uses the old type solver, which reports false
errors for this library.

```bash
# preview the documentation locally, or build it into build/
moonwave dev
moonwave build
```

```bash
# build the library into a model file, or sync a dev place into ROBLOX Studio
rojo build -o luautils.rbxm
rojo serve dev.project.json
```

## CI

Every push to `master` and every pull request runs the checks in
`.github/workflows/ci.yml`.
The workflow installs the tools pinned in `rokit.toml` and runs `.lute/ci.luau`,
the same script you run locally. A separate job also builds the docs, which the
script does not do, so run `moonwave build` too if you changed any doc comments
or the README.

The script runs these steps in order and reports every failure at the end:

| Step              | Command                                                 |
| ----------------- | ------------------------------------------------------- |
| version           | `lute run .lute/version.luau`                           |
| format            | `stylua --check src tests`                              |
| lint              | `selene src`                                            |
| sourcemap         | `rojo sourcemap default.project.json -o sourcemap.json` |
| typecheck (src)   | `luau-lsp analyze --platform=roblox ... src`            |
| typecheck (tests) | `luau-lsp analyze --platform=standard ... tests`        |
| test              | `lute test`                                             |

`src` is type checked against ROBLOX's type definitions, because some modules
use ROBLOX globals (such as `task.wait`). `tests` are checked without them,
because they run under Lute. Type checking `tests` also checks every `src`
module they require, which would fail on those ROBLOX globals, so
`--ignore="src/**"` hides `src` diagnostics there; `src` is already checked
in the step before.

The separate docs job runs `moonwave build`, so broken doc comments or README
links fail CI too, even when the script passes.

If you add or change a check, update `.lute/ci.luau` and the table above
together.

## ROBLOX type definitions

`src` is type checked against ROBLOX's type definitions
(`globalTypes.None.d.luau` from the `scripts` folder of the luau-lsp
repository).
The CI script reads the `luau-lsp` version pinned in `rokit.toml` and downloads
the definitions from that exact release tag into `.cache/`, so they always match
the type checker.
Updating `luau-lsp` in `rokit.toml` updates the definitions on the next run, so
nothing needs to be committed.

## Rojo projects

* `default.project.json` builds the library on its own, as a model.
* `dev.project.json` builds a place with the library in
  `ReplicatedStorage/Luautils`.

## Project structure

```
src/luautils/
├── init.luau   -- re-exports every sublibrary
├── _internal/  -- private helpers, never re-exported
├── Core/       -- core functionality and types needed by other sublibraries
├── Time/       -- time-related functionality
├── Tables/     -- table-related functionality
└── ...         -- Collections, Math, Strings, Validation, Async, Events, Roblox
tests/          -- mirrors src/
```

Each sublibrary is a folder with an `init.luau` that re-exports its modules.

## Dependency direction

Requires only point down or sideways within a sublibrary, never up:

```
_internal <- Core <- Time, Tables, Strings, ... <- Events <- Roblox
```

Everything outside `Events/` and `Roblox/` is pure Luau and must run under Lute.
If a pure module needs a Roblox global, make it injectable (like `retry`'s
`sleep` option) and only fall back to the global at call time.

`Events/` and `Roblox/` may use ROBLOX globals, but only inside functions,
never when the module is required.
The root `init.luau` requires every sublibrary, so this keeps the whole library
loadable outside ROBLOX (which the pesde package relies on).
`tests/Luautils.test.luau` enforces this by requiring the root module under
Lute.

## Conventions

### Files and naming

* Every file starts with `--!strict` for strict type checking.
* Modules that return a function are named in camelCase (`deepCopy.luau`).
  Modules that return a class or table, and sublibrary folders, are named in
  PascalCase (`Duration.luau`, `Core/`).
* Inside `src/`, use relative string requires (`require("../Core")`), and
  `@self` in `init.luau` files.
* Formatting is enforced by StyLua (`stylua.toml`).

### Classes

* Classes use the `typeof(setmetatable({} :: Data, Class))` pattern for their
  exported type.
* Instances are created in one place (usually a private `new` helper) and frozen
  with `table.freeze` if immutable.
* Classes provide `Class.is(value)`, which checks the metatable.
* Named methods come alongside metamethods: `equals` with `__eq`, `compareTo`
  with `__lt`/`__le`, `toString` with `__tostring`.
  Type protocols such as `Equatable` can only see named methods.
* Do not define `__iter` on value types.
  It changes the behavior of every generic table-walking function
  (`for k, v in t do`).

**Why are methods declared with dot notation?**
Methods are written as `function Class.method(self: Class, ...)` rather than
`function Class:method(...)`.
With colon notation, the type checker infers `self`'s type, which prevents
generics from working properly across classes, along with other type issues.
Dot notation forces `self` to be declared explicitly, which fixes these issues.
Callers can still use colon syntax: `value:method()`.

### Errors

* Throw with a thrower from `Core.Errors.errorWithScope(scope)`, so error
  messages are prefixed with `[Scope.function()]: `.
  Use the class name as the scope for classes (`"Duration"` gives
  `[Duration.plus()]`), and the sublibrary name for function modules (`"Async"`
  gives `[Async.retry()]`).
* Errors blame the caller's line.
  Levels are counted from the function that calls the thrower: the default of 2
  blames that function's caller, and each helper frame in between adds 1.
* Any helper that takes an error level must be a table field (for example
  `Internal.normalize`), not a `local function`.
  The compiler may inline local functions at `-O2`, which removes their stack
  frame and breaks the level.
* Developer errors (invalid arguments, undefined operations) should throw.
  Data from outside the program (parsing, deserializing) should return a
  `Result` from a `try*` function, with a throwing version alongside it.
* For the most part, only operator metamethods validate their operand types at
  runtime, since callers can't see a signature from there.
  Other functions rely on their type annotations.
* Document every error a function can throw with an `@error` tag.

### Types

* Shared function and container types live in `Core/typing.luau` and are
  re-exported from `Core`.
* Use string literal unions (`"floor" | "ceil"`) or tagged unions
  (`{ kind: "circle", radius: number } | { kind: "rect", ... }`) instead of enum
  objects.

### Documentation

* Public functions have Moonwave doc comments with `@param`, `@return`, and
  `@error` tags.
  Methods also need `@method` and `@within` due to the dot notation convention.
* Include a short `lua` example block when the behavior isn't obvious from the
  signature.
* Note when an argument is evaluated eagerly (for example "`default` is
  evaluated even if...") and point to the lazy alternative.

### Tests

* Tests mirror `src/`: `src/luautils/Core/Option.luau` is tested by
  `tests/Core/Option.test.luau`.
* Use the helpers in `tests/Helpers.luau`, such as `eqByStr`, `throwsWith`, and
  `spy`.
* Compare tables like `Option`s, `Result`s, and `Duration`s with
  `Helpers.eqByStr` or `==`, not `asserts.eq`, which compares tables
  structurally and ignores `__eq`.
* Tests require submodules directly, never the root `init.luau`.
  The exception is `tests/Luautils.test.luau`, which checks that the root module
  loads outside ROBLOX.
* Test error messages by their full `[Scope.function()]: ` prefix.

## Package registries

This library is published to both Wally and pesde:

| Registry | Manifest     | Target                    | For                          |
| -------- | ------------ | ------------------------- | ---------------------------- |
| Wally    | `wally.toml` | ROBLOX (`realm = shared`) | ROBLOX projects              |
| pesde    | `pesde.toml` | `luau` environment only   | Lute and other Luau runtimes |

pesde is not published with a `roblox` target.
Wally is the standard for ROBLOX projects, and a second pesde target would need
a separate publish for every version.

Both packages ship the whole library, including `Events/` and `Roblox/` (see
Dependency direction).
`default.project.json` is Wally's entry point, and pesde's `includes` leaves it
out, since pesde rejects packages that contain it.

## Releasing

Versions follow semantic versioning.
While the library is below `1.0.0`, breaking changes bump the minor version
(`0.1.0` to `0.2.0`), and everything else bumps the patch version (`0.1.0` to
`0.1.1`).

`master` only changes through pull requests, and a version tag can only be
pushed once its commit has been deployed to GitHub Pages (the "Deploy docs" CI
job, which runs after a pull request is merged).

In the steps below, replace `X.Y.Z` with the new version and `YYYY-MM-DD` with
today's date.

1. Create a release branch from an up-to-date `master`:

```bash
git switch master
git pull --ff-only
git switch -c release/vX.Y.Z
```

2. Bump the version in `src/luautils/init.luau` (`VERSION`), `wally.toml`, and
   `pesde.toml`, then add a `## [vX.Y.Z] - YYYY-MM-DD` section to the top of
   [CHANGELOG.md](CHANGELOG.md).
   The `version` CI step fails if these differ.
3. Commit, push the branch, and open a pull request:

```bash
git commit -am "Release vX.Y.Z"
git push -u origin release/vX.Y.Z
gh pr create --title "Release vX.Y.Z" --fill
```

4. Merge the pull request once CI passes, and wait for "Deploy docs" to finish
   on `master` (`gh run watch`).
5. Tag the merged commit and push only the tag:

```bash
git switch master
git pull --ff-only
git tag vX.Y.Z
git push origin vX.Y.Z
```

6. Publish from the tagged commit (the first time, log in with `wally login`
   and `pesde auth login`):

```bash
wally publish

# check the tarball first
pesde publish --dry-run
pesde publish
```

7. Create the GitHub release, using the changelog section as the notes:

```bash
gh release create vX.Y.Z --title vX.Y.Z --notes "<changelog section>"
```

The tag must match the version in the files above.
