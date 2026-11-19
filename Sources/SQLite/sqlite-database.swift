import Foundation
import SQLite3

/// A column value or statement binding.
public enum SQLiteValue: Sendable, Equatable {
    case integer(Int64)
    case real(Double)
    case text(String)
    case null

    public var int: Int? {
        switch self {
        case .integer(let value): return Int(value)
        case .real(let value): return Int(value)
        default: return nil
        }
    }

    public var double: Double? {
        switch self {
        case .integer(let value): return Double(value)
        case .real(let value): return value
        default: return nil
        }
    }

    public var string: String? {
        if case .text(let value) = self {
            return value
        }
        return nil
    }
}

public struct SQLiteError: Error, Sendable, Equatable, LocalizedError {
    public let code: Int32
    public let message: String

    public var errorDescription: String? {
        "SQLite error \(code): \(message)"
    }
}

/// A thin, single-connection wrapper over the system SQLite. Not thread-safe on
/// its own; own it from one actor.
public final class SQLiteDatabase {
    private var handle: OpaquePointer?

    /// Opens or creates the database at `path`; `":memory:"` for a scratch one.
    public init(
        path: String
    ) throws {
        let status = sqlite3_open_v2(path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX, nil)
        guard status == SQLITE_OK else {
            let error = SQLiteError(code: status, message: handle.map { String(cString: sqlite3_errmsg($0)) } ?? "cannot open")
            sqlite3_close(handle)
            throw error
        }
    }

    deinit {
        sqlite3_close(handle)
    }

    /// Runs one or more statements without bindings or results.
    public func execute(
        _ sql: String
    ) throws {
        var message: UnsafeMutablePointer<CChar>?
        let status = sqlite3_exec(handle, sql, nil, nil, &message)
        guard status == SQLITE_OK else {
            let text = message.map { String(cString: $0) } ?? "failed"
            sqlite3_free(message)
            throw SQLiteError(code: status, message: text)
        }
    }

    /// Runs one statement for each set of bindings, reusing the prepared statement.
    public func run(
        _ sql: String,
        _ rows: [[SQLiteValue]]
    ) throws {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        for bindings in rows {
            try bind(bindings, to: statement)
            let status = sqlite3_step(statement)
            guard status == SQLITE_DONE || status == SQLITE_ROW else {
                throw failure(status)
            }
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
        }
    }

    public func run(
        _ sql: String,
        _ bindings: SQLiteValue...
    ) throws {
        try run(sql, [bindings])
    }

    /// Every result row of one statement.
    public func query(
        _ sql: String,
        _ bindings: [SQLiteValue] = []
    ) throws -> [[SQLiteValue]] {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)

        var rows: [[SQLiteValue]] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE {
                return rows
            }
            guard status == SQLITE_ROW else {
                throw failure(status)
            }
            rows.append((0..<sqlite3_column_count(statement)).map { column(statement, $0) })
        }
    }

    /// Runs `body` in one transaction, rolled back when it throws.
    public func transaction<T>(
        _ body: () throws -> T
    ) throws -> T {
        try execute("BEGIN IMMEDIATE")
        do {
            let result = try body()
            try execute("COMMIT")
            return result
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func prepare(
        _ sql: String
    ) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        let status = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard status == SQLITE_OK else {
            throw failure(status)
        }
        return statement
    }

    private func bind(
        _ bindings: [SQLiteValue],
        to statement: OpaquePointer?
    ) throws {
        // SQLite copies the text immediately with SQLITE_TRANSIENT.
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (offset, value) in bindings.enumerated() {
            let index = Int32(offset + 1)
            let status: Int32
            switch value {
            case .integer(let integer): status = sqlite3_bind_int64(statement, index, integer)
            case .real(let real): status = sqlite3_bind_double(statement, index, real)
            case .text(let text): status = sqlite3_bind_text(statement, index, text, -1, transient)
            case .null: status = sqlite3_bind_null(statement, index)
            }
            guard status == SQLITE_OK else {
                throw failure(status)
            }
        }
    }

    private func column(
        _ statement: OpaquePointer?,
        _ index: Int32
    ) -> SQLiteValue {
        switch sqlite3_column_type(statement, index) {
        case SQLITE_INTEGER: return .integer(sqlite3_column_int64(statement, index))
        case SQLITE_FLOAT: return .real(sqlite3_column_double(statement, index))
        case SQLITE_NULL: return .null
        default: return sqlite3_column_text(statement, index).map { .text(String(cString: $0)) } ?? .null
        }
    }

    private func failure(
        _ status: Int32
    ) -> SQLiteError {
        SQLiteError(code: status, message: String(cString: sqlite3_errmsg(handle)))
    }
}

public extension SQLiteValue {
    init(
        _ value: String?
    ) {
        self = value.map { .text($0) } ?? .null
    }

    init(
        _ value: Int?
    ) {
        self = value.map { .integer(Int64($0)) } ?? .null
    }

    init(
        _ value: Date?
    ) {
        self = value.map { .real($0.timeIntervalSince1970) } ?? .null
    }

    init(
        _ value: Bool
    ) {
        self = .integer(value ? 1 : 0)
    }
}
