# Changelog

All notable changes to this project will be documented in this file.

## [0.8.1] - 2026-04-06

### Added
- **XML Serialization** (`serialize -format XML`): Full XML output of hierarchical keyed lists, with proper escaping of `&`, `<`, `>`, `"`, `'` characters.
- **XML Parsing** (`parse -format XML`): Import XML documents back into keyed lists using the standard Tcl `xml` package. Supports nested `<key name="..." val="...">` elements with custom attributes.
- **Strict Mode** (`kset -strict 1`): Prevents creation of intermediate nodes. If a parent key does not exist, the operation fails instead of auto-creating the path.
- **Wildcard Search in `kget`**: Patterns like `item.*` or `config.db?` are now supported, returning path/value pairs for all matching keys.
- **Resolution Index**: Added composite index `key_data_key3 ON (name_id, parent, name)` for faster hierarchical node resolution.
- **Kset Path Shortcut**: Optimized `kset` to attempt a direct `UPDATE` by path first. For existing keys, this reduces SQL overhead from O(N) level-by-level checks to O(1).
- **Set-Based Serialize**: Refactored `serialize` (TCL, XML, TEXT) to fetch the entire subtree in a single SQL query instead of using recursive database calls.

### Fixed
- **XML Serialize namespace resolution**: `__serialize_xml` was incorrectly using `[namespace current]` (resolving to `::sqlk`) instead of the instance namespace passed via `$ns`. Now correctly uses the public ensemble commands (`keys`, `kget`, `attrget`).
- **XML Parse scoping**: Previous implementation attempted to use internal `_kset_core`/`_attrset_core` procedures via `namespace eval` + `uplevel 1`, which broke the variable resolution chain. Replaced with direct calls to instance ensemble commands (`kset`, `attrset`)  — the same proven pattern used by `__parse` for TCL format.
- **Wildcard kget regex**: Fixed an extra trailing space in the glob pattern `{*[*?]* }` that prevented any wildcard match from succeeding.
- **`validkey` minimum length**: Changed regex quantifier from `{1,39}` to `{0,39}` to allow single-character key names.
- **`_attrset_core` encryption**: Fixed missing `$val` argument to `dodecdata` and incorrect `doencdata` call.

### Architecture
- **Restored `uplevel 1` extension philosophy**: All internal procedures (`_kset`, `_kget`, `_keys`, `_parse`, etc.) remain parameter-less macros that execute in the caller's namespace scope via `uplevel 1`. This was temporarily broken during XML development and has been fully restored.
- **No use of `subst`**: Per project conventions, `subst` is not used anywhere in the codebase.
- **Error handling**: All `catch`/`if` patterns replaced with `try`/`on error`.

---

## [0.8] - 2026-04-06

### Added
- **AES-128-CBC Encryption**: Replaced the deprecated RC4 encryption. Includes deterministic IV for searchable variable names and random IV for values/attributes.
- **WAL Mode**: Enabled SQLite Write-Ahead Logging by default for better concurrency and fewer "database is locked" errors.
- **Composite Index**: Added a composite index on `(name_id, path)` to `key_data` for significantly faster lookups. Includes an auto-migration routine for existing databases.
- **Improved Security**: Fixed a potential SQL injection vulnerability in the `_keyid` procedure.
- **Tcl 8.6+ Optimizations**: Replaced `eval` with `tailcall` in command wrappers for better performance and safety.
- **JSON Serialization**: Added standalone JSON `serialize` and `parse` support (zero-dependency).
- **Bulk Processing (`kbatch`)**: High-speed batch insertion for large datasets within atomic transactions.
- **Observability (`kwatch`)**: Synchronous change notification system for data monitoring.
- **Advanced Tools**: Added `kcount`, `kfind`, `kgetall`, `krename`, `kmerge`, `kclone`, and `kdiff`.

### Changed
- **Performance**: Replaced `fmod()` with the integer modulo operator `%`.
- **Optimization**: Braced `expr` statements and converted SQL strings to braces for better byte-code compilation.
- **Encryption API**: Refactored internal encryption pros from RC4-based to AES-based (`doencdata`/`dodecdata`).

### Fixed
- Fixed typo `sqkl::` instead of `sqlk::` in the `kclose` procedure.
- Removed stray `puts ok` debug statement.
- Removed unused variables and dead code sections.
- Unified encryption/decryption logic across attributes and values.

## [0.7] - 2019

### Added
- First public release of the modern `sqlk` implementation.
- Basic hierarchical keyed list support over SQLite.
- RC4 encryption support.
- Tcl ensemble integration.

## [Pre-release] - 2010

### Added
- Initial project creation and development of the core SQLite keyed list concept.
