import Foundation
import Security

/// A property wrapper that persists values securely in the Keychain.
///
/// Use `@SecurePersisted` for sensitive data such as authentication tokens,
/// passwords, or API keys. Values are encoded with `JSONEncoder` before
/// being written to the system Keychain.
///
/// ```swift
/// struct Credentials {
///     @SecurePersisted(key: "auth_token")
///     var authToken: String?
///
///     @SecurePersisted(key: "refresh_token", service: "com.app.auth")
///     var refreshToken: String?
/// }
/// ```
@propertyWrapper
public struct SecurePersisted<Value: Codable> {

    // MARK: - Properties

    private let key: String
    private let service: String
    private let accessGroup: String?
    private let accessibility: CFString
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Initialisation

    /// Creates a new Keychain-backed persisted property.
    ///
    /// - Parameters:
    ///   - key: The Keychain account identifier.
    ///   - service: The Keychain service name. Defaults to the bundle identifier.
    ///   - accessGroup: Optional Keychain sharing access group.
    ///   - accessibility: When the item is accessible. Defaults to after first unlock.
    public init(
        key: String,
        service: String = Bundle.main.bundleIdentifier ?? "SwiftPersistence",
        accessGroup: String? = nil,
        accessibility: CFString = kSecAttrAccessibleAfterFirstUnlock
    ) {
        self.key = key
        self.service = service
        self.accessGroup = accessGroup
        self.accessibility = accessibility
    }

    // MARK: - Wrapped Value

    public var wrappedValue: Value? {
        get {
            guard let data = readFromKeychain() else { return nil }
            return try? decoder.decode(Value.self, from: data)
        }
        set {
            if let newValue {
                guard let data = try? encoder.encode(newValue) else { return }
                saveToKeychain(data)
            } else {
                deleteFromKeychain()
            }
        }
    }

    // MARK: - Keychain Operations

    private func baseQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecAttrAccessible as String: accessibility
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    private func readFromKeychain() -> Data? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query.removeValue(forKey: kSecAttrAccessible as String)

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func saveToKeychain(_ data: Data) {
        deleteFromKeychain()

        var query = baseQuery()
        query[kSecValueData as String] = data

        SecItemAdd(query as CFDictionary, nil)
    }

    private func deleteFromKeychain() {
        var query = baseQuery()
        query.removeValue(forKey: kSecAttrAccessible as String)
        SecItemDelete(query as CFDictionary)
    }
}
