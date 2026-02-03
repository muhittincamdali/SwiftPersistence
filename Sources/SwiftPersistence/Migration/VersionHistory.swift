//
//  VersionHistory.swift
//  SwiftPersistence
//
//  Created by Muhittin Camdali on 2025.
//  MIT License
//

import Foundation
import Combine

// MARK: - Version Record

/// A record of a schema version change
public struct VersionRecord: Identifiable, Codable, Sendable, Hashable {
    
    /// The record identifier
    public let id: UUID
    
    /// The version number
    public let version: String
    
    /// The timestamp of the version change
    public let timestamp: Date
    
    /// The type of version change
    public let changeType: VersionChangeType
    
    /// Description of the changes
    public let description: String
    
    /// The user or device that made the change
    public let source: String?
    
    /// Additional metadata
    public let metadata: [String: String]
    
    /// Duration of the migration (if applicable)
    public let duration: TimeInterval?
    
    /// Whether the migration was successful
    public let success: Bool
    
    /// Error message if failed
    public let errorMessage: String?
    
    /// Creates a new version record
    public init(
        id: UUID = UUID(),
        version: String,
        timestamp: Date = Date(),
        changeType: VersionChangeType,
        description: String,
        source: String? = nil,
        metadata: [String: String] = [:],
        duration: TimeInterval? = nil,
        success: Bool = true,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.version = version
        self.timestamp = timestamp
        self.changeType = changeType
        self.description = description
        self.source = source
        self.metadata = metadata
        self.duration = duration
        self.success = success
        self.errorMessage = errorMessage
    }
}

// MARK: - Version Change Type

/// Types of version changes
public enum VersionChangeType: String, Codable, Sendable, CaseIterable {
    /// Initial schema creation
    case initial
    
    /// Schema migration
    case migration
    
    /// Schema rollback
    case rollback
    
    /// Data import
    case `import`
    
    /// Data export
    case export
    
    /// Manual version set
    case manual
    
    /// Schema repair
    case repair
    
    /// Checkpoint creation
    case checkpoint
}

// MARK: - Version History

/// Manages version history for a database
public actor VersionHistory {
    
    /// The stored records
    private var records: [VersionRecord]
    
    /// Maximum number of records to keep
    private let maxRecords: Int
    
    /// The storage path
    private let storagePath: URL?
    
    /// Publisher for history changes
    private let changesSubject = PassthroughSubject<VersionRecord, Never>()
    
    /// Creates a new version history
    public init(maxRecords: Int = 1000, storagePath: URL? = nil) {
        self.records = []
        self.maxRecords = maxRecords
        self.storagePath = storagePath
    }
    
    /// Adds a record to the history
    public func addRecord(_ record: VersionRecord) {
        records.append(record)
        
        // Trim if needed
        if records.count > maxRecords {
            records.removeFirst(records.count - maxRecords)
        }
        
        changesSubject.send(record)
    }
    
    /// Records a migration
    public func recordMigration(
        fromVersion: String,
        toVersion: String,
        description: String,
        duration: TimeInterval,
        success: Bool,
        errorMessage: String? = nil
    ) {
        let record = VersionRecord(
            version: toVersion,
            changeType: .migration,
            description: "Migration from \(fromVersion) to \(toVersion): \(description)",
            metadata: ["fromVersion": fromVersion],
            duration: duration,
            success: success,
            errorMessage: errorMessage
        )
        
        Task {
            await addRecord(record)
        }
    }
    
    /// Records a rollback
    public func recordRollback(
        fromVersion: String,
        toVersion: String,
        reason: String,
        success: Bool
    ) {
        let record = VersionRecord(
            version: toVersion,
            changeType: .rollback,
            description: "Rollback from \(fromVersion) to \(toVersion): \(reason)",
            metadata: ["fromVersion": fromVersion, "reason": reason],
            success: success
        )
        
        Task {
            await addRecord(record)
        }
    }
    
    /// Records an initial creation
    public func recordInitialCreation(version: String) {
        let record = VersionRecord(
            version: version,
            changeType: .initial,
            description: "Initial schema creation at version \(version)"
        )
        
        Task {
            await addRecord(record)
        }
    }
    
    /// Records a checkpoint
    public func recordCheckpoint(version: String, description: String) {
        let record = VersionRecord(
            version: version,
            changeType: .checkpoint,
            description: "Checkpoint: \(description)"
        )
        
        Task {
            await addRecord(record)
        }
    }
    
    /// Gets all records
    public func getAllRecords() -> [VersionRecord] {
        records
    }
    
    /// Gets records for a specific version
    public func getRecords(for version: String) -> [VersionRecord] {
        records.filter { $0.version == version }
    }
    
    /// Gets records of a specific type
    public func getRecords(ofType type: VersionChangeType) -> [VersionRecord] {
        records.filter { $0.changeType == type }
    }
    
    /// Gets records in a date range
    public func getRecords(from startDate: Date, to endDate: Date) -> [VersionRecord] {
        records.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }
    
    /// Gets the most recent record
    public func getMostRecent() -> VersionRecord? {
        records.last
    }
    
    /// Gets the most recent successful migration
    public func getMostRecentSuccessfulMigration() -> VersionRecord? {
        records.last { $0.changeType == .migration && $0.success }
    }
    
    /// Gets failed migrations
    public func getFailedMigrations() -> [VersionRecord] {
        records.filter { $0.changeType == .migration && !$0.success }
    }
    
    /// Gets the current version from history
    public func getCurrentVersion() -> String? {
        records.last(where: { $0.success })?.version
    }
    
    /// Gets statistics about the version history
    public func getStatistics() -> VersionHistoryStatistics {
        let migrations = records.filter { $0.changeType == .migration }
        let successfulMigrations = migrations.filter { $0.success }
        let failedMigrations = migrations.filter { !$0.success }
        let rollbacks = records.filter { $0.changeType == .rollback }
        
        let totalDuration = migrations.compactMap { $0.duration }.reduce(0, +)
        let averageDuration = migrations.isEmpty ? 0 : totalDuration / Double(migrations.count)
        
        return VersionHistoryStatistics(
            totalRecords: records.count,
            totalMigrations: migrations.count,
            successfulMigrations: successfulMigrations.count,
            failedMigrations: failedMigrations.count,
            totalRollbacks: rollbacks.count,
            totalDuration: totalDuration,
            averageMigrationDuration: averageDuration,
            firstRecord: records.first,
            lastRecord: records.last
        )
    }
    
    /// Clears all history
    public func clearHistory() {
        records.removeAll()
    }
    
    /// Exports history to JSON
    public func exportToJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(records)
    }
    
    /// Imports history from JSON
    public func importFromJSON(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let imported = try decoder.decode([VersionRecord].self, from: data)
        records.append(contentsOf: imported)
        
        // Sort by timestamp
        records.sort { $0.timestamp < $1.timestamp }
        
        // Trim if needed
        if records.count > maxRecords {
            records.removeFirst(records.count - maxRecords)
        }
    }
    
    /// Saves history to disk
    public func saveToDisk() throws {
        guard let path = storagePath else {
            throw VersionHistoryError.noStoragePath
        }
        
        let data = try exportToJSON()
        try data.write(to: path)
    }
    
    /// Loads history from disk
    public func loadFromDisk() throws {
        guard let path = storagePath else {
            throw VersionHistoryError.noStoragePath
        }
        
        guard FileManager.default.fileExists(atPath: path.path) else {
            return
        }
        
        let data = try Data(contentsOf: path)
        try importFromJSON(data)
    }
}

// MARK: - Version History Statistics

/// Statistics about version history
public struct VersionHistoryStatistics: Sendable {
    
    /// Total number of records
    public let totalRecords: Int
    
    /// Total number of migrations
    public let totalMigrations: Int
    
    /// Number of successful migrations
    public let successfulMigrations: Int
    
    /// Number of failed migrations
    public let failedMigrations: Int
    
    /// Total number of rollbacks
    public let totalRollbacks: Int
    
    /// Total migration duration in seconds
    public let totalDuration: TimeInterval
    
    /// Average migration duration
    public let averageMigrationDuration: TimeInterval
    
    /// The first record
    public let firstRecord: VersionRecord?
    
    /// The last record
    public let lastRecord: VersionRecord?
    
    /// Success rate for migrations
    public var migrationSuccessRate: Double {
        guard totalMigrations > 0 else { return 1.0 }
        return Double(successfulMigrations) / Double(totalMigrations)
    }
}

// MARK: - Version History Error

/// Errors related to version history
public enum VersionHistoryError: Error, LocalizedError, Sendable {
    case noStoragePath
    case importFailed(String)
    case exportFailed(String)
    case recordNotFound
    
    public var errorDescription: String? {
        switch self {
        case .noStoragePath:
            return "No storage path configured for version history"
        case .importFailed(let reason):
            return "Failed to import version history: \(reason)"
        case .exportFailed(let reason):
            return "Failed to export version history: \(reason)"
        case .recordNotFound:
            return "Version record not found"
        }
    }
}

// MARK: - Version Timeline

/// A timeline view of version changes
public struct VersionTimeline: Sendable {
    
    /// Timeline entries
    public let entries: [TimelineEntry]
    
    /// A single timeline entry
    public struct TimelineEntry: Identifiable, Sendable {
        public let id: UUID
        public let record: VersionRecord
        public let index: Int
        public let isLatest: Bool
        
        public init(record: VersionRecord, index: Int, isLatest: Bool) {
            self.id = record.id
            self.record = record
            self.index = index
            self.isLatest = isLatest
        }
    }
    
    /// Creates a timeline from records
    public init(records: [VersionRecord]) {
        var entries: [TimelineEntry] = []
        
        for (index, record) in records.enumerated() {
            let entry = TimelineEntry(
                record: record,
                index: index,
                isLatest: index == records.count - 1
            )
            entries.append(entry)
        }
        
        self.entries = entries
    }
    
    /// Gets entries for a specific change type
    public func entries(ofType type: VersionChangeType) -> [TimelineEntry] {
        entries.filter { $0.record.changeType == type }
    }
    
    /// Gets the entry for a specific version
    public func entry(for version: String) -> TimelineEntry? {
        entries.first { $0.record.version == version }
    }
}

// MARK: - Version Diff

/// Represents the difference between two versions
public struct VersionDiff: Sendable {
    
    /// The older version
    public let fromVersion: String
    
    /// The newer version
    public let toVersion: String
    
    /// Records between the versions
    public let records: [VersionRecord]
    
    /// Number of migrations
    public var migrationCount: Int {
        records.filter { $0.changeType == .migration }.count
    }
    
    /// Total duration
    public var totalDuration: TimeInterval {
        records.compactMap { $0.duration }.reduce(0, +)
    }
    
    /// Whether all changes were successful
    public var allSuccessful: Bool {
        records.allSatisfy { $0.success }
    }
    
    /// Creates a diff between two versions
    public init(from fromVersion: String, to toVersion: String, records: [VersionRecord]) {
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        self.records = records
    }
}

// MARK: - Version Snapshot

/// A snapshot of the database at a specific version
public struct VersionSnapshot: Identifiable, Codable, Sendable {
    
    /// The snapshot identifier
    public let id: UUID
    
    /// The version number
    public let version: String
    
    /// When the snapshot was created
    public let createdAt: Date
    
    /// The schema definition at this version
    public let schema: String?
    
    /// Data hash for verification
    public let dataHash: String?
    
    /// Size of the database at this version
    public let databaseSize: Int64?
    
    /// Additional metadata
    public let metadata: [String: String]
    
    /// Creates a new snapshot
    public init(
        id: UUID = UUID(),
        version: String,
        createdAt: Date = Date(),
        schema: String? = nil,
        dataHash: String? = nil,
        databaseSize: Int64? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.version = version
        self.createdAt = createdAt
        self.schema = schema
        self.dataHash = dataHash
        self.databaseSize = databaseSize
        self.metadata = metadata
    }
}

// MARK: - Snapshot Manager

/// Manages version snapshots
public actor SnapshotManager {
    
    /// Stored snapshots
    private var snapshots: [VersionSnapshot]
    
    /// Maximum snapshots to keep
    private let maxSnapshots: Int
    
    /// Creates a new snapshot manager
    public init(maxSnapshots: Int = 10) {
        self.snapshots = []
        self.maxSnapshots = maxSnapshots
    }
    
    /// Creates a new snapshot
    public func createSnapshot(
        version: String,
        schema: String? = nil,
        dataHash: String? = nil,
        databaseSize: Int64? = nil,
        metadata: [String: String] = [:]
    ) -> VersionSnapshot {
        let snapshot = VersionSnapshot(
            version: version,
            schema: schema,
            dataHash: dataHash,
            databaseSize: databaseSize,
            metadata: metadata
        )
        
        snapshots.append(snapshot)
        
        // Trim if needed
        if snapshots.count > maxSnapshots {
            snapshots.removeFirst(snapshots.count - maxSnapshots)
        }
        
        return snapshot
    }
    
    /// Gets all snapshots
    public func getAllSnapshots() -> [VersionSnapshot] {
        snapshots
    }
    
    /// Gets a snapshot for a specific version
    public func getSnapshot(for version: String) -> VersionSnapshot? {
        snapshots.last { $0.version == version }
    }
    
    /// Gets the most recent snapshot
    public func getMostRecentSnapshot() -> VersionSnapshot? {
        snapshots.last
    }
    
    /// Deletes a snapshot
    public func deleteSnapshot(_ id: UUID) {
        snapshots.removeAll { $0.id == id }
    }
    
    /// Clears all snapshots
    public func clearSnapshots() {
        snapshots.removeAll()
    }
}
