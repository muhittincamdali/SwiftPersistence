import Foundation
import Combine

/// A property wrapper that persists values in UserDefaults.
///
/// Use `@Persisted` to bind a property directly to a UserDefaults key.
/// The wrapper handles encoding and decoding of `Codable` types
/// automatically using `JSONEncoder` / `JSONDecoder`.
///
/// ```swift
/// struct Settings {
///     @Persisted(key: "username", defaultValue: "Guest")
///     var username: String
///
///     @Persisted(key: "launchCount", defaultValue: 0)
///     var launchCount: Int
/// }
/// ```
@propertyWrapper
public struct Persisted<Value: Codable> {

    // MARK: - Properties

    private let key: String
    private let defaultValue: Value
    private let store: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Publisher

    /// A publisher that emits the current value whenever it changes.
    public var projectedValue: AnyPublisher<Value, Never> {
        store.publisher(for: key)
            .compactMap { [decoder] value -> Value? in
                guard let data = value as? Data else {
                    return value as? Value
                }
                return try? decoder.decode(Value.self, from: data)
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Initialisation

    /// Creates a new persisted property.
    ///
    /// - Parameters:
    ///   - key: The UserDefaults key.
    ///   - defaultValue: The fallback value when nothing is stored.
    ///   - store: The UserDefaults instance. Defaults to `.standard`.
    public init(
        key: String,
        defaultValue: Value,
        store: UserDefaults = .standard
    ) {
        self.key = key
        self.defaultValue = defaultValue
        self.store = store
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    // MARK: - Wrapped Value

    public var wrappedValue: Value {
        get {
            guard let data = store.data(forKey: key) else {
                // Try reading primitive types directly
                if let primitive = store.object(forKey: key) as? Value {
                    return primitive
                }
                return defaultValue
            }
            do {
                return try decoder.decode(Value.self, from: data)
            } catch {
                return defaultValue
            }
        }
        set {
            // Store primitives directly for interoperability
            if isPrimitive(newValue) {
                store.set(newValue, forKey: key)
            } else {
                let data = try? encoder.encode(newValue)
                store.set(data, forKey: key)
            }
        }
    }

    // MARK: - Helpers

    /// Resets the value back to the default and removes the stored entry.
    public mutating func reset() {
        store.removeObject(forKey: key)
    }

    /// Returns `true` if a value is currently persisted for this key.
    public var hasValue: Bool {
        store.object(forKey: key) != nil
    }

    // MARK: - Private

    private func isPrimitive(_ value: Value) -> Bool {
        value is Bool ||
        value is Int ||
        value is Double ||
        value is Float ||
        value is String
    }
}

// MARK: - UserDefaults Publisher Helper

private extension UserDefaults {

    /// Returns a notification-based publisher for a specific key.
    func publisher(for key: String) -> AnyPublisher<Any?, Never> {
        NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification, object: self)
            .map { [weak self] _ in self?.object(forKey: key) }
            .eraseToAnyPublisher()
    }
}
