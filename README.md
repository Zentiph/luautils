# luautils

A Luau utilities library written for a wide variety of general use cases.

This library is heavily inspired by the Rust standard library, and aims to make
Luau a more functional and safe language.

## Installation

As of now, there is no clean way to install these scripts other than to clone
the repository or download them manually.
I'd eventually like to add this to Wally, but for now, the best way to install
is to clone the repository:

```bash
git clone https://github.com/Zentiph/luautils.git
```

The tools used by this project are pinned in `rokit.toml`. To install them,
run the following from the repository root:

```bash
rokit install
```

### Verifying Installation

To verify that the version of the library you have is compatible for use, you
can run the test suite and type checker on the library from the repository
root:

```bash
# test suite (discovers every *.test.luau file under tests/)
lute test
```

```bash
# type check
luau-lsp analyze --platform standard --flag:LuauSolverV2=true src tests
```

`--flag:LuauSolverV2=true` is required; without it, `luau-lsp analyze` uses the
old type solver, which reports false errors for this library.

## Development

All commands are run from the repository root.

```bash
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
# preview the documentation locally, or build it into build/
moonwave dev
moonwave build
```

```bash
# build the library into a model file, or sync it live into Roblox Studio
rojo build -o luautils.rbxm
rojo serve
```

## Structure

With `rojo` and the default `default.project.json`, the library is copied into
the `ReplicatedStorage/Luautils` `Folder`.

## QnA

| Q                                                                                                                                        | A                                                                                      |
| ---------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| Why do all datatype method signatures use dot (`class.method`) notation rather than colon (`class:method`) notation when being declared? | It comes down to how Luau handles `self` in methods, specifically the type checker. When using colon notation, `self`'s type is automatically interpreted, which prevents the proper usage of generics across classes, along with some other type issues. Dot notation, while forcing the declaration of `self` explicitly, fixes these problems. |

