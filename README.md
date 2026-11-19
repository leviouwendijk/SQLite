# SQLite

A thin wrapper over the system `libsqlite3` (macOS ships it): one connection,
typed values, bound statements, rows and transactions. Sibling of `PSQL`,
kept separate on purpose: local embedded databases, no server.

```swift
import SQLite

let database = try SQLiteDatabase(path: "/path/index.sqlite")   // or ":memory:"
try database.execute("CREATE TABLE IF NOT EXISTS t (k TEXT PRIMARY KEY, v INTEGER)")
try database.transaction {
    try database.run("INSERT OR REPLACE INTO t VALUES (?, ?)", rows)   // one prepared statement, many rows
}
let top = try database.query("SELECT k, v FROM t WHERE v > ? ORDER BY v DESC", [.integer(10)])
```

`SQLiteDatabase` is not thread-safe on its own; own it from one actor (as
Mail's `MailIndex` does). Values are `SQLiteValue` (`integer`, `real`, `text`,
`null`) with `int`/`double`/`string` accessors and initializers from optionals,
`Bool` and `Date` (seconds since 1970).

## Build and test

```sh
sbm test    # t_sqlite
```
