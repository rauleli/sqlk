sqlk

keyed list on sqlite

similar syntax than C keyed lists, but sort of taken from TclX, using sqlite so the same application couldn spawn child processes or threads and all of them could keep using the same information, using tcl and sqlite3 and preserving memory usage.

It also keeps values stored in file, so it can be used also as log or config file.

Due the sqlite ability to use :memory:, it can handle information quite fast, then serialize/parse it into a  file to release memory.

The project started around 2008, and has been improving.  But never released as final first version.

Hope it can be useful for more people and improved even more
