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

## Structure

With `rojo` and the default `default.project.json`, the library is copied into
the `ReplicatedStorage/Luautils` `Folder`.

The library is split into the following sub-libraries:

- datatypes (`.../DataTypes`)
  - All `ModuleScript`s part of the public API return classes
- functions (`.../Functions`)
  - All `ModuleScript`s part of the public API return functions directly

## QnA

| Q                                                                                                                                        | A                                                                                      |
| ---------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| Why do all datatype method signatures use dot (`class.method`) notation rather than colon (`class:method`) notation when being declared? | It comes down to how Luau handles `self` in methods, specifically the type checker. When using colon notation, `self`'s type is automatically interpreted, which prevents the proper usage of generics across classes, along with some other type issues. Dot notation, while forcing the declaration of `self` explicitly, fixes these problems. |

