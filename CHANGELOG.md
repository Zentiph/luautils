# Changelog for luautils

<!--
## [UNRELEASED]
*
-->

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
  * Documented feature branches and the `Unreleased` changelog section in
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
* > Note: The Wally and pesde packages report `Luautils.VERSION` as `0.1.0`
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
