# Changelog for luautils

## [UNRELEASED]
> Note: `Duration:toParts()` now returns `TimeParts`, whose fields are
> read-only, so code that modifies the returned table no longer type checks
* Features
  * Core
    * Class (new module)
      * Utilities for object-oriented design in Luau
      * `sealed`/`isSealed` for making classes immutable and final, and checking
        it; instances of sealed classes can still be frozen
      * `extends`/`isA`/`isSubclassOf` for inheritance
      * `parentOf`/`classOf` for finding a class's base class and a value's
        class
      * `new` for creating instances, setting up `__index` and inherited
        metamethods automatically, optionally building on fields made by a base
        class to reuse its constructor logic
      * `merge` for building a subclass's fields on its base class's fields
      * `IsA<C>` type function and `cast` for passing subclass instances where a
        base class instance is expected
      * `tryCast` for checking and typing a value in one step, since `isA`
        cannot narrow types
      * `Metatable<C>` type
    * typing
      * `NonNil<T>` type function
      * `Partial<T>` type function
      * `DeepPartial<T>` type function
      * `Required<T>` type function
      * `DeepRequired<T>` type function
      * `ReadOnly<T>` type function
      * `DeepReadOnly<T>` type function
      * `Writable<T>` type function
      * `DeepWritable<T>` type function
      * `Record<K, V>` type function
      * `Exclude<T, U>` type function
      * `Extract<T, U>` type function
      * `Pick<T, K>` type function
      * `Omit<T, K>` type function
      * `Merge<A, B>` type function
      * `Parameter<F, I>` type function
      * `ReturnType<F>` type function
      * `OmitSelf<F>` type function
      * `Uppercase<T>` type function
      * `Lowercase<T>` type function
      * `Capitalize<T>` type function
      * `Uncapitalize<T>` type function
    * Values
      * `hasMethod` function
  * Time
    * `Duration.TimeParts` type
* Changes
  * Core
    * `Option` and `Result` are sealed with `Class.sealed()` instead of frozen,
      so `Class.extends()` throws on them
  * Time
    * `Duration`, `Cooldown`, and `Stopwatch` are sealed with `Class.sealed()`
      instead of frozen, so `Class.extends()` throws on them
    * `Duration.fromParts()` takes `Partial<TimeParts>` instead of `TimePartsI`
    * `Duration:toParts()` returns `TimeParts` instead of `TimePartsO`
    * `TimeParts` is exported through `Time` and `Luautils`
    * `HumanStringOptions` is now readonly
* Fixes
  * Time
    * `Stopwatch.new()` no longer shows a type error in Studio and the editor
* Deprecations
  * Time
    * `Duration.TimePartsI` (use `Partial<TimeParts>` instead)
    * `Duration.TimePartsO` (use `TimeParts` instead)
* Tests
  * Added type-check tests for the typing type functions in `tests/typing`,
    including cases that must fail to type check
  * Added runtime and type-check tests for Class
  * Cooldown tests pass the key type with `Cooldown.new<<K>>(...)`, as
    documented
* CI
  * Added a `typecheck (typing)` step that runs `.lute/typing.luau`
  * Every typecheck step also runs with `--no-flags-enabled`, matching the Luau
    flags Studio and the editor use, since `luau-lsp analyze` enables every flag
    by default
  * Added a `docs format` step that checks doc comments and Markdown files with
    `.lute/docs.luau --check`
* Tooling
  * Added the `types` library global to `luau-extras.yml` for selene
  * Added `.lute/docs.luau`, which formats prose in doc comments and Markdown
    files
* Documentation
  * Documented in CONTRIBUTING that typing helpers are type functions, which
    need the new type solver
  * Prose in doc comments and Markdown files fills lines up to 80 columns
    instead of starting each sentence on a new line, and wrapped list items line
    up with the item's text
  * Notes and warnings in doc comments are blockquotes instead of `:::`
    admonitions, so they read cleanly when hovering in an editor
  * `@type` tags for generic types in `typing` include their generics, such as
    `Map<K,V>`
  * `Cooldown.new()` explains why to pass the key type with
    `Cooldown.new<<K>>(...)`, including a type error in Studio without it
  * Documented the CI steps that check with Studio's Luau flags, and the doc
    formatting conventions, in CONTRIBUTING

## [v0.1.3] - 2026-11-10
* Features
  * Time
    * Stopwatch class
    * Cooldown class
  * Core.Values
    * Standard value checks
    * Protocol matching on any value
* CI
  * `.lute/version.luau` takes an optional expected version, checked before
    tagging a release
  * Added a CI check for branch names on pull requests
  * Added automatic pull request labels based on the branch name
* Documentation
  * Documented feature branches and the `UNRELEASED` changelog section in
    CONTRIBUTING
  * Added merge and version-check commands to the release steps in CONTRIBUTING
  * Documented the allowed branch name prefixes in CONTRIBUTING
  * Tagged every class as `mutable` or `immutable` in the docs, and documented
    the convention in CONTRIBUTING

## [v0.1.2] - 2026-11-05
* Fixed `Luautils.VERSION` reporting `0.1.0` in the published 0.1.1 packages
* Tests
  * Added root tests
    * Test luautils does not load ROBLOX globals at load time (for non-ROBLOX
      environments)
    * Test luautils contains a `VERSION` string
* CI
  * Added version matcher for all files that report a package version
* Documentation
  * Updated README to reflect new installation methods
  * Updated CONTRIBUTING to reflect new practices for publication

## [v0.1.1] - 2026-11-05
> Note: The Wally and pesde packages report `Luautils.VERSION` as `0.1.0`
* Published to Wally and pesde
* Made all tables returned from modules frozen to enforce read-only properties
* Documentation fixes
  * Marked `Luautils.VERSION` as read-only

## [v0.1.0] - 2026-11-05
* Initial release
* `Core`
  * `typing` base types
  * `Option<T>`
  * `Result<T, E>`
  * `Errors`
* `Time`
  * `Duration`
* `Async`
  * `retry`
* `Tables`
  * `deepCopy`
* Initial test suite
