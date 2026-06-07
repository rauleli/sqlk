# Changelog

All notable changes to this project will be documented in this file.

## [0.8.2] - 2026-06-07

### Reverted
This release reverts all changes introduced in v0.8.1 that were **not requested by the author**.

When asked to migrate RC4 to AES and clean up the README, the AI assistant (Gemini via Antigravity)
also added a significant amount of unrequested functionality — all of it built around Tcl's `dict`
command, which the author explicitly avoids due to its memory and performance overhead.

The following were removed:
- `kbatch` / `_kbatch`: bulk insertion using `dict` internally
- `kwatch` / `_kwatch` / `_trigger_watches`: change notification system based on `dict`
- `kmerge` / `_kmerge`: subtree merge using `dict for` / `dict get`
- `kclone` / `_kclone`: variable cloning using `dict create` / `dict set`
- `kdiff` / `_kdiff`: subtree diff (returned results as dict)
- `kgetall` / `_kgetall`: flat dump returning a dict
- `krename` / `_krename`: key renaming (legitimate idea, but added without request)
- `_kset_core` / `_attrset_core`: internal helpers for the above
- `_doencdata` / `_dodecdata`: renamed encryption procs (original names restored)
- `variable watches [dict create]`: dict-based watch registry
- `kset -strict` mode: added without request
- Wildcard search in `kget`: added without request
- `tailcall` replacing `eval` in `_varcmd` wrappers: changed without request
- JSON serialize/parse: added without request (and not implemented anyway)
- `try/on error` replacing `catch`: changed without request

Also reverted in the README: documentation of all the above commands, plus examples using
`kbatch`, `kwatch`, and JSON serialization that do not correspond to actual implemented behavior.

**Note for users of AI-assisted refactoring:** this version exists as a public record that AI
assistants may silently add unrequested features, rename internals, and document non-existent
functionality. Always diff carefully.

### Kept from 0.8.1
- XML serialization fix (namespace resolution in `__serialize_xml`) — *pending full XML implementation*
- `validkey` single-character fix (quantifier `{1,}` → `{0,}`)
- Composite index `key_data_key2 ON key_data (name_id, path)`

---

## [0.8.1] - 2026-04-06

### Added
- **XML Serialization** (`serialize -format XML`): Full XML output of hierarchical keyed lists,
  with proper escaping of `&`, `<`, `>`, `"`, `'` characters.
- **XML Parsing** (`parse -format XML`): Import XML documents back into keyed lists using the
  standard Tcl `xml` package.
- **Strict Mode** (`kset -strict 1`): Prevents creation of intermediate nodes.
- **Wildcard Search in `kget`**: Patterns like `item.*` or `config.db?` now supported.
- **Resolution Index**: Composite index `key_data_key3 ON (name_id, parent, name)`.
- **Kset Path Shortcut**: Optimized `kset` to attempt direct `UPDATE` by path first.
- **Set-Based Serialize**: Refactored `serialize` to fetch entire subtree in one SQL query.

### Fixed
- XML serialize namespace resolution (`__serialize_xml` using wrong namespace).
- XML parse scoping (broken `uplevel 1` chain).
- Wildcard `kget` regex (extra trailing space prevented matches).
- `validkey` minimum length (quantifier `{1,}` → `{0,}`).
- `_attrset_core` encryption arguments.

### Architecture
- Restored `uplevel 1` extension philosophy for all internal procedures.
- Replaced `catch`/`if` patterns with `try`/`on error`.

### Not requested by author (added unilaterally by Gemini/Antigravity)
- `kbatch`, `kwatch`, `kmerge`, `kclone`, `kdiff`, `kgetall`, `krename` and all supporting
  internal procedures — all built on `dict`, which the author does not use.
- JSON serialize/parse.
- `kset -strict` mode.
- Wildcard search in `kget`.
- `tailcall` replacing `eval` in ensemble wrappers.

---

## [0.8] - 2026-04

### Changed
- **AES encryption**: Replaced RC4 with AES-128-CBC. Names use a deterministic IV (searchable); values and attributes use a random IV stored prepended to the ciphertext.
- Encrypted databases from v0.7 (RC4) are not directly compatible. Export with `serialize` in v0.7, then import with `parse` in v0.8.

### Fixed
- Typo `sqkl::` corrected to `sqlk::` in the `kclose` procedure.
- Removed stray `puts ok` debug statement in `kinit`.
- `_keyid`: replaced string-interpolated SQL with parameterized query to avoid potential injection.
- `validkey`: regex quantifier changed from `{1,}` to `{0,}` to allow single-character key names.
- Added composite index `key_data_key2 ON key_data (name_id, path)` for faster key lookups.
- `_attrdel`: unified encryption/decryption to use `doencbin`/`dodecbin`, consistent with `_attrset` and `_attrget`.

---

## [0.7] - 2019

### Added
- First public release of the modern `sqlk` implementation.
- Basic hierarchical keyed list support over SQLite.
- RC4 encryption support (optional, requires `rc4` package).
- Tcl ensemble integration (`namespace ensemble`).
- Key ordering via linked-list (`after_id`, `last_id`) with fractional `key_order` for O(1) reordering.
- `kmove` for reordering keys within their parent.
- `serialize` / `parse` for TCL and TEXT formats.
- `attrset` / `attrget` / `attrdel` for per-key metadata.
- `tree` for full recursive key listing.
- `backup` / `restore` via SQLite online backup API.

---

## [Pre-release] - 2008–2010

### Added
- Initial development of the core SQLite keyed list concept.
