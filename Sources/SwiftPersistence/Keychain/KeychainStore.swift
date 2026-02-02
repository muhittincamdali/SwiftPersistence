import Foundation
import Security

/// A type-safe wrapper for Keychain Services.
///
/// `KeychainStore` provides simple CRUD operations for storing `Data` blobs
/// in the system Keychain. All operations map errors to ``PersistenceError``.
///
/// ```swift
/// let store = KeychainStore()
/// try store.save(tokenData, forKey: "auth_token")
/// let data = try store.load(forKey: "auth_token")
/// try store.delete(forKey: "auth_token")
/// ```
public final class KeychainStore: @unchecked Sendable {

    // MARK: - Properties

    private let configuration: KeychainConfiguration
    private let lock = NSLock()

    // MARK: - Initialisation

    /// Creates a Keychain store with the given configuration.
    ///
    /// - Parameter configuration: The Keychain configuration. Defaults to standard settings.
    public init(configuration: KeychainConfiguration = KeychainConfiguration()) {
        self.configuration = configuration
    }

    /// Convenience initialiser that creates a store with default configuration.
    public convenience init() {
        self.init(configuration: KeychainConfiguration())
    }

    // MARK: - Save

    /// Saves data to the Keychain for the given key.
    ///
    /// If an entry already exists for the key, it is updated.
    ///
    /// - Parameters:
    ///   - data: The data to store.
    ///   - key: The account identifier.
    /// - Throws: ``PersistenceError/keychainError(status:)`` on failure.
    public func save(_ data: Data, forKey key: String) throws {
        lock.lock()
        defer { lock.unlock() }

        // Attempt to update first
        let updateQuery = baseQuery(for: key)
        let attributes: [String: Any] = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus != errSecItemNotFound {
            throw PersistenceError.keychainError(status: updateStatus)
        }

        // Item doesn't exist yet — add it
        var addQuery = baseQuery(for: key)
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = configuration.accessibility.secValue

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        guard addStatus == errSecSuccess else {
            throw PersistenceError.keychainError(status: addStatus)
        }
    }

    // MARK: - Load

    /// Loads data from the Keychain for the given key.
    ///
    /// - Parameter key: The account identifier.
    /// - Returns: The stored data.
    /// - Throws: ``PersistenceError/notFound(key:)`` if missing,
    ///           ``PersistenceError/keychainError(status:)`` on failure.
    public func load(forKey key: String) throws -> Data {
        lock.lock()
        defer { lock.unlock() }

        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            throw PersistenceError.notFound(key: key)
        }

        guard status == errSecSuccess, let data = result as? Data else {
            throw PersistenceError.keychainError(status: status)
        }

        return data
    }

    // MARK: - Delete

    /// Deletes the Keychain entry for the given key.
    ///
    /// - Parameter key: The account identifier.
    /// - Throws: ``PersistenceError/keychainError(status:)`` on failure.
    public func delete(forKey key: String) throws {
        lock.lock()
        defer { lock.unlock() }

        let query = baseQuery(for: key)
        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PersistenceError.keychainError(status: status)
        }
    }

    /// Deletes all items for the configured service.
    ///
    /// - Throws: ``PersistenceError/keychainError(status:)`` on failure.
    public func deleteAll() throws {
        lock.lock()
        defer { lock.unlock() }

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: configuration.service
        ]

        if let group = configuration.accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PersistenceError.keychainError(status: status)
        }
    }

    // MARK: - Query

    /// Checks whether a Keychain entry exists for the given key.
    ///
    /// - Parameter key: The account identifier.
    /// - Returns: `true` if the key has a stored value.
    public func exists(forKey key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        var query = baseQuery(for: key)
        query[kSecReturnData as String] = false

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Private

    private func baseQuery(for key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: configuration.service,
            kSecAttrAccount as String: key
        ]

        if let group = configuration.accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }

        return query
    }
}
