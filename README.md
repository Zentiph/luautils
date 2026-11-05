# luautils

A Luau utilities library written for a wide variety of general use cases.
Luautils strives to be like an extension of Luau's standard library.

This library is heavily inspired by standard libraries of other languages such
as Rust and Java

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

As of now, there is no clean way to install the library other than to clone the
repository or download it manually.
This library will eventually be added to Wally, but for now, the best way to
install is to clone the repository:

```bash
git clone https://github.com/Zentiph/luautils.git
```

### Using it in ROBLOX

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
To install them ans run every check (formatting, linting, type checking, and
tests), run the following from the repository root:

```bash
rokit install
lute setup
lute run .lute/ci.luau
```

## Documentation

The API documentation is hosted on GitHub Pages at
<https://zentiph.github.io/luautils/>, and is rebuilt from `master` on every
push that passes CI.

It is written as Moonwave doc comments in the source.
To preview it locally:

```bash
moonwave dev
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, the CI checks, and
the conventions used throughout the library.