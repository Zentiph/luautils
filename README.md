# luautils

A Luau utilities library written for a wide variety of general use cases.
Luautils strives to act as an extension of Luau's standard library.

This library is heavily inspired by standard libraries of other languages such
as Rust and Java.

## Contents

| Sublibrary | Contains                                       |
| ---------- | ---------------------------------------------- |
| `Core`     | `Option`, `Result`, `Errors`, and shared types |
| `Time`     | `Duration`                                     |
| `Tables`   | `deepCopy`                                     |
| `Async`    | `retry`                                        |

`Collections`, `Math`, `Strings`, `Validation`, `Events`, and `Roblox` are
planned and currently empty.

## Installation

### ROBLOX

For use in ROBLOX projects, Wally is the recommended installation method.

Get the latest version:

```bash
wally search luautils
```

Add it to your `wally.toml`:

```toml
Luautils = "zentiph/luautils@<version>
```

Then require it:

```lua
local Luautils = require(ReplicatedStorage.Packages.Luautils)
```

### Standalone Luau

For standalone Luau projects, such as Lute, pesde is the recommended method:

```bash
pesde add zentiph/luautils
```

The pesde release targets luau only.
[ROBLOX projects should use Wally](#roblox).

### Manually

Clone the repository:

```bash
git clone https://github.com/Zentiph/luautils.git
```

Build the library into a model file with Rojo, then insert it into your place:

```bash
rojo build -o luautils.rbxm
```

Or sync it live into ROBLOX Studio, where it appears as the
`ReplicatedStorage/Luautils` `ModuleScript`:

```bash
rojo serve dev.project.json
```

Then require it:

```lua
local Luautils = require(game:GetService("ReplicatedStorage").Luautils)
local Option = Luautils.Core.Option
```

### Verifying your copy

The tools used by this project are pinned in `rokit.toml`.
To install them and run every check (formatting, linting, type checking, and
tests), run the following from the repository root:

```bash
rokit install
lute setup
lute run .lute/ci.luau
```

## Documentation

The API documentation is hosted on GitHub Pages at
[zentiph.github.io/luautils](https://zentiph.github.io/luautils/), and is
rebuilt from `master` on every push that passes CI.

It is written as Moonwave doc comments in the source.
To preview it locally:

```bash
moonwave dev
```

## Contributing

See
[CONTRIBUTING.md](https://github.com/Zentiph/luautils/blob/master/CONTRIBUTING.md)
for development setup, the CI checks, and the conventions used throughout the
library.