# sqlk – Keyed List Handler over SQLite for Tcl

`sqlk` is a lightweight key-value store implemented in Tcl using SQLite, inspired by C-style keyed lists and TclX patterns. It allows concurrent access to structured memory via SQLite while preserving performance and minimizing memory usage.

## ✨ Features
- Shared memory model between parent/child processes or threads using SQLite
- Supports `:memory:` mode for fast in-RAM operations
- Automatically serializes to file for persistent storage
- Can be used as log/config manager
- Originally created in 2010 and improved over time (v0.7 released in 2019)

## 🔧 Usage

```tcl
package require sqlk

# Initialize an in-memory database and create a command ensemble 'mainsqlk'
sqlk::kinit :memory: -procname mainsqlk

# Add a keyed list variable named 'myvar'
mainsqlk varadd myvar

# Basic set and get
myvar kset user.name "Raúl"
myvar kset user.id 0001
puts [myvar kget user.name] ;# Output: Raúl

# Batch insert for performance
myvar kbatch {
    app.config.theme  "dark"
    app.config.lang   "es"
    app.window.width  1024
}

# Wildcard searches
puts [myvar kget app.config.*] ;# Output: app.config.lang es app.config.theme dark

# Watch for changes
proc on_theme_change {name key op old new} {
    puts "Theme changed from $old to $new on $name:$key"
}
myvar kwatch app.config.theme on_theme_change
myvar kset app.config.theme "light" ;# Triggers callback

# Serialization and Parsing
set xml_data [myvar serialize -format XML]
set json_data [myvar serialize -format JSON]

# Parse JSON into a new variable
mainsqlk varadd myvar2
myvar2 parse -format JSON $json_data
```

## 🛠️ Extended API Commands (v0.8+)

The following advanced commands have been added for comprehensive data management:

- `kbatch list`: High-performance batch insertion using a single atomic transaction.
- `kwatch key callback`: Watch a key (and its descendants) for changes. Callback signature: `proc cb {name key op old new}`.
- `kcount ?key?`: Returns the number of direct children under the given key.
- `kfind pattern`: Searches for keys matching a SQL `LIKE` pattern (using `*` and `?`). 
- `kgetall ?key?`: Returns the specified node and all its descendants as a flat dictionary.
- `krename key newname`: Renames a key (and updates paths of all its children), preserving its order.
- `kmerge src_key newname ?target_key?`: Deep merges a subtree into another list.
- `kclone newname`: Clones the entire keyed list into a new variable under the same database.
- `kdiff key1 key2`: Compares two subtrees and returns a list of differences (additions, modifications, deletions).
- `kset -strict 1 key val`: Strict setter that requires the `parent` node to exist.

## 📄 Supported Formats

The `serialize` and `parse` commands now support multiple formats:
- **TCL** (Default): Native Tcl list representation.
- **XML**: Hierarchical XML with element `<key name="..." val="..." attr="...">`.
- **JSON**: Dictionary representation mapped to JSON strings.
- **TEXT**: Human-readable hierarchical text dump.

## 🔄 Migration from v0.7 (RC4) to v0.8 (AES)

Version 0.8 replaces the old RC4 encryption with AES-128-CBC. If you have an encrypted database from v0.7, it is **not** directly compatible.

To migrate your data:
1. Using **v0.7**, open your database and use the `serialize` command to export your data.
2. Using **v0.8**, create/open the new database and use the `parse` command to import the serialized data.

## 📁 Persistence Modes
- `sqlk::init ":memory:"` for fast temporary use
- Provide a path to use disk-based SQLite storage

## 📜 License
MIT

## 🙏 Acknowledgements
Born out of real system needs for shared memory management.  
Now shared to serve as a flexible tool for the Tcl community.

## ☕ Support my work

If this project has been helpful to you or saved you some development time, consider buying me a coffee! Your support helps me keep exploring new optimizations and sharing quality code.

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/rauleli)
