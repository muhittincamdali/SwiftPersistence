import Foundation
import Combine

/// A lightweight engine for synchronising key-value data with iCloud.
///
/// `CloudSyncEngine` wraps `NSUbiquitousKeyValueStore` and publishes
/// change notifications so your app can react to remote updates.
///
/// ```swift
/// let engine = CloudSyncEngine()
/// engine.startObserving()
///
/// engine.set("dark", forKey: "theme")
/// let theme: String? = engine.string(forKey: "theme")
/// ```
public final class CloudSyncEngine: @unchecked Sendable {

    // MARK: - Properties

    private let store: NSUbiquitousKeyValueStore
    private let changeSubject = PassthroughSubject<CloudChange, Never>()
    private var observation: Any?

    /// Publishes iCloud change events.
    public var changes: AnyPublisher<CloudChange, Never> {
        changeSubject.eraseToAnyPublisher()
    }

    // MARK: - Types

    /// Represents a batch of changes received from iCloud.
    public struct CloudChange: Sendable {
        /// The reason for the change.
        public let reason: ChangeReason
        /// The keys that were modified.
        public let changedKeys: [String]
    }

    /// The reason an iCloud key-value change occurred.
    public enum ChangeReason: Int, Sendable {
        /// The server had newer values.
        case serverChange = 0
        /// Initial sync after first launch.
        case initialSync = 1
        /// Local storage quota was exceeded.
        case quotaViolation = 2
        /// An account-related change occurred.
        case accountChange = 3
        /// Unknown reason.
        case unknown = -1
    }

    // MARK: - Initialisation

    /// Creates a sync engine with the given ubiquitous store.
    ///
    /// - Parameter store: The iCloud key-value store. Defaults to `.default`.
    public init(store: NSUbiquitousKeyValueStore = .default) {
        self.store = store
    }

    deinit {
        stopObserving()
    }

    // MARK: - Observation

    /// Begins observing iCloud key-value store changes.
    public func startObserving() {
        observation = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] notification in
            self?.handleExternalChange(notification)
        }

        store.synchronize()
    }

    /// Stops observing iCloud changes.
    public func stopObserving() {
        if let observation {
            NotificationCenter.default.removeObserver(observation)
        }
        observation = nil
    }

    // MARK: - Read

    /// Returns the string value for the given key.
    public func string(forKey key: String) -> String? {
        store.string(forKey: key)
    }

    /// Returns the data value for the given key.
    public func data(forKey key: String) -> Data? {
        store.data(forKey: key)
    }

    /// Returns the boolean value for the given key.
    public func bool(forKey key: String) -> Bool {
        store.bool(forKey: key)
    }

    /// Returns the integer value for the given key.
    public func integer(forKey key: String) -> Int64 {
        store.longLong(forKey: key)
    }

    /// Returns the double value for the given key.
    public func double(forKey key: String) -> Double {
        store.double(forKey: key)
    }

    // MARK: - Write

    /// Sets a string value in the iCloud store.
    public func set(_ value: String, forKey key: String) {
        store.set(value, forKey: key)
    }

    /// Sets a data value in the iCloud store.
    public func set(_ value: Data, forKey key: String) {
        store.set(value, forKey: key)
    }

    /// Sets a boolean value in the iCloud store.
    public func set(_ value: Bool, forKey key: String) {
        store.set(value, forKey: key)
    }

    /// Sets an integer value in the iCloud store.
    public func set(_ value: Int64, forKey key: String) {
        store.set(value, forKey: key)
    }

    /// Sets a double value in the iCloud store.
    public func set(_ value: Double, forKey key: String) {
        store.set(value, forKey: key)
    }

    // MARK: - Remove

    /// Removes the value for the given key.
    public func removeObject(forKey key: String) {
        store.removeObject(forKey: key)
    }

    // MARK: - Sync

    /// Forces a synchronisation with iCloud.
    ///
    /// - Returns: `true` if the sync was initiated successfully.
    @discardableResult
    public func synchronize() -> Bool {
        store.synchronize()
    }

    // MARK: - Private

    private func handleExternalChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }

        let reasonValue = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int ?? -1
        let reason = ChangeReason(rawValue: reasonValue) ?? .unknown

        let keys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []

        let change = CloudChange(reason: reason, changedKeys: keys)
        changeSubject.send(change)
    }
}
