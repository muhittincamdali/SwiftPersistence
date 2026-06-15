import Foundation

/// SwiftPersistence: Framework-Agnostic Repository
/// 
/// Completely decouples the UI layer from the underlying database (CoreData/SwiftData/SQLite).
/// Allows swapping persistence engines with zero changes to business logic.
public protocol AgnosticRepository: Sendable {
    associatedtype Model: Sendable
    
    /// Saves an item to the configured persistence engine.
    func save(_ item: Model) async throws
    
    /// Fetches all items from the configured persistence engine.
    func fetchAll() async throws -> [Model]
}
