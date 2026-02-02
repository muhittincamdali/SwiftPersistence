import Foundation

/// Errors that can occur during persistence operations.
///
/// Each case represents a specific failure mode across the various
/// storage backends supported by SwiftPersistence.
public enum PersistenceError: LocalizedError {

    /// The requested item was not found in the store.
    case notFound(key: String)

    /// Encoding the value to a storable format failed.
    case encodingFailed(underlying: Error)

    /// Decoding the stored data back to the expected type failed.
    case decodingFailed(underlying: Error)

    /// A Keychain operation returned an unexpected status code.
    case keychainError(status: OSStatus)

    /// The file system operation failed at the given path.
    case fileSystemError(path: String, underlying: Error)

    /// A CoreData operation encountered an error.
    case coreDataError(underlying: Error)

    /// A SwiftData operation encountered an error.
    case swiftDataError(underlying: Error)

    /// iCloud sync encountered a conflict or connectivity issue.
    case syncError(reason: String)

    /// The requested migration could not be completed.
    case migrationFailed(from: String, to: String)

    /// A generic, unclassified persistence error.
    case unknown(underlying: Error)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .notFound(let key):
            return "Item not found for key: \(key)"
        case .encodingFailed(let error):
            return "Encoding failed: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Decoding failed: \(error.localizedDescription)"
        case .keychainError(let status):
            return "Keychain error with status: \(status)"
        case .fileSystemError(let path, let error):
            return "File system error at \(path): \(error.localizedDescription)"
        case .coreDataError(let error):
            return "CoreData error: \(error.localizedDescription)"
        case .swiftDataError(let error):
            return "SwiftData error: \(error.localizedDescription)"
        case .syncError(let reason):
            return "Sync error: \(reason)"
        case .migrationFailed(let from, let to):
            return "Migration failed from \(from) to \(to)"
        case .unknown(let error):
            return "Unknown persistence error: \(error.localizedDescription)"
        }
    }
}
