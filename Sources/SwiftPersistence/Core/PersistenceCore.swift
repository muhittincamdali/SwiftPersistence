import Foundation

/// Main entry point for the SwiftPersistence toolkit.
public enum SwiftPersistence {
    public static let version = "2.0.0"
}

/// A protocol for storable objects.
public protocol Storable: Codable, Sendable, Identifiable {
    associatedtype ID: Hashable & Sendable
    var id: ID { get }
}

/// A protocol for persistence engines.
public protocol PersistenceEngine: Sendable {
    func save<T: Storable>(_ object: T) async throws
    func fetch<T: Storable>(_ type: T.Type, id: T.ID) async throws -> T?
    func delete<T: Storable>(_ type: T.Type, id: T.ID) async throws
}
