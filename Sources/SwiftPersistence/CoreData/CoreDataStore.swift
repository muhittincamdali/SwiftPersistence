import Foundation
import CoreData

/// A lightweight wrapper around Core Data's `NSPersistentContainer`.
///
/// `CoreDataStore` simplifies common Core Data operations by providing
/// type-safe fetch, insert, update, and delete methods that map errors
/// to ``PersistenceError``.
///
/// ```swift
/// let store = CoreDataStore(modelName: "MyApp")
/// try store.loadPersistentStores()
///
/// let users: [NSManagedObject] = try store.fetch(entityName: "User")
/// ```
public final class CoreDataStore: @unchecked Sendable {

    // MARK: - Properties

    /// The underlying persistent container.
    public let container: NSPersistentContainer

    /// The main-queue managed object context.
    public var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    // MARK: - Initialisation

    /// Creates a store backed by the named Core Data model.
    ///
    /// - Parameter modelName: The `.xcdatamodeld` file name (without extension).
    public init(modelName: String) {
        self.container = NSPersistentContainer(name: modelName)
    }

    /// Creates a store with an existing container.
    ///
    /// - Parameter container: A pre-configured persistent container.
    public init(container: NSPersistentContainer) {
        self.container = container
    }

    // MARK: - Setup

    /// Loads the persistent stores. Call this once during app launch.
    ///
    /// - Throws: ``PersistenceError/coreDataError(underlying:)`` on failure.
    public func loadPersistentStores() throws {
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw PersistenceError.coreDataError(underlying: loadError)
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Fetch

    /// Fetches all objects for the given entity name.
    ///
    /// - Parameters:
    ///   - entityName: The Core Data entity name.
    ///   - predicate: An optional `NSPredicate` filter.
    ///   - sortDescriptors: Optional sort descriptors.
    /// - Returns: An array of managed objects.
    /// - Throws: ``PersistenceError/coreDataError(underlying:)`` on failure.
    public func fetch(
        entityName: String,
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil
    ) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors

        do {
            return try viewContext.fetch(request)
        } catch {
            throw PersistenceError.coreDataError(underlying: error)
        }
    }

    /// Returns the count of objects matching the entity and predicate.
    ///
    /// - Parameters:
    ///   - entityName: The Core Data entity name.
    ///   - predicate: An optional filter.
    /// - Returns: The number of matching objects.
    public func count(entityName: String, predicate: NSPredicate? = nil) throws -> Int {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = predicate

        do {
            return try viewContext.count(for: request)
        } catch {
            throw PersistenceError.coreDataError(underlying: error)
        }
    }

    // MARK: - Insert

    /// Creates and returns a new managed object for the given entity.
    ///
    /// - Parameter entityName: The Core Data entity name.
    /// - Returns: The newly inserted managed object.
    public func insert(entityName: String) -> NSManagedObject {
        NSEntityDescription.insertNewObject(forEntityName: entityName, into: viewContext)
    }

    // MARK: - Delete

    /// Deletes a managed object from the context.
    ///
    /// - Parameter object: The object to delete.
    public func delete(_ object: NSManagedObject) {
        viewContext.delete(object)
    }

    /// Deletes all objects for the given entity.
    ///
    /// - Parameter entityName: The entity name to purge.
    /// - Throws: ``PersistenceError/coreDataError(underlying:)`` on failure.
    public func deleteAll(entityName: String) throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let batchDelete = NSBatchDeleteRequest(fetchRequest: request)

        do {
            try viewContext.execute(batchDelete)
        } catch {
            throw PersistenceError.coreDataError(underlying: error)
        }
    }

    // MARK: - Save

    /// Saves all pending changes in the view context.
    ///
    /// - Throws: ``PersistenceError/coreDataError(underlying:)`` on failure.
    public func save() throws {
        guard viewContext.hasChanges else { return }
        do {
            try viewContext.save()
        } catch {
            throw PersistenceError.coreDataError(underlying: error)
        }
    }

    // MARK: - Background

    /// Performs work on a background context and saves.
    ///
    /// - Parameter block: The work to perform with a background context.
    /// - Throws: ``PersistenceError/coreDataError(underlying:)`` on failure.
    public func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask(block)
    }
}
