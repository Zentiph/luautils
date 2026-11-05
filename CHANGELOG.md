# Changelog for luautils

## [Unreleased] - 202X-XX-XX
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
