//
//  iCloudSync.swift
//  SwiftPersistence
//
//  Created by Muhittin Camdali on 2025.
//  MIT License
//

import Foundation
import Combine

// MARK: - iCloud Sync Configuration

/// Configuration for iCloud synchronization
public struct iCloudSyncConfiguration: Sendable, Hashable {
    
    /// The container identifier
    public var containerIdentifier: String?
    
    /// Whether to sync automatically
    public var automaticSync: Bool
    
    /// The sync interval in seconds
    public var syncInterval: TimeInterval
    
    /// Whether to use CloudKit for sync
    public var useCloudKit: Bool
    
    /// Whether to use iCloud Documents
    public var useDocuments: Bool
    
    /// The zone name for CloudKit
    public var zoneName: String
    
    /// Whether to subscribe to changes
    public var subscribeToChanges: Bool
    
    /// The batch size for sync operations
    public var batchSize: Int
    
    /// Whether to compress data before syncing
    public var compressData: Bool
    
    /// The conflict resolution strategy
    public var conflictResolution: ConflictResolutionStrategy
    
    /// Creates a new iCloud sync configuration
    public init(
        containerIdentifier: String? = nil,
        automaticSync: Bool = true,
        syncInterval: TimeInterval = 60,
        useCloudKit: Bool = true,
        useDocuments: Bool = false,
        zoneName: String = "SwiftPersistence",
        subscribeToChanges: Bool = true,
        batchSize: Int = 100,
        compressData: Bool = true,
        conflictResolution: ConflictResolutionStrategy = .lastWriteWins
    ) {
        self.containerIdentifier = containerIdentifier
        self.automaticSync = automaticSync
        self.syncInterval = syncInterval
        self.useCloudKit = useCloudKit
        self.useDocuments = useDocuments
        self.zoneName = zoneName
        self.subscribeToChanges = subscribeToChanges
        self.batchSize = batchSize
        self.compressData = compressData
        self.conflictResolution = conflictResolution
    }
}

// MARK: - Conflict Resolution Strategy

/// Strategy for resolving sync conflicts
public enum ConflictResolutionStrategy: String, Sendable, CaseIterable {
    /// The most recent write wins
    case lastWriteWins
    
    /// The server version wins
    case serverWins
    
    /// The client version wins
    case clientWins
    
    /// Merge changes from both versions
    case merge
    
    /// Use a custom resolver
    case custom
}

// MARK: - Sync State

/// The current state of synchronization
public enum SyncState: String, Sendable {
    /// Sync is idle
    case idle
    
    /// Sync is in progress
    case syncing
    
    /// Sync completed successfully
    case completed
    
    /// Sync failed
    case failed
    
    /// Waiting for network
    case waitingForNetwork
    
    /// Sync is paused
    case paused
}

// MARK: - Sync Record

/// A record to be synced
public struct SyncRecord: Identifiable, Codable, Sendable, Hashable {
    
    /// The record identifier
    public let id: String
    
    /// The record type
    public let recordType: String
    
    /// The record data
    public let data: Data
    
    /// The local modification date
    public let localModificationDate: Date
    
    /// The server modification date
    public var serverModificationDate: Date?
    
    /// The change tag for conflict detection
    public var changeTag: String?
    
    /// Whether the record has been deleted
    public var isDeleted: Bool
    
    /// The sync status
    public var syncStatus: SyncRecordStatus
    
    /// Creates a new sync record
    public init(
        id: String,
        recordType: String,
        data: Data,
        localModificationDate: Date = Date(),
        serverModificationDate: Date? = nil,
        changeTag: String? = nil,
        isDeleted: Bool = false,
        syncStatus: SyncRecordStatus = .pending
    ) {
        self.id = id
        self.recordType = recordType
        self.data = data
        self.localModificationDate = localModificationDate
        self.serverModificationDate = serverModificationDate
        self.changeTag = changeTag
        self.isDeleted = isDeleted
        self.syncStatus = syncStatus
    }
}

/// The sync status of a record
public enum SyncRecordStatus: String, Codable, Sendable {
    /// Pending sync
    case pending
    
    /// Currently syncing
    case syncing
    
    /// Synced successfully
    case synced
    
    /// Sync failed
    case failed
    
    /// Has a conflict
    case conflict
}

// MARK: - Sync Change

/// A change to be synced
public struct SyncChange: Identifiable, Sendable {
    
    /// The change identifier
    public let id: UUID
    
    /// The type of change
    public let type: ChangeType
    
    /// The record that changed
    public let record: SyncRecord
    
    /// The timestamp of the change
    public let timestamp: Date
    
    /// The source of the change
    public let source: ChangeSource
    
    /// Change types
    public enum ChangeType: String, Sendable {
        case insert
        case update
        case delete
    }
    
    /// Change sources
    public enum ChangeSource: String, Sendable {
        case local
        case remote
    }
    
    /// Creates a new sync change
    public init(
        id: UUID = UUID(),
        type: ChangeType,
        record: SyncRecord,
        timestamp: Date = Date(),
        source: ChangeSource = .local
    ) {
        self.id = id
        self.type = type
        self.record = record
        self.timestamp = timestamp
        self.source = source
    }
}

// MARK: - Sync Conflict

/// A conflict between local and remote data
public struct SyncConflict: Identifiable, Sendable {
    
    /// The conflict identifier
    public let id: UUID
    
    /// The record type
    public let recordType: String
    
    /// The record identifier
    public let recordId: String
    
    /// The local version
    public let localRecord: SyncRecord
    
    /// The remote version
    public let remoteRecord: SyncRecord
    
    /// The conflict detection date
    public let detectedAt: Date
    
    /// Creates a new sync conflict
    public init(
        id: UUID = UUID(),
        recordType: String,
        recordId: String,
        localRecord: SyncRecord,
        remoteRecord: SyncRecord,
        detectedAt: Date = Date()
    ) {
        self.id = id
        self.recordType = recordType
        self.recordId = recordId
        self.localRecord = localRecord
        self.remoteRecord = remoteRecord
        self.detectedAt = detectedAt
    }
}

// MARK: - Sync Progress

/// Progress information for sync operations
public struct SyncProgress: Sendable {
    
    /// The total number of records to sync
    public let total: Int
    
    /// The number of records completed
    public let completed: Int
    
    /// The number of records that failed
    public let failed: Int
    
    /// The current operation
    public let currentOperation: String?
    
    /// The progress percentage (0.0 - 1.0)
    public var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
    
    /// Whether the sync is complete
    public var isComplete: Bool {
        completed + failed >= total
    }
    
    /// Creates a new sync progress
    public init(
        total: Int,
        completed: Int,
        failed: Int = 0,
        currentOperation: String? = nil
    ) {
        self.total = total
        self.completed = completed
        self.failed = failed
        self.currentOperation = currentOperation
    }
}

// MARK: - Sync Delegate

/// Delegate for sync events
public protocol iCloudSyncDelegate: AnyObject, Sendable {
    
    /// Called when sync state changes
    func syncStateDidChange(_ state: SyncState)
    
    /// Called when sync progress updates
    func syncProgressDidUpdate(_ progress: SyncProgress)
    
    /// Called when a conflict is detected
    func syncDidDetectConflict(_ conflict: SyncConflict) async -> SyncRecord?
    
    /// Called when sync completes
    func syncDidComplete(uploaded: Int, downloaded: Int, conflicts: Int)
    
    /// Called when sync fails
    func syncDidFail(_ error: Error)
    
    /// Called when records are received from the server
    func syncDidReceiveRecords(_ records: [SyncRecord])
}

// MARK: - iCloud Sync Manager

/// Manages iCloud synchronization
public actor iCloudSyncManager {
    
    /// The configuration
    private let configuration: iCloudSyncConfiguration
    
    /// The local storage
    private var localRecords: [String: [String: SyncRecord]]
    
    /// The server storage (simulated)
    private var serverRecords: [String: [String: SyncRecord]]
    
    /// Pending changes
    private var pendingChanges: [SyncChange]
    
    /// Current conflicts
    private var conflicts: [SyncConflict]
    
    /// The current sync state
    private var state: SyncState
    
    /// The delegate
    private weak var delegate: iCloudSyncDelegate?
    
    /// Sync metrics
    private var metrics: iCloudSyncMetrics
    
    /// Last sync date
    private var lastSyncDate: Date?
    
    /// Sync timer task
    private var syncTimerTask: Task<Void, Never>?
    
    /// Change token for incremental sync
    private var serverChangeToken: String?
    
    /// Creates a new iCloud sync manager
    public init(configuration: iCloudSyncConfiguration = iCloudSyncConfiguration()) {
        self.configuration = configuration
        self.localRecords = [:]
        self.serverRecords = [:]
        self.pendingChanges = []
        self.conflicts = []
        self.state = .idle
        self.metrics = iCloudSyncMetrics()
    }
    
    /// Sets the delegate
    public func setDelegate(_ delegate: iCloudSyncDelegate?) {
        self.delegate = delegate
    }
    
    /// Starts automatic synchronization
    public func startAutoSync() {
        guard configuration.automaticSync else { return }
        
        syncTimerTask?.cancel()
        syncTimerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(configuration.syncInterval * 1_000_000_000))
                await performSync()
            }
        }
    }
    
    /// Stops automatic synchronization
    public func stopAutoSync() {
        syncTimerTask?.cancel()
        syncTimerTask = nil
    }
    
    /// Performs a full sync
    public func performSync() async {
        guard state != .syncing else { return }
        
        updateState(.syncing)
        metrics.syncStartCount += 1
        
        do {
            // Upload local changes
            let uploadCount = try await uploadChanges()
            
            // Download remote changes
            let downloadCount = try await downloadChanges()
            
            // Resolve conflicts
            let conflictCount = await resolveConflicts()
            
            // Update last sync date
            lastSyncDate = Date()
            metrics.lastSuccessfulSync = lastSyncDate
            metrics.successfulSyncCount += 1
            
            updateState(.completed)
            delegate?.syncDidComplete(uploaded: uploadCount, downloaded: downloadCount, conflicts: conflictCount)
            
        } catch {
            metrics.failedSyncCount += 1
            updateState(.failed)
            delegate?.syncDidFail(error)
        }
    }
    
    /// Uploads local changes to the server
    private func uploadChanges() async throws -> Int {
        let changes = pendingChanges.filter { $0.source == .local }
        var uploadedCount = 0
        
        for change in changes {
            try await uploadRecord(change.record)
            uploadedCount += 1
            
            // Remove from pending
            pendingChanges.removeAll { $0.id == change.id }
        }
        
        metrics.recordsUploaded += uploadedCount
        return uploadedCount
    }
    
    /// Downloads changes from the server
    private func downloadChanges() async throws -> Int {
        var downloadedCount = 0
        
        // In a real implementation, this would fetch from CloudKit
        // For simulation, we check for server records not in local
        for (recordType, typeRecords) in serverRecords {
            for (recordId, serverRecord) in typeRecords {
                let localRecord = localRecords[recordType]?[recordId]
                
                if localRecord == nil || serverRecord.serverModificationDate ?? Date.distantPast > localRecord!.localModificationDate {
                    // Check for conflict
                    if let local = localRecord, local.localModificationDate > serverRecord.serverModificationDate ?? Date.distantPast {
                        // Conflict detected
                        let conflict = SyncConflict(
                            recordType: recordType,
                            recordId: recordId,
                            localRecord: local,
                            remoteRecord: serverRecord
                        )
                        conflicts.append(conflict)
                        delegate?.syncStateDidChange(.syncing)
                        _ = await delegate?.syncDidDetectConflict(conflict)
                    } else {
                        // Apply server change
                        if localRecords[recordType] == nil {
                            localRecords[recordType] = [:]
                        }
                        localRecords[recordType]?[recordId] = serverRecord
                        downloadedCount += 1
                    }
                }
            }
        }
        
        metrics.recordsDownloaded += downloadedCount
        return downloadedCount
    }
    
    /// Resolves pending conflicts
    private func resolveConflicts() async -> Int {
        var resolvedCount = 0
        
        for conflict in conflicts {
            let resolved = await resolveConflict(conflict)
            if resolved != nil {
                resolvedCount += 1
            }
        }
        
        // Clear resolved conflicts
        conflicts.removeAll()
        metrics.conflictsResolved += resolvedCount
        
        return resolvedCount
    }
    
    /// Resolves a single conflict
    private func resolveConflict(_ conflict: SyncConflict) async -> SyncRecord? {
        // First try delegate for custom resolution
        if configuration.conflictResolution == .custom {
            if let resolved = await delegate?.syncDidDetectConflict(conflict) {
                return await applyResolution(resolved, for: conflict)
            }
        }
        
        // Apply automatic resolution
        let resolvedRecord: SyncRecord
        
        switch configuration.conflictResolution {
        case .lastWriteWins:
            let localDate = conflict.localRecord.localModificationDate
            let serverDate = conflict.remoteRecord.serverModificationDate ?? Date.distantPast
            resolvedRecord = localDate > serverDate ? conflict.localRecord : conflict.remoteRecord
            
        case .serverWins:
            resolvedRecord = conflict.remoteRecord
            
        case .clientWins:
            resolvedRecord = conflict.localRecord
            
        case .merge:
            resolvedRecord = mergeRecords(conflict.localRecord, conflict.remoteRecord)
            
        case .custom:
            // Already handled above
            return nil
        }
        
        return await applyResolution(resolvedRecord, for: conflict)
    }
    
    /// Applies the resolved record
    private func applyResolution(_ record: SyncRecord, for conflict: SyncConflict) async -> SyncRecord {
        // Update local
        if localRecords[conflict.recordType] == nil {
            localRecords[conflict.recordType] = [:]
        }
        localRecords[conflict.recordType]?[conflict.recordId] = record
        
        // Upload to server
        try? await uploadRecord(record)
        
        return record
    }
    
    /// Merges two records
    private func mergeRecords(_ local: SyncRecord, _ remote: SyncRecord) -> SyncRecord {
        // Simple merge strategy: use the newer data
        let useLocal = local.localModificationDate > (remote.serverModificationDate ?? Date.distantPast)
        
        return SyncRecord(
            id: local.id,
            recordType: local.recordType,
            data: useLocal ? local.data : remote.data,
            localModificationDate: Date(),
            serverModificationDate: remote.serverModificationDate,
            changeTag: UUID().uuidString,
            isDeleted: local.isDeleted || remote.isDeleted,
            syncStatus: .synced
        )
    }
    
    /// Uploads a record to the server
    private func uploadRecord(_ record: SyncRecord) async throws {
        // Simulate upload delay
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        var uploadedRecord = record
        uploadedRecord.serverModificationDate = Date()
        uploadedRecord.syncStatus = .synced
        uploadedRecord.changeTag = UUID().uuidString
        
        // Update server storage
        if serverRecords[record.recordType] == nil {
            serverRecords[record.recordType] = [:]
        }
        serverRecords[record.recordType]?[record.id] = uploadedRecord
        
        // Update local with server metadata
        localRecords[record.recordType]?[record.id] = uploadedRecord
    }
    
    /// Updates the sync state
    private func updateState(_ newState: SyncState) {
        state = newState
        delegate?.syncStateDidChange(newState)
    }
    
    // MARK: - Public API
    
    /// Gets the current sync state
    public func getState() -> SyncState {
        state
    }
    
    /// Gets the last sync date
    public func getLastSyncDate() -> Date? {
        lastSyncDate
    }
    
    /// Gets current conflicts
    public func getConflicts() -> [SyncConflict] {
        conflicts
    }
    
    /// Gets sync metrics
    public func getMetrics() -> iCloudSyncMetrics {
        metrics
    }
    
    /// Resets metrics
    public func resetMetrics() {
        metrics = iCloudSyncMetrics()
    }
    
    /// Saves a record for sync
    public func saveRecord<T: Storable>(_ object: T) async throws {
        let data = try JSONEncoder().encode(object)
        let recordType = String(describing: T.self)
        let recordId = "\(object.id)"
        
        let record = SyncRecord(
            id: recordId,
            recordType: recordType,
            data: data,
            localModificationDate: Date(),
            syncStatus: .pending
        )
        
        // Save locally
        if localRecords[recordType] == nil {
            localRecords[recordType] = [:]
        }
        localRecords[recordType]?[recordId] = record
        
        // Queue for sync
        let change = SyncChange(type: .insert, record: record, source: .local)
        pendingChanges.append(change)
    }
    
    /// Updates a record for sync
    public func updateRecord<T: Storable>(_ object: T) async throws {
        let data = try JSONEncoder().encode(object)
        let recordType = String(describing: T.self)
        let recordId = "\(object.id)"
        
        guard let existing = localRecords[recordType]?[recordId] else {
            throw PersistenceError.notFound
        }
        
        var record = existing
        record = SyncRecord(
            id: recordId,
            recordType: recordType,
            data: data,
            localModificationDate: Date(),
            serverModificationDate: record.serverModificationDate,
            changeTag: record.changeTag,
            isDeleted: false,
            syncStatus: .pending
        )
        
        localRecords[recordType]?[recordId] = record
        
        let change = SyncChange(type: .update, record: record, source: .local)
        pendingChanges.append(change)
    }
    
    /// Deletes a record for sync
    public func deleteRecord<T: Storable>(_ type: T.Type, id: T.ID) async throws {
        let recordType = String(describing: type)
        let recordId = "\(id)"
        
        guard var record = localRecords[recordType]?[recordId] else {
            return
        }
        
        record = SyncRecord(
            id: record.id,
            recordType: record.recordType,
            data: record.data,
            localModificationDate: Date(),
            serverModificationDate: record.serverModificationDate,
            changeTag: record.changeTag,
            isDeleted: true,
            syncStatus: .pending
        )
        
        localRecords[recordType]?[recordId] = record
        
        let change = SyncChange(type: .delete, record: record, source: .local)
        pendingChanges.append(change)
    }
    
    /// Fetches a record
    public func fetchRecord<T: Storable>(_ type: T.Type, id: T.ID) async throws -> T? {
        let recordType = String(describing: type)
        let recordId = "\(id)"
        
        guard let record = localRecords[recordType]?[recordId],
              !record.isDeleted else {
            return nil
        }
        
        return try JSONDecoder().decode(type, from: record.data)
    }
    
    /// Fetches all records of a type
    public func fetchAllRecords<T: Storable>(_ type: T.Type) async throws -> [T] {
        let recordType = String(describing: type)
        
        guard let records = localRecords[recordType] else {
            return []
        }
        
        return try records.values
            .filter { !$0.isDeleted }
            .compactMap { try JSONDecoder().decode(type, from: $0.data) }
    }
    
    /// Gets pending changes count
    public func getPendingChangesCount() -> Int {
        pendingChanges.count
    }
    
    /// Pauses sync
    public func pauseSync() {
        guard state == .syncing || state == .idle else { return }
        updateState(.paused)
        syncTimerTask?.cancel()
    }
    
    /// Resumes sync
    public func resumeSync() {
        guard state == .paused else { return }
        updateState(.idle)
        startAutoSync()
    }
    
    /// Forces an immediate sync
    public func forceSyncNow() async {
        await performSync()
    }
    
    /// Clears all local data
    public func clearLocalData() {
        localRecords.removeAll()
        pendingChanges.removeAll()
        conflicts.removeAll()
    }
    
    /// Resets sync state
    public func resetSyncState() {
        serverChangeToken = nil
        lastSyncDate = nil
        clearLocalData()
        updateState(.idle)
    }
}

// MARK: - iCloud Sync Metrics

/// Metrics for iCloud sync operations
public struct iCloudSyncMetrics: Sendable {
    
    /// Number of sync starts
    public var syncStartCount: Int = 0
    
    /// Number of successful syncs
    public var successfulSyncCount: Int = 0
    
    /// Number of failed syncs
    public var failedSyncCount: Int = 0
    
    /// Number of records uploaded
    public var recordsUploaded: Int = 0
    
    /// Number of records downloaded
    public var recordsDownloaded: Int = 0
    
    /// Number of conflicts resolved
    public var conflictsResolved: Int = 0
    
    /// Last successful sync date
    public var lastSuccessfulSync: Date?
    
    /// Total sync time in seconds
    public var totalSyncTime: TimeInterval = 0
    
    /// Average sync time
    public var averageSyncTime: TimeInterval {
        guard successfulSyncCount > 0 else { return 0 }
        return totalSyncTime / Double(successfulSyncCount)
    }
}

// MARK: - iCloud Account Status

/// iCloud account status
public enum iCloudAccountStatus: String, Sendable {
    case available
    case unavailable
    case restricted
    case noAccount
    case couldNotDetermine
}

// MARK: - Sync Error

/// Errors that can occur during sync
public enum SyncError: Error, LocalizedError, Sendable {
    case notAuthenticated
    case networkUnavailable
    case quotaExceeded
    case serverError(String)
    case conflictNotResolved
    case invalidRecord
    case zoneNotFound
    case partialFailure([String])
    
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated with iCloud"
        case .networkUnavailable:
            return "Network is unavailable"
        case .quotaExceeded:
            return "iCloud storage quota exceeded"
        case .serverError(let message):
            return "Server error: \(message)"
        case .conflictNotResolved:
            return "Conflict could not be resolved"
        case .invalidRecord:
            return "Invalid record format"
        case .zoneNotFound:
            return "CloudKit zone not found"
        case .partialFailure(let ids):
            return "Partial failure for records: \(ids.joined(separator: ", "))"
        }
    }
}

// MARK: - Notifications

public extension Notification.Name {
    static let iCloudSyncDidStart = Notification.Name("SwiftPersistence.iCloudSyncDidStart")
    static let iCloudSyncDidComplete = Notification.Name("SwiftPersistence.iCloudSyncDidComplete")
    static let iCloudSyncDidFail = Notification.Name("SwiftPersistence.iCloudSyncDidFail")
    static let iCloudSyncConflictDetected = Notification.Name("SwiftPersistence.iCloudSyncConflictDetected")
    static let iCloudAccountStatusDidChange = Notification.Name("SwiftPersistence.iCloudAccountStatusDidChange")
}

// MARK: - CloudKit Zone Manager

/// Manages CloudKit zones
public actor CloudKitZoneManager {
    
    /// The container identifier
    private let containerIdentifier: String?
    
    /// The zone name
    private let zoneName: String
    
    /// Whether the zone has been created
    private var zoneCreated: Bool = false
    
    /// Subscription identifiers
    private var subscriptionIds: [String] = []
    
    /// Creates a new zone manager
    public init(containerIdentifier: String? = nil, zoneName: String = "SwiftPersistence") {
        self.containerIdentifier = containerIdentifier
        self.zoneName = zoneName
    }
    
    /// Creates the zone if needed
    public func createZoneIfNeeded() async throws {
        guard !zoneCreated else { return }
        
        // In a real implementation, this would create a CloudKit zone
        // For simulation, we just mark it as created
        zoneCreated = true
    }
    
    /// Deletes the zone
    public func deleteZone() async throws {
        zoneCreated = false
        subscriptionIds.removeAll()
    }
    
    /// Subscribes to changes in the zone
    public func subscribeToChanges() async throws -> String {
        guard zoneCreated else {
            throw SyncError.zoneNotFound
        }
        
        let subscriptionId = UUID().uuidString
        subscriptionIds.append(subscriptionId)
        return subscriptionId
    }
    
    /// Unsubscribes from changes
    public func unsubscribe(_ subscriptionId: String) async throws {
        subscriptionIds.removeAll { $0 == subscriptionId }
    }
    
    /// Checks if subscribed
    public func isSubscribed() -> Bool {
        !subscriptionIds.isEmpty
    }
}

// MARK: - Sync Batch

/// A batch of records to sync
public struct SyncBatch: Sendable {
    
    /// The batch identifier
    public let id: UUID
    
    /// Records to save
    public let recordsToSave: [SyncRecord]
    
    /// Record IDs to delete
    public let recordIdsToDelete: [String]
    
    /// The creation date
    public let createdAt: Date
    
    /// Creates a new sync batch
    public init(
        id: UUID = UUID(),
        recordsToSave: [SyncRecord] = [],
        recordIdsToDelete: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.recordsToSave = recordsToSave
        self.recordIdsToDelete = recordIdsToDelete
        self.createdAt = createdAt
    }
    
    /// The total number of operations
    public var operationCount: Int {
        recordsToSave.count + recordIdsToDelete.count
    }
    
    /// Whether the batch is empty
    public var isEmpty: Bool {
        operationCount == 0
    }
}
