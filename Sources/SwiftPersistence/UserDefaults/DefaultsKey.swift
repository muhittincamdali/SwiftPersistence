import Foundation

/// A type-safe key for accessing values in ``DefaultsStore``.
///
/// `DefaultsKey` associates a string key with a specific `Codable` type,
/// ensuring compile-time safety when reading and writing UserDefaults.
///
/// ```swift
/// extension DefaultsKey {
///     static let username = DefaultsKey<String>("username")
///     static let launchCount = DefaultsKey<Int>("launchCount")
///     static let onboardingDone = DefaultsKey<Bool>("onboardingDone")
/// }
///
/// let store = DefaultsStore()
/// try store.set("Alice", forKey: .username)
/// ```
public struct DefaultsKey<Value: Codable>: Hashable, Sendable {

    /// The raw string key used in UserDefaults.
    public let rawValue: String

    /// Creates a new defaults key.
    ///
    /// - Parameter rawValue: The string identifier for this key.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }

    public static func == (lhs: DefaultsKey, rhs: DefaultsKey) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}

// MARK: - ExpressibleByStringLiteral

extension DefaultsKey: ExpressibleByStringLiteral {

    /// Creates a key from a string literal.
    ///
    /// - Parameter value: The string literal key.
    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension DefaultsKey: CustomStringConvertible {

    public var description: String {
        "DefaultsKey<\(Value.self)>(\"\(rawValue)\")"
    }
}
