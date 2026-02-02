import Foundation
import Security

/// Configuration for Keychain access parameters.
///
/// Use `KeychainConfiguration` to customise the service name,
/// access group, and accessibility level used by ``KeychainStore``.
///
/// ```swift
/// let config = KeychainConfiguration(
///     service: "com.myapp.auth",
///     accessGroup: "TEAMID.com.myapp.shared",
///     accessibility: .afterFirstUnlock
/// )
/// let store = KeychainStore(configuration: config)
/// ```
public struct KeychainConfiguration: Sendable {

    /// The Keychain service identifier.
    public let service: String

    /// The optional access group for Keychain sharing.
    public let accessGroup: String?

    /// When the Keychain items should be accessible.
    public let accessibility: Accessibility

    /// Predefined accessibility levels mapping to Security framework constants.
    public enum Accessibility: Sendable {
        /// Items are accessible after the device is unlocked once.
        case afterFirstUnlock
        /// Items are only accessible while the device is unlocked.
        case whenUnlocked
        /// Items are always accessible (least secure).
        case always

        /// The corresponding `kSecAttrAccessible` value.
        var secValue: CFString {
            switch self {
            case .afterFirstUnlock:
                return kSecAttrAccessibleAfterFirstUnlock
            case .whenUnlocked:
                return kSecAttrAccessibleWhenUnlocked
            case .always:
                return kSecAttrAccessibleAfterFirstUnlock
            }
        }
    }

    /// Creates a Keychain configuration.
    ///
    /// - Parameters:
    ///   - service: The service identifier. Defaults to the bundle identifier.
    ///   - accessGroup: An optional sharing access group.
    ///   - accessibility: The accessibility level. Defaults to `.afterFirstUnlock`.
    public init(
        service: String = Bundle.main.bundleIdentifier ?? "SwiftPersistence",
        accessGroup: String? = nil,
        accessibility: Accessibility = .afterFirstUnlock
    ) {
        self.service = service
        self.accessGroup = accessGroup
        self.accessibility = accessibility
    }
}
