import Foundation

#if canImport(SwiftData)
import SwiftData

/// Describes a single model migration step.
///
/// Use `MigrationStep` to define transformations between schema versions.
/// The ``ModelMigrationPlan`` collects steps and applies them in order.
///
/// ```swift
/// let step = MigrationStep(
///     sourceVersion: "v1",
///     targetVersion: "v2",
///     migrate: { context in
///         // transform data
///     }
/// )
/// ```
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
public struct MigrationStep: Sendable {

    /// A human-readable label for the source schema version.
    public let sourceVersion: String

    /// A human-readable label for the target schema version.
    public let targetVersion: String

    /// The migration closure executed during the step.
    public let migrate: @Sendable () throws -> Void

    /// Creates a migration step.
    ///
    /// - Parameters:
    ///   - sourceVersion: The version string before migration.
    ///   - targetVersion: The version string after migration.
    ///   - migrate: The closure that performs the data transformation.
    public init(
        sourceVersion: String,
        targetVersion: String,
        migrate: @escaping @Sendable () throws -> Void
    ) {
        self.sourceVersion = sourceVersion
        self.targetVersion = targetVersion
        self.migrate = migrate
    }
}

/// Manages an ordered list of migration steps and executes them sequentially.
///
/// ```swift
/// let plan = ModelMigrationPlan()
/// plan.addStep(MigrationStep(sourceVersion: "v1", targetVersion: "v2") {
///     // migration logic
/// })
/// try plan.execute(from: "v1", to: "v2")
/// ```
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
public final class ModelMigrationPlan: @unchecked Sendable {

    // MARK: - Properties

    private var steps: [MigrationStep] = []
    private let lock = NSLock()

    /// The current schema version after the last successful migration.
    public private(set) var currentVersion: String?

    // MARK: - Initialisation

    /// Creates an empty migration plan.
    ///
    /// - Parameter currentVersion: The starting schema version, if known.
    public init(currentVersion: String? = nil) {
        self.currentVersion = currentVersion
    }

    // MARK: - Building

    /// Appends a migration step to the plan.
    ///
    /// - Parameter step: The step to add.
    public func addStep(_ step: MigrationStep) {
        lock.lock()
        defer { lock.unlock() }
        steps.append(step)
    }

    /// Appends multiple migration steps.
    ///
    /// - Parameter newSteps: An array of steps to add in order.
    public func addSteps(_ newSteps: [MigrationStep]) {
        lock.lock()
        defer { lock.unlock() }
        steps.append(contentsOf: newSteps)
    }

    // MARK: - Execution

    /// Executes all migration steps between the given versions.
    ///
    /// Steps are filtered to include only those whose `sourceVersion`
    /// falls within the range `[from, to)`.
    ///
    /// - Parameters:
    ///   - from: The starting version.
    ///   - to: The desired target version.
    /// - Throws: ``PersistenceError/migrationFailed(from:to:)`` if a step fails.
    public func execute(from: String, to: String) throws {
        lock.lock()
        let relevantSteps = steps.filter { $0.sourceVersion >= from && $0.targetVersion <= to }
        lock.unlock()

        guard !relevantSteps.isEmpty else {
            throw PersistenceError.migrationFailed(from: from, to: to)
        }

        for step in relevantSteps {
            do {
                try step.migrate()
                currentVersion = step.targetVersion
            } catch {
                throw PersistenceError.migrationFailed(
                    from: step.sourceVersion,
                    to: step.targetVersion
                )
            }
        }
    }

    /// Returns the number of registered migration steps.
    public var stepCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return steps.count
    }
}
#endif
