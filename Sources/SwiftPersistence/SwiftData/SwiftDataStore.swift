import Foundation

#if canImport(SwiftData)
import SwiftData

/// A convenience wrapper around SwiftData for common CRUD operations.
///
/// `SwiftDataStore` simplifies working with `ModelContext` by providing
/// generic fetch, insert, update, and delete helpers with built-in
/// error mapping to ``PersistenceError``.
///
/// ```swift
/// let store = try SwiftDataStore(for: User.self, Item.self)
/// let users: [User] = try store.fetchAll()
/// try store.insert(newUser)
/// try store.save()
/// ```
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
public final class SwiftDataStore {

    // MARK: - Properties

    /// The underlying model container.
    public let container: ModelContainer

    /// The main-actor-bound model context.
    @MainActor
    public var context: ModelContext {
        container.mainContext
    }

    // MARK: - Initialisation

    /// Creates a store with the given persistent model types.
    ///
    /// - Parameters:
    ///   - types: The `PersistentModel` types to register.
    ///   - configuration: An optional model configuration.
    /// - Throws: ``PersistenceError/swiftDataError(underlying:)`` on failure.
    public init(
        for types: any PersistentModel.Type...,
        configuration: ModelConfiguration? = nil
    ) throws {
        do {
            let schema = Schema(types)
            if let configuration {
                self.container = try ModelContainer(for: schema, configurations: [configuration])
            } else {
                self.container = try ModelContainer(for: schema)
            }
        } catch {
            throw PersistenceError.swiftDataError(underlying: error)
        }
    }

    /// Creates a store with an existing `ModelContainer`.
    ///
    /// - Parameter container: The container to use.
    public init(container: ModelContainer) {
        self.container = container
    }

    // MARK: - Fetch

    /// Fetches all models matching the given predicate.
    ///
    /// - Parameters:
    ///   - predicate: An optional filter predicate.
    ///   - sortBy: Sort descriptors to apply.
    /// - Returns: An array of matching models.
    /// - Throws: ``PersistenceError/swiftDataError(underlying:)`` on failure.
    @MainActor
    public func fetchAll<T: PersistentModel>(
        predicate: Predicate<T>? = nil,
        sortBy: [SortDescriptor<T>] = []
    ) throws -> [T] {
        do {
            var descriptor = FetchDescriptor<T>(predicate: predicate, sortBy: sortBy)
            descriptor.fetchLimit = nil
            return try context.fetch(descriptor)
        } catch {
            throw PersistenceError.swiftDataError(underlying: error)
        }
    }

    /// Fetches the first model matching the predicate.
    ///
    /// - Parameter predicate: The filter predicate.
    /// - Returns: The first match, or `nil` if none found.
    @MainActor
    public func fetchFirst<T: PersistentModel>(
        predicate: Predicate<T>? = nil
    ) throws -> T? {
        do {
            var descriptor = FetchDescriptor<T>(predicate: predicate)
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first
        } catch {
            throw PersistenceError.swiftDataError(underlying: error)
        }
    }

    /// Returns the total number of models of the given type.
    ///
    /// - Parameter predicate: An optional filter.
    /// - Returns: The count of matching models.
    @MainActor
    public func count<T: PersistentModel>(
        predicate: Predicate<T>? = nil
    ) throws -> Int {
        do {
            let descriptor = FetchDescriptor<T>(predicate: predicate)
            return try context.fetchCount(descriptor)
        } catch {
            throw PersistenceError.swiftDataError(underlying: error)
        }
    }

    // MARK: - Insert

    /// Inserts a new model into the context.
    ///
    /// - Parameter model: The model instance to insert.
    @MainActor
    public func insert<T: PersistentModel>(_ model: T) {
        context.insert(model)
    }

    /// Inserts multiple models into the context.
    ///
    /// - Parameter models: The model instances to insert.
    @MainActor
    public func insertBatch<T: PersistentModel>(_ models: [T]) {
        for model in models {
            context.insert(model)
        }
    }

    // MARK: - Delete

    /// Deletes a model from the context.
    ///
    /// - Parameter model: The model to remove.
    @MainActor
    public func delete<T: PersistentModel>(_ model: T) {
        context.delete(model)
    }

    /// Deletes all models matching the predicate.
    ///
    /// - Parameter predicate: The filter for deletion.
    @MainActor
    public func deleteAll<T: PersistentModel>(
        _ type: T.Type,
        predicate: Predicate<T>? = nil
    ) throws {
        let models = try fetchAll(predicate: predicate) as [T]
        for model in models {
            context.delete(model)
        }
    }

    // MARK: - Save

    /// Persists all pending changes in the context.
    ///
    /// - Throws: ``PersistenceError/swiftDataError(underlying:)`` on failure.
    @MainActor
    public func save() throws {
        do {
            try context.save()
        } catch {
            throw PersistenceError.swiftDataError(underlying: error)
        }
    }
}
#endif
