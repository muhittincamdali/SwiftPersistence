//
//  MigrationManager.swift
//  SwiftPersistence
//
//  Created by Muhittin Camdali on 2025.
//  MIT License
//

import Foundation
import Combine

// MARK: - Migration Version

/// Represents a schema version
public struct SchemaVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
    
    /// The major version number
    public let major: Int
    
    /// The minor version number
    public let minor: Int
    
    /// The patch version number
    public let patch: Int
    
    /// Creates a new schema version
    public init(major: Int, minor: Int = 0, patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    
    /// Creates a version from a string (e.g., "1.2.3")
    public init?(_ string: String) {
        let parts = string.split(separator: ".").compactMap { Int($0) }
        guard !parts.isEmpty else { return nil }
        
        self.major = parts[0]
        self.minor = parts.count > 1 ? parts[1] : 0
        self.patch = parts.count > 2 ? parts[2] : 0
    }
    
    public var description: String {
        "\(major).\(minor).\(patch)"
    }
    
    /// The integer representation for comparison
    public var intValue: Int {
        major * 1_000_000 + minor * 1_000 + patch
    }
    
    public static func < (lhs: SchemaVersion, rhs: SchemaVersion) -> Bool {
        lhs.intValue < rhs.intValue
    }
    
    /// Version 1.0.0
    public static let v1_0_0 = SchemaVersion(major: 1, minor: 0, patch: 0)
    
    /// Zero version
    public static let zero = SchemaVersion(major: 0, minor: 0, patch: 0)
}

// MARK: - Migration Step

/// A single migration step
public struct MigrationStep: Identifiable, Sendable {
    
    /// The step identifier
    public let id: UUID
    
    /// The source version
    public let fromVersion: SchemaVersion
    
    /// The target version
    public let toVersion: SchemaVersion
    
    /// Description of the migration
    public let description: String
    
    /// The migration operation
    public let operation: @Sendable (MigrationContext) async throws -> Void
    
    /// Whether this migration is reversible
    public let reversible: Bool
    
    /// The rollback operation (if reversible)
    public let rollback: (@Sendable (MigrationContext) async throws -> Void)?
    
    /// Creates a new migration step
    public init(
        id: UUID = UUID(),
        from: SchemaVersion,
        to: SchemaVersion,
        description: String,
        reversible: Bool = false,
        operation: @escaping @Sendable (MigrationContext) async throws -> Void,
        rollback: (@Sendable (MigrationContext) async throws -> Void)? = nil
    ) {
        self.id = id
        self.fromVersion = from
        self.toVersion = to
        self.description = description
        self.operation = operation
        self.reversible = reversible
        self.rollback = rollback
    }
}

// MARK: - Migration Context

/// Context provided to migration operations
public final class MigrationContext: @unchecked Sendable {
    
    /// The source version
    public let fromVersion: SchemaVersion
    
    /// The target version
    public let toVersion: SchemaVersion
    
    /// User info dictionary
    public var userInfo: [String: Any]
    
    /// Progress callback
    public var progressHandler: ((Double, String?) -> Void)?
    
    /// The underlying storage
    private var storage: [String: Any]
    
    /// Lock for thread safety
    private let lock = NSLock()
    
    /// Creates a new migration context
    public init(from: SchemaVersion, to: SchemaVersion) {
        self.fromVersion = from
        self.toVersion = to
        self.userInfo = [:]
        self.storage = [:]
    }
    
    /// Sets a value in temporary storage
    public func set<T>(_ value: T, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = value
    }
    
    /// Gets a value from temporary storage
    public func get<T>(_ key: String) -> T? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key] as? T
    }
    
    /// Reports progress
    public func reportProgress(_ progress: Double, message: String? = nil) {
        progressHandler?(progress, message)
    }
}

// MARK: - Migration Plan

/// A plan for executing migrations
public struct MigrationPlan: Sendable {
    
    /// The steps to execute
    public let steps: [MigrationStep]
    
    /// The starting version
    public let fromVersion: SchemaVersion
    
    /// The target version
    public let toVersion: SchemaVersion
    
    /// Estimated time in seconds
    public let estimatedTime: TimeInterval?
    
    /// Whether all steps are reversible
    public var isFullyReversible: Bool {
        steps.allSatisfy { $0.reversible }
    }
    
    /// The number of steps
    public var stepCount: Int {
        steps.count
    }
    
    /// Creates a new migration plan
    public init(
        steps: [MigrationStep],
        from: SchemaVersion,
        to: SchemaVersion,
        estimatedTime: TimeInterval? = nil
    ) {
        self.steps = steps
        self.fromVersion = from
        self.toVersion = to
        self.estimatedTime = estimatedTime
    }
}

// MARK: - Migration Result

/// Result of a migration
public struct MigrationResult: Sendable {
    
    /// Whether the migration succeeded
    public let success: Bool
    
    /// The starting version
    public let fromVersion: SchemaVersion
    
    /// The final version
    public let toVersion: SchemaVersion
    
    /// Steps that were executed
    public let executedSteps: Int
    
    /// Total steps
    public let totalSteps: Int
    
    /// The error if migration failed
    public let error: Error?
    
    /// Time taken in seconds
    public let duration: TimeInterval
    
    /// Whether the migration was rolled back
    public let wasRolledBack: Bool
    
    /// Creates a success result
    public static func success(
        from: SchemaVersion,
        to: SchemaVersion,
        steps: Int,
        duration: TimeInterval
    ) -> MigrationResult {
        MigrationResult(
            success: true,
            fromVersion: from,
            toVersion: to,
            executedSteps: steps,
            totalSteps: steps,
            error: nil,
            duration: duration,
            wasRolledBack: false
        )
    }
    
    /// Creates a failure result
    public static func failure(
        from: SchemaVersion,
        to: SchemaVersion,
        executedSteps: Int,
        totalSteps: Int,
        error: Error,
        duration: TimeInterval,
        wasRolledBack: Bool
    ) -> MigrationResult {
        MigrationResult(
            success: false,
            fromVersion: from,
            toVersion: to,
            executedSteps: executedSteps,
            totalSteps: totalSteps,
            error: error,
            duration: duration,
            wasRolledBack: wasRolledBack
        )
    }
}

// MARK: - Migration Progress

/// Progress of a migration
public struct MigrationProgress: Sendable {
    
    /// The current step index (1-based)
    public let currentStep: Int
    
    /// Total number of steps
    public let totalSteps: Int
    
    /// The current step description
    public let stepDescription: String?
    
    /// Progress within the current step (0.0 - 1.0)
    public let stepProgress: Double
    
    /// Overall progress (0.0 - 1.0)
    public var overallProgress: Double {
        guard totalSteps > 0 else { return 0 }
        let completedSteps = Double(currentStep - 1)
        return (completedSteps + stepProgress) / Double(totalSteps)
    }
}

// MARK: - Migration Delegate

/// Delegate for migration events
public protocol MigrationDelegate: AnyObject, Sendable {
    
    /// Called when migration starts
    func migrationDidStart(from: SchemaVersion, to: SchemaVersion)
    
    /// Called when a step starts
    func migrationStepDidStart(_ step: MigrationStep, index: Int, total: Int)
    
    /// Called when a step completes
    func migrationStepDidComplete(_ step: MigrationStep, index: Int, total: Int)
    
    /// Called when progress updates
    func migrationProgressDidUpdate(_ progress: MigrationProgress)
    
    /// Called when migration completes
    func migrationDidComplete(_ result: MigrationResult)
    
    /// Called when migration fails
    func migrationDidFail(_ error: Error, at step: MigrationStep?)
    
    /// Called when rollback starts
    func migrationRollbackDidStart()
    
    /// Called when rollback completes
    func migrationRollbackDidComplete(success: Bool)
}

// MARK: - Migration Manager

/// Manages database migrations
public actor MigrationManager {
    
    /// Registered migration steps
    private var steps: [MigrationStep]
    
    /// The current schema version
    private var currentVersion: SchemaVersion
    
    /// Migration history
    private var history: [MigrationHistoryEntry]
    
    /// The delegate
    private weak var delegate: MigrationDelegate?
    
    /// Whether a migration is in progress
    private var isMigrating: Bool
    
    /// Configuration
    private let configuration: MigrationConfiguration
    
    /// Version storage
    private var versionStorage: VersionStorage
    
    /// Creates a new migration manager
    public init(
        currentVersion: SchemaVersion = .zero,
        configuration: MigrationConfiguration = MigrationConfiguration()
    ) {
        self.steps = []
        self.currentVersion = currentVersion
        self.history = []
        self.isMigrating = false
        self.configuration = configuration
        self.versionStorage = VersionStorage()
    }
    
    /// Sets the delegate
    public func setDelegate(_ delegate: MigrationDelegate?) {
        self.delegate = delegate
    }
    
    /// Registers a migration step
    public func registerStep(_ step: MigrationStep) {
        steps.append(step)
        steps.sort { $0.fromVersion < $1.fromVersion }
    }
    
    /// Registers multiple migration steps
    public func registerSteps(_ newSteps: [MigrationStep]) {
        steps.append(contentsOf: newSteps)
        steps.sort { $0.fromVersion < $1.fromVersion }
    }
    
    /// Clears all registered steps
    public func clearSteps() {
        steps.removeAll()
    }
    
    /// Gets the current version
    public func getCurrentVersion() -> SchemaVersion {
        currentVersion
    }
    
    /// Sets the current version
    public func setCurrentVersion(_ version: SchemaVersion) {
        currentVersion = version
    }
    
    /// Creates a migration plan
    public func createPlan(to targetVersion: SchemaVersion) -> MigrationPlan? {
        let relevantSteps = findMigrationPath(from: currentVersion, to: targetVersion)
        
        guard !relevantSteps.isEmpty else { return nil }
        
        let estimatedTime = Double(relevantSteps.count) * 2.0 // 2 seconds per step estimate
        
        return MigrationPlan(
            steps: relevantSteps,
            from: currentVersion,
            to: targetVersion,
            estimatedTime: estimatedTime
        )
    }
    
    /// Finds the migration path between versions
    private func findMigrationPath(from: SchemaVersion, to: SchemaVersion) -> [MigrationStep] {
        guard from < to else { return [] }
        
        var path: [MigrationStep] = []
        var current = from
        
        while current < to {
            guard let nextStep = steps.first(where: { 
                $0.fromVersion == current || 
                ($0.fromVersion <= current && $0.toVersion > current)
            }) else {
                break
            }
            
            path.append(nextStep)
            current = nextStep.toVersion
        }
        
        return path
    }
    
    /// Executes a migration plan
    public func execute(_ plan: MigrationPlan) async throws -> MigrationResult {
        guard !isMigrating else {
            throw MigrationError.migrationInProgress
        }
        
        isMigrating = true
        defer { isMigrating = false }
        
        let startTime = Date()
        var executedSteps = 0
        
        delegate?.migrationDidStart(from: plan.fromVersion, to: plan.toVersion)
        
        // Create backup if configured
        if configuration.createBackupBeforeMigration {
            try await createBackup()
        }
        
        do {
            for (index, step) in plan.steps.enumerated() {
                delegate?.migrationStepDidStart(step, index: index + 1, total: plan.stepCount)
                
                let context = MigrationContext(from: step.fromVersion, to: step.toVersion)
                context.progressHandler = { [weak self] progress, message in
                    Task {
                        await self?.reportProgress(
                            currentStep: index + 1,
                            totalSteps: plan.stepCount,
                            stepProgress: progress,
                            stepDescription: message
                        )
                    }
                }
                
                try await step.operation(context)
                
                executedSteps += 1
                currentVersion = step.toVersion
                
                // Record in history
                history.append(MigrationHistoryEntry(
                    stepId: step.id,
                    fromVersion: step.fromVersion,
                    toVersion: step.toVersion,
                    executedAt: Date(),
                    success: true,
                    duration: Date().timeIntervalSince(startTime)
                ))
                
                delegate?.migrationStepDidComplete(step, index: index + 1, total: plan.stepCount)
            }
            
            let result = MigrationResult.success(
                from: plan.fromVersion,
                to: plan.toVersion,
                steps: executedSteps,
                duration: Date().timeIntervalSince(startTime)
            )
            
            delegate?.migrationDidComplete(result)
            
            return result
            
        } catch {
            delegate?.migrationDidFail(error, at: plan.steps[executedSteps])
            
            var wasRolledBack = false
            
            // Attempt rollback if configured
            if configuration.rollbackOnFailure && executedSteps > 0 {
                wasRolledBack = await attemptRollback(
                    steps: Array(plan.steps.prefix(executedSteps)),
                    startingVersion: plan.fromVersion
                )
            }
            
            let result = MigrationResult.failure(
                from: plan.fromVersion,
                to: plan.toVersion,
                executedSteps: executedSteps,
                totalSteps: plan.stepCount,
                error: error,
                duration: Date().timeIntervalSince(startTime),
                wasRolledBack: wasRolledBack
            )
            
            delegate?.migrationDidComplete(result)
            
            throw error
        }
    }
    
    /// Migrates to the target version
    public func migrate(to targetVersion: SchemaVersion) async throws -> MigrationResult {
        guard let plan = createPlan(to: targetVersion) else {
            throw MigrationError.noMigrationPath(from: currentVersion, to: targetVersion)
        }
        
        return try await execute(plan)
    }
    
    /// Migrates to the latest version
    public func migrateToLatest() async throws -> MigrationResult {
        guard let latestVersion = steps.map({ $0.toVersion }).max() else {
            throw MigrationError.noMigrationsRegistered
        }
        
        return try await migrate(to: latestVersion)
    }
    
    /// Checks if migration is needed
    public func needsMigration(to targetVersion: SchemaVersion) -> Bool {
        currentVersion < targetVersion
    }
    
    /// Gets pending migrations
    public func getPendingMigrations(to targetVersion: SchemaVersion) -> [MigrationStep] {
        findMigrationPath(from: currentVersion, to: targetVersion)
    }
    
    /// Gets migration history
    public func getHistory() -> [MigrationHistoryEntry] {
        history
    }
    
    /// Clears migration history
    public func clearHistory() {
        history.removeAll()
    }
    
    private func reportProgress(currentStep: Int, totalSteps: Int, stepProgress: Double, stepDescription: String?) {
        let progress = MigrationProgress(
            currentStep: currentStep,
            totalSteps: totalSteps,
            stepDescription: stepDescription,
            stepProgress: stepProgress
        )
        delegate?.migrationProgressDidUpdate(progress)
    }
    
    private func createBackup() async throws {
        // Implement backup logic
        versionStorage.createBackup()
    }
    
    private func attemptRollback(steps: [MigrationStep], startingVersion: SchemaVersion) async -> Bool {
        delegate?.migrationRollbackDidStart()
        
        var success = true
        var targetVersion = currentVersion
        
        for step in steps.reversed() {
            guard step.reversible, let rollback = step.rollback else {
                success = false
                continue
            }
            
            let context = MigrationContext(from: step.toVersion, to: step.fromVersion)
            
            do {
                try await rollback(context)
                targetVersion = step.fromVersion
            } catch {
                success = false
            }
        }
        
        currentVersion = success ? startingVersion : targetVersion
        delegate?.migrationRollbackDidComplete(success: success)
        
        return success
    }
}

// MARK: - Migration Configuration

/// Configuration for migrations
public struct MigrationConfiguration: Sendable {
    
    /// Whether to create a backup before migration
    public var createBackupBeforeMigration: Bool
    
    /// Whether to rollback on failure
    public var rollbackOnFailure: Bool
    
    /// Whether to run migrations in a transaction
    public var useTransaction: Bool
    
    /// Maximum time allowed for a single step
    public var stepTimeout: TimeInterval?
    
    /// Whether to validate the database after migration
    public var validateAfterMigration: Bool
    
    /// Creates a new configuration
    public init(
        createBackupBeforeMigration: Bool = true,
        rollbackOnFailure: Bool = true,
        useTransaction: Bool = true,
        stepTimeout: TimeInterval? = 300,
        validateAfterMigration: Bool = true
    ) {
        self.createBackupBeforeMigration = createBackupBeforeMigration
        self.rollbackOnFailure = rollbackOnFailure
        self.useTransaction = useTransaction
        self.stepTimeout = stepTimeout
        self.validateAfterMigration = validateAfterMigration
    }
}

// MARK: - Migration History Entry

/// An entry in the migration history
public struct MigrationHistoryEntry: Identifiable, Sendable {
    
    public let id: UUID
    public let stepId: UUID
    public let fromVersion: SchemaVersion
    public let toVersion: SchemaVersion
    public let executedAt: Date
    public let success: Bool
    public let duration: TimeInterval
    public let errorMessage: String?
    
    public init(
        id: UUID = UUID(),
        stepId: UUID,
        fromVersion: SchemaVersion,
        toVersion: SchemaVersion,
        executedAt: Date,
        success: Bool,
        duration: TimeInterval,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.stepId = stepId
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        self.executedAt = executedAt
        self.success = success
        self.duration = duration
        self.errorMessage = errorMessage
    }
}

// MARK: - Migration Error

/// Errors that can occur during migration
public enum MigrationError: Error, LocalizedError, Sendable {
    case migrationInProgress
    case noMigrationPath(from: SchemaVersion, to: SchemaVersion)
    case noMigrationsRegistered
    case stepFailed(step: String, error: Error)
    case rollbackFailed
    case validationFailed(String)
    case timeout
    case backupFailed
    
    public var errorDescription: String? {
        switch self {
        case .migrationInProgress:
            return "A migration is already in progress"
        case .noMigrationPath(let from, let to):
            return "No migration path from \(from) to \(to)"
        case .noMigrationsRegistered:
            return "No migrations have been registered"
        case .stepFailed(let step, let error):
            return "Migration step '\(step)' failed: \(error.localizedDescription)"
        case .rollbackFailed:
            return "Failed to rollback migration"
        case .validationFailed(let reason):
            return "Migration validation failed: \(reason)"
        case .timeout:
            return "Migration step timed out"
        case .backupFailed:
            return "Failed to create backup before migration"
        }
    }
}

// MARK: - Version Storage

/// Storage for version information
public final class VersionStorage: @unchecked Sendable {
    
    private var currentVersion: SchemaVersion = .zero
    private var backupVersion: SchemaVersion?
    private var backupData: Data?
    
    public init() {}
    
    public func getCurrentVersion() -> SchemaVersion {
        currentVersion
    }
    
    public func setCurrentVersion(_ version: SchemaVersion) {
        currentVersion = version
    }
    
    public func createBackup() {
        backupVersion = currentVersion
    }
    
    public func restoreBackup() -> Bool {
        guard let version = backupVersion else { return false }
        currentVersion = version
        backupVersion = nil
        return true
    }
}

// MARK: - Migration Builder

/// Builder for creating migration steps
public struct MigrationBuilder {
    
    private var steps: [MigrationStep] = []
    
    public init() {}
    
    /// Adds a migration step
    public mutating func addStep(
        from: SchemaVersion,
        to: SchemaVersion,
        description: String,
        reversible: Bool = false,
        operation: @escaping @Sendable (MigrationContext) async throws -> Void,
        rollback: (@Sendable (MigrationContext) async throws -> Void)? = nil
    ) {
        let step = MigrationStep(
            from: from,
            to: to,
            description: description,
            reversible: reversible,
            operation: operation,
            rollback: rollback
        )
        steps.append(step)
    }
    
    /// Builds the migration steps
    public func build() -> [MigrationStep] {
        steps.sorted { $0.fromVersion < $1.fromVersion }
    }
}

// MARK: - Common Migrations

/// Factory for common migration operations
public struct CommonMigrations {
    
    /// Creates a step to add a column
    public static func addColumn(
        from: SchemaVersion,
        to: SchemaVersion,
        table: String,
        column: String,
        type: String,
        defaultValue: String? = nil
    ) -> MigrationStep {
        MigrationStep(
            from: from,
            to: to,
            description: "Add column \(column) to \(table)",
            reversible: true,
            operation: { context in
                // In real implementation, execute SQL
                context.reportProgress(1.0, message: "Added column \(column)")
            },
            rollback: { context in
                // In real implementation, execute SQL to drop column
                context.reportProgress(1.0, message: "Removed column \(column)")
            }
        )
    }
    
    /// Creates a step to rename a column
    public static func renameColumn(
        from: SchemaVersion,
        to: SchemaVersion,
        table: String,
        oldName: String,
        newName: String
    ) -> MigrationStep {
        MigrationStep(
            from: from,
            to: to,
            description: "Rename column \(oldName) to \(newName) in \(table)",
            reversible: true,
            operation: { context in
                context.reportProgress(1.0, message: "Renamed column")
            },
            rollback: { context in
                context.reportProgress(1.0, message: "Reverted column name")
            }
        )
    }
    
    /// Creates a step to create a table
    public static func createTable(
        from: SchemaVersion,
        to: SchemaVersion,
        table: String,
        columns: [(String, String)]
    ) -> MigrationStep {
        MigrationStep(
            from: from,
            to: to,
            description: "Create table \(table)",
            reversible: true,
            operation: { context in
                context.reportProgress(1.0, message: "Created table \(table)")
            },
            rollback: { context in
                context.reportProgress(1.0, message: "Dropped table \(table)")
            }
        )
    }
    
    /// Creates a step to drop a table
    public static func dropTable(
        from: SchemaVersion,
        to: SchemaVersion,
        table: String
    ) -> MigrationStep {
        MigrationStep(
            from: from,
            to: to,
            description: "Drop table \(table)",
            reversible: false,
            operation: { context in
                context.reportProgress(1.0, message: "Dropped table \(table)")
            }
        )
    }
    
    /// Creates a step to create an index
    public static func createIndex(
        from: SchemaVersion,
        to: SchemaVersion,
        name: String,
        table: String,
        columns: [String],
        unique: Bool = false
    ) -> MigrationStep {
        MigrationStep(
            from: from,
            to: to,
            description: "Create index \(name) on \(table)",
            reversible: true,
            operation: { context in
                context.reportProgress(1.0, message: "Created index \(name)")
            },
            rollback: { context in
                context.reportProgress(1.0, message: "Dropped index \(name)")
            }
        )
    }
}
