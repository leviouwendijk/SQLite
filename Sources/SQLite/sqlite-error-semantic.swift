import Errors
import Foundation
import SQLite3

extension SQLiteError:
    SemanticError,
    ErrorNamespaced,
    ErrorDispositionProviding
{
    public static let errorNamespace = "sqlite"

    /// The primary result code without its extended bits.
    var primaryCode: Int32 {
        code & 0xFF
    }

    public var errorCode: String {
        switch primaryCode {
        case SQLITE_BUSY: return "busy"
        case SQLITE_LOCKED: return "locked"
        case SQLITE_READONLY: return "read_only"
        case SQLITE_PERM: return "permission_denied"
        case SQLITE_CONSTRAINT: return "constraint_failed"
        case SQLITE_CANTOPEN: return "cannot_open"
        case SQLITE_FULL: return "disk_full"
        case SQLITE_CORRUPT, SQLITE_NOTADB: return "corrupt"
        case SQLITE_MISMATCH: return "type_mismatch"
        case SQLITE_MISUSE: return "misuse"
        case SQLITE_ERROR: return "statement_failed"
        default: return "failed"
        }
    }

    public var errorDisposition: ErrorDisposition? {
        switch primaryCode {
        case SQLITE_BUSY, SQLITE_LOCKED: return .transient
        case SQLITE_READONLY, SQLITE_PERM: return .requires_access
        case SQLITE_CONSTRAINT, SQLITE_MISMATCH: return .invalid_input
        case SQLITE_CORRUPT, SQLITE_NOTADB, SQLITE_FULL: return .permanent
        default: return nil
        }
    }

    public var errorPresentation: ErrorPresentation {
        ErrorPresentation(
            message: "SQLite error \(code).",
            // SQLite's message can quote values from the statement.
            reason: message,
            recoverySuggestion: suggestion,
            reasonSensitivity: .potentially_sensitive
        )
    }

    public var errorDiagnosticFields: [ErrorDiagnosticField] {
        [
            .init(key: "sqlite.code", value: Int(code)),
        ]
    }

    private var suggestion: String? {
        switch primaryCode {
        case SQLITE_BUSY, SQLITE_LOCKED:
            return "Another connection holds the database; try again shortly."
        case SQLITE_CANTOPEN:
            return "Check that the database's directory exists and is writable."
        case SQLITE_CORRUPT, SQLITE_NOTADB:
            return "The file is not a usable database; rebuild it from its source."
        default:
            return nil
        }
    }
}
