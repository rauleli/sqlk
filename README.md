# sqlk – Keyed List Handler over SQLite for Tcl

`sqlk` is a lightweight key-value store implemented in Tcl using SQLite, inspired by C-style keyed lists and TclX patterns. It allows concurrent access to structured memory via SQLite while preserving performance and minimizing memory usage.

## ✨ Features

- Shared memory model between parent/child processes or threads using SQLite
- Supports `:memory:` mode for fast in-RAM operations
- Automatically serializes to file for persistent storage
- Can be used as log/config manager
- Originally created in 2008 and improved over time

## 🔧 Usage

```tcl
package require sqlk

# Initialize a database and create a command ensemble 'mainsqlk'
sqlk::kinit mydb.sqlite -procname mainsqlk

# Add a keyed list variable named 'myvar'
mainsqlk varadd myvar

# Basic set and get
myvar kset user.name "Raúl"
myvar kset user.id 0001
puts [myvar kget user.name] ;# Output: Raúl

# Multiple keys in one call
myvar kset app.theme dark app.lang es app.width 1024

# Check existence
if {[myvar kexist user.name]} { puts "exists" }

# List child keys
puts [myvar keys user]       ;# Output: name id

# Full key tree
puts [myvar tree]

# Attributes
myvar attrset user.name type string
puts [myvar attrget user.name type]

# Delete a key (and all its children)
myvar kdel user.name

# Reorder keys
myvar kmove user.id afterkey user.name

# Serialization
set tcldata [myvar serialize -format TCL]
set tcldata [myvar serialize -format TCL -indent 1]
set txtdata [myvar serialize -format TEXT]

# Parse back
mainsqlk varadd myvar2
myvar2 parse $tcldata

# In-memory mode (no persistence)
sqlk::kinit :memory: -procname tmpdb
```

## 📋 API Reference

### Database-level commands (`procname`)

| Command | Description |
|---------|-------------|
| `procname varlist` | List all keyed list variables |
| `procname varadd name ?-procname p? ?-enckey k?` | Create a new keyed list variable |
| `procname vardel name` | Delete a variable and all its keys |
| `procname kget name key` | Get value of a key |
| `procname kset name key val ?key val ...?` | Set one or more keys |
| `procname kdel name key` | Delete a key and its subtree |
| `procname kexist name key` | Returns 1 if key exists, 0 otherwise |
| `procname kmove name key ?afterkey?` | Reorder a key within its parent |
| `procname keys name ?key?` | List direct children of a key (or root) |
| `procname tree name ?key?` | Flat list of all keys in subtree |
| `procname attrset name key attr val ?attr val ...?` | Set attributes on a key |
| `procname attrget name key ?attr?` | Get attribute(s) of a key |
| `procname attrdel name key attr` | Delete an attribute |
| `procname serialize name ?-format TCL\|XML\|TEXT? ?-indent 0\|1? ?-key key?` | Serialize a variable |
| `procname parse name ?-format TCL\|XML? ?-into key? data` | Import serialized data |
| `procname varcmd name ?procname?` | Get or create the per-variable command ensemble |
| `procname closefile` | Close the database |
| `procname backup filename` | Backup the database to a file |
| `procname restore filename` | Restore the database from a file |

### Per-variable commands (`namecmd`)

Once a variable is created with `varadd`, it gets its own command ensemble with the same operations minus the variable name argument:

```tcl
myvar kget key
myvar kset key val ?key val ...?
myvar kdel key
myvar kexist key
myvar kmove key ?afterkey?
myvar keys ?key?
myvar tree ?key?
myvar attrset key attr val ?attr val ...?
myvar attrget key ?attr?
myvar attrdel key attr
myvar serialize ?-format TCL|XML|TEXT? ?-indent 0|1? ?-key key?
myvar parse ?-format TCL|XML? ?-into key? data
```

## 📄 Serialization Formats

| Format | Description |
|--------|-------------|
| `TCL` (default) | Native Tcl list — lossless roundtrip including attributes |
| `TEXT` | Human-readable hierarchical dump |
| `XML` | Pending implementation |

## 🔐 Encryption

Optional AES encryption per variable. Requires the `aes` Tcl package.

```tcl
sqlk::kinit mydb.sqlite -procname db -enckey mysecretkey
db varadd secrets
```

Encrypted databases from v0.7 (RC4) are not directly compatible with v0.8 (AES). To migrate:

1. Using **v0.7**, export with `serialize -format TCL`
2. Using **v0.8**, import with `parse`

## 📁 Persistence Modes

- `:memory:` — fast, in-RAM only, lost on close
- `path/to/file.sqlite` — persistent disk-based storage

## 📜 License

MIT

## 🙏 Acknowledgements

Born out of real system needs for shared memory management between processes.  
Shared to serve as a flexible tool for the Tcl community.

## ☕ Support my work

If this project has been helpful to you or saved you some development time, consider buying me a coffee!

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/rauleli)
