import Foundation

/// A type-safe wrapper around `UserDefaults`.
///
/// `DefaultsStore` leverages ``DefaultsKey`` to provide compile-time
/// type checking for all read and write operations. Values are encoded
/// as JSON for complex types, while primitives are stored directly.
///
/// ```swift
/// let store = DefaultsStore()
/// try store.set("dark", forKey: DefaultsKey<String>("theme"))
/// let theme: String? = try store.get(forKey: DefaultsKey<String>("theme"))
/// ```
public final class DefaultsStore: @unchecked Sendable {

    // MARK: - Properties

    private let suite: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Initialisation

    /// Creates a defaults store backed by the given suite.
    ///
    /// - Parameter suite: The `UserDefaults` suite. Defaults to `.standard`.
    public init(suite: UserDefaults = .standard) {
        self.suite = suite
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    // MARK: - Read

    /// Retrieves the value for the given key.
    ///
    /// - Parameter key: The typed defaults key.
    /// - Returns: The decoded value, or `nil` if not present.
    /// - Throws: ``PersistenceError/decodingFailed(underlying:)`` on decode failure.
    public func get<T: Codable>(forKey key: DefaultsKey<T>) throws -> T? {
        // Try direct primitive read first
        if let value = suite.object(forKey: key.rawValue) as? T {
            return value
        }

        guard let data = suite.data(forKey: key.rawValue) else {
            return nil
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw PersistenceError.decodingFailed(underlying: error)
        }
    }

    // MARK: - Write

    /// Stores a value for the given key.
    ///
    /// Primitive types (`Bool`, `Int`, `Double`, `Float`, `String`) are
    /// stored directly. All other `Codable` types are JSON-encoded.
    ///
    /// - Parameters:
    ///   - value: The value to store.
    ///   - key: The typed defaults key.
    /// - Throws: ``PersistenceError/encodingFailed(underlying:)`` on encode failure.
    public func set<T: Codable>(_ value: T, forKey key: DefaultsKey<T>) throws {
        if isPrimitive(value) {
            suite.set(value, forKey: key.rawValue)
        } else {
            do {
                let data = try encoder.encode(value)
                suite.set(data, forKey: key.rawValue)
            } catch {
                throw PersistenceError.encodingFailed(underlying: error)
            }
        }
    }

    // MARK: - Remove

    /// Removes the value associated with the given key.
    ///
    /// - Parameter key: The raw string key to remove.
    public func remove(forKey key: String) {
        suite.removeObject(forKey: key)
    }

    /// Removes the value for a typed key.
    ///
    /// - Parameter key: The typed defaults key.
    public func remove<T>(forKey key: DefaultsKey<T>) {
        suite.removeObject(forKey: key.rawValue)
    }

    // MARK: - Query

    /// Returns `true` if a value exists for the raw key.
    ///
    /// - Parameter key: The string key to check.
    /// - Returns: Whether the key has an associated value.
    public func contains(key: String) -> Bool {
        suite.object(forKey: key) != nil
    }

    /// Removes all keys from the suite.
    public func removeAll() {
        guard let domain = Bundle.main.bundleIdentifier else { return }
        suite.removePersistentDomain(forName: domain)
        suite.synchronize()
    }

    // MARK: - Private

    private func isPrimitive<T>(_ value: T) -> Bool {
        value is Bool || value is Int || value is Double || value is Float || value is String
    }
}
