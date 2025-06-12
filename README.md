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

sqlk::kinit mydb.sqlite -procname mainsqlk
mainsqlk varadd myvar myvar
myvar kset user.name "Raúl"
myvar kset user.id 0001
puts [myvar kget user.name]
```

## 📁 Persistence Modes
- `sqlk::init ":memory:"` for fast temporary use
- Provide a path to use disk-based SQLite storage

## 📜 License
MIT (or specify your preference)

## 🙏 Acknowledgements
Born out of real system needs for shared memory management.  
Now shared to serve as a flexible tool for the Tcl community.
