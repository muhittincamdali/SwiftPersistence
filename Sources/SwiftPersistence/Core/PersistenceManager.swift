import Foundation
import Combine

/// A unified facade for all persistence backends.
///
/// `PersistenceManager` provides a single entry point for storing and
/// retrieving data across UserDefaults, Keychain, file system, CoreData,
/// and SwiftData backends. Use it to keep your persistence logic
/// centralised rather than scattered across the codebase.
///
/// ```swift
/// let manager = PersistenceManager.shared
/// try manager.save("token_123", forKey: "authToken", in: .keychain)
/// let token: String = try manager.load(forKey: "authToken", from: .keychain)
/// ```
public final class PersistenceManager: @unchecked Sendable {

    // MARK: - Singleton

    /// The shared persistence manager instance.
    public static let shared = PersistenceManager()

    // MARK: - Backend Stores

    /// The UserDefaults-backed store.
    public let defaults: DefaultsStore

    /// The Keychain-backed store.
    public let keychain: KeychainStore

    /// The file-system-backed store.
    public let fileStore: FileStore

    // MARK: - Publishers

    /// Publishes persistence events for observation.
    public let events = PassthroughSubject<PersistenceEvent, Never>()

    // MARK: - Storage Backend

    /// Enumerates the available storage backends.
    public enum Backend {
        /// UserDefaults storage — fast, unencrypted, small values.
        case userDefaults
        /// Keychain storage — encrypted, suitable for secrets.
        case keychain
        /// File system storage — for larger or structured data.
        case fileSystem
    }

    // MARK: - Events

    /// An event emitted by the persistence manager.
    public enum PersistenceEvent {
        /// A value was saved.
        case saved(key: String, backend: Backend)
        /// A value was loaded.
        case loaded(key: String, backend: Backend)
        /// A value was removed.
        case removed(key: String, backend: Backend)
        /// An error occurred.
        case error(PersistenceError)
    }

    // MARK: - Initialisation

    /// Creates a persistence manager with custom stores.
    ///
    /// - Parameters:
    ///   - defaults: The UserDefaults store to use.
    ///   - keychain: The Keychain store to use.
    ///   - fileStore: The file store to use.
    public init(
        defaults: DefaultsStore = DefaultsStore(),
        keychain: KeychainStore = KeychainStore(),
        fileStore: FileStore = FileStore()
    ) {
        self.defaults = defaults
        self.keychain = keychain
        self.fileStore = fileStore
    }

    // MARK: - Unified Save

    /// Saves an `Encodable` value to the specified backend.
    ///
    /// - Parameters:
    ///   - value: The value to persist.
    ///   - key: The storage key.
    ///   - backend: The target backend.
    /// - Throws: ``PersistenceError`` if encoding or writing fails.
    public func save<T: Encodable>(_ value: T, forKey key: String, in backend: Backend) throws {
        switch backend {
        case .userDefaults:
            try defaults.set(value, forKey: DefaultsKey<T>(key))
            events.send(.saved(key: key, backend: .userDefaults))

        case .keychain:
            let data = try encode(value)
            try keychain.save(data, forKey: key)
            events.send(.saved(key: key, backend: .keychain))

        case .fileSystem:
            let data = try encode(value)
            try fileStore.write(data, toFile: key)
            events.send(.saved(key: key, backend: .fileSystem))
        }
    }

    // MARK: - Unified Load

    /// Loads a `Decodable` value from the specified backend.
    ///
    /// - Parameters:
    ///   - key: The storage key.
    ///   - backend: The source backend.
    /// - Returns: The decoded value.
    /// - Throws: ``PersistenceError`` if reading or decoding fails.
    public func load<T: Decodable>(forKey key: String, from backend: Backend) throws -> T {
        let result: T

        switch backend {
        case .userDefaults:
            guard let value: T = try defaults.get(forKey: DefaultsKey<T>(key)) else {
                throw PersistenceError.notFound(key: key)
            }
            result = value

        case .keychain:
            let data = try keychain.load(forKey: key)
            result = try decode(data)

        case .fileSystem:
            let data = try fileStore.read(fromFile: key)
            result = try decode(data)
        }

        events.send(.loaded(key: key, backend: backend))
        return result
    }

    // MARK: - Unified Remove

    /// Removes the value associated with the key from the specified backend.
    ///
    /// - Parameters:
    ///   - key: The storage key.
    ///   - backend: The target backend.
    /// - Throws: ``PersistenceError`` if removal fails.
    public func remove(forKey key: String, from backend: Backend) throws {
        switch backend {
        case .userDefaults:
            defaults.remove(forKey: key)

        case .keychain:
            try keychain.delete(forKey: key)

        case .fileSystem:
            try fileStore.delete(file: key)
        }

        events.send(.removed(key: key, backend: backend))
    }

    // MARK: - Helpers

    /// Checks whether a value exists for the given key in the specified backend.
    ///
    /// - Parameters:
    ///   - key: The storage key.
    ///   - backend: The backend to check.
    /// - Returns: `true` if the key exists.
    public func exists(forKey key: String, in backend: Backend) -> Bool {
        switch backend {
        case .userDefaults:
            return defaults.contains(key: key)
        case .keychain:
            return keychain.exists(forKey: key)
        case .fileSystem:
            return fileStore.fileExists(name: key)
        }
    }

    /// Removes all data from every backend. Use with caution.
    public func purgeAll() throws {
        defaults.removeAll()
        try keychain.deleteAll()
        try fileStore.deleteAll()
    }

    // MARK: - Private Encoding / Decoding

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        do {
            return try JSONEncoder().encode(value)
        } catch {
            throw PersistenceError.encodingFailed(underlying: error)
        }
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw PersistenceError.decodingFailed(underlying: error)
        }
    }
}
