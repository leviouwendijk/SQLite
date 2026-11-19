import Foundation
import SQLite
import Testing

private enum SQLiteTestingFailure: Error {
    case failed
}

@main
struct SQLiteTestingMain {
    static func main() async throws {
        let reporter = PlainTextTestReporter(
            output: ClosureTestTextOutput { text in
                FileHandle.standardOutput.write(Data(text.utf8))
            }
        )
        let result = await TestRunner.run(
            SQLiteTestSuite.suite,
            sink: reporter
        )
        if result.isFailure {
            throw SQLiteTestingFailure.failed
        }
    }
}

enum SQLiteTestSuite {
    static let suite = TestSuite(
        "sqlite",
        title: "SQLite"
    ) {
        Test("values-round-trip") {
            try SQLiteTests.values()
        }
        Test("statement-reused-for-rows") {
            try SQLiteTests.batch()
        }
        Test("transaction-rolls-back-on-throw") {
            try SQLiteTests.rollback()
        }
        Test("errors-carry-the-message") {
            try SQLiteTests.errors()
        }
    }
}

enum SQLiteTests {
    static func values() throws {
        let database = try SQLiteDatabase(path: ":memory:")
        try database.execute("CREATE TABLE t (i INTEGER, r REAL, s TEXT, n TEXT)")
        try database.run("INSERT INTO t VALUES (?, ?, ?, ?)", .integer(42), .real(1.5), .text("één ✉"), .null)
        let rows = try database.query("SELECT i, r, s, n FROM t")
        try Expect.equal(rows, [[.integer(42), .real(1.5), .text("één ✉"), .null]], "Every type back as written")
        try Expect.equal(rows[0][0].int, 42, "Int accessor")
        try Expect.equal(rows[0][1].double, 1.5, "Double accessor")
        try Expect.equal(rows[0][2].string, "één ✉", "UTF-8 text")
        try Expect.equal(SQLiteValue(nil as String?), .null, "Optional becomes NULL")
        try Expect.equal(SQLiteValue(true), .integer(1), "Bool as integer")
    }

    static func batch() throws {
        let database = try SQLiteDatabase(path: ":memory:")
        try database.execute("CREATE TABLE t (k TEXT PRIMARY KEY, v INTEGER)")
        try database.run("INSERT INTO t VALUES (?, ?)", (1...500).map { [.text("k\($0)"), .integer(Int64($0))] })
        let sum = try database.query("SELECT COUNT(*), SUM(v) FROM t WHERE v > ?", [.integer(250)])
        try Expect.equal(sum, [[.integer(250), .integer(93_875)]], "Bound filter over every row")
    }

    static func rollback() throws {
        let database = try SQLiteDatabase(path: ":memory:")
        try database.execute("CREATE TABLE t (v INTEGER)")
        struct Abort: Error {}
        do {
            try database.transaction {
                try database.run("INSERT INTO t VALUES (?)", .integer(1))
                throw Abort()
            }
        } catch is Abort {}
        try Expect.equal(try database.query("SELECT COUNT(*) FROM t"), [[.integer(0)]], "Nothing kept")
        try database.transaction {
            try database.run("INSERT INTO t VALUES (?)", .integer(1))
        }
        try Expect.equal(try database.query("SELECT COUNT(*) FROM t"), [[.integer(1)]], "Committed")
    }

    static func errors() throws {
        let database = try SQLiteDatabase(path: ":memory:")
        do {
            _ = try database.query("SELECT * FROM missing")
            throw TestFlowAssertionFailure(label: "error", message: "expected a failure")
        } catch let error as SQLiteError {
            try Expect.true(error.message.contains("missing"), "Names the table")
        }
    }
}
