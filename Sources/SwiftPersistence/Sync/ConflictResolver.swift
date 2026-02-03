//
//  ConflictResolver.swift
//  SwiftPersistence
//
//  Created by Muhittin Camdali on 2025.
//  MIT License
//

import Foundation
import Combine

// MARK: - Conflict Resolution Result

/// The result of a conflict resolution
public enum ConflictResolutionResult: Sendable {
    /// Use the local version
    case useLocal
    
    /// Use the remote version
    case useRemote
    
    /// Use a merged version
    case useMerged(Data)
    
    /// Skip this conflict
    case skip
    
    /// Retry later
    case retryLater
}

// MARK: - Conflict Context

/// Context information for conflict resolution
public struct ConflictContext: Sendable {
    
    /// The conflict being resolved
    public let conflict: SyncConflict
    
    /// The resolution strategy to use
    public let strategy: ConflictResolutionStrategy
    
    /// Additional metadata
    public let metadata: [String: String]
    
    /// Whether this is an automatic resolution
    public let isAutomatic: Bool
    
    /// The user ID (if available)
    public let userId: String?
    
    /// The device ID
    public let deviceId: String
    
    /// Creates a new conflict context
    public init(
        conflict: SyncConflict,
        strategy: ConflictResolutionStrategy,
        metadata: [String: String] = [:],
        isAutomatic: Bool = true,
        userId: String? = nil,
        deviceId: String = UUID().uuidString
    ) {
        self.conflict = conflict
        self.strategy = strategy
        self.metadata = metadata
        self.isAutomatic = isAutomatic
        self.userId = userId
        self.deviceId = deviceId
    }
}

// MARK: - Conflict Resolver Protocol

/// Protocol for custom conflict resolvers
public protocol ConflictResolverProtocol: Sendable {
    
    /// Resolves a conflict
    func resolve(_ context: ConflictContext) async throws -> ConflictResolutionResult
    
    /// Whether this resolver can handle the given conflict
    func canHandle(_ conflict: SyncConflict) -> Bool
    
    /// The priority of this resolver (higher = checked first)
    var priority: Int { get }
}

extension ConflictResolverProtocol {
    public var priority: Int { 0 }
    
    public func canHandle(_ conflict: SyncConflict) -> Bool {
        true
    }
}

// MARK: - Last Write Wins Resolver

/// Resolves conflicts by choosing the most recent write
public struct LastWriteWinsResolver: ConflictResolverProtocol {
    
    public init() {}
    
    public func resolve(_ context: ConflictContext) async throws -> ConflictResolutionResult {
        let localDate = context.conflict.localRecord.localModificationDate
        let remoteDate = context.conflict.remoteRecord.serverModificationDate ?? Date.distantPast
        
        return localDate > remoteDate ? .useLocal : .useRemote
    }
}

// MARK: - Server Wins Resolver

/// Resolves conflicts by always choosing the server version
public struct ServerWinsResolver: ConflictResolverProtocol {
    
    public init() {}
    
    public func resolve(_ context: ConflictContext) async throws -> ConflictResolutionResult {
        .useRemote
    }
}

// MARK: - Client Wins Resolver

/// Resolves conflicts by always choosing the client version
public struct ClientWinsResolver: ConflictResolverProtocol {
    
    public init() {}
    
    public func resolve(_ context: ConflictContext) async throws -> ConflictResolutionResult {
        .useLocal
    }
}

// MARK: - Property-Based Merge Resolver

/// Resolves conflicts by merging individual properties
public struct PropertyMergeResolver<T: Codable & Sendable>: ConflictResolverProtocol {
    
    /// The merge function for each property
    public typealias PropertyMerger = @Sendable (T, T) -> T
    
    private let merger: PropertyMerger
    
    public init(merger: @escaping PropertyMerger) {
        self.merger = merger
    }
    
    public func resolve(_ context: ConflictContext) async throws -> ConflictResolutionResult {
        let decoder = JSONDecoder()
        
        let localObject = try decoder.decode(T.self, from: context.conflict.localRecord.data)
        let remoteObject = try decoder.decode(T.self, from: context.conflict.remoteRecord.data)
        
        let mergedObject = merger(localObject, remoteObject)
        let mergedData = try JSONEncoder().encode(mergedObject)
        
        return .useMerged(mergedData)
    }
}

// MARK: - Field-Level Merge Resolver

/// Resolves conflicts by merging at the field level
public final class FieldLevelMergeResolver: ConflictResolverProtocol, @unchecked Sendable {
    
    /// Strategy for merging a field
    public enum FieldMergeStrategy: Sendable {
        case useLocal
        case useRemote
        case useLatest
        case concatenate
        case sum
        case max
        case min
        case custom(@Sendable (Any, Any) -> Any)
    }
    
    private let fieldStrategies: [String: FieldMergeStrategy]
    private let defaultStrategy: FieldMergeStrategy
    
    public init(
        fieldStrategies: [String: FieldMergeStrategy] = [:],
        defaultStrategy: FieldMergeStrategy = .useLatest
    ) {
        self.fieldStrategies = fieldStrategies
        self.defaultStrategy = defaultStrategy
    }
    
    public func resolve(_ context: ConflictContext) async throws -> ConflictResolutionResult {
        guard let localDict = try? JSONSerialization.jsonObject(with: context.conflict.localRecord.data) as? [String: Any],
              let remoteDict = try? JSONSerialization.jsonObject(with: context.conflict.remoteRecord.data) as? [String: Any] else {
            throw ConflictResolutionError.invalidData
        }
        
        var mergedDict: [String: Any] = [:]
        
        // Get all keys from both dictionaries
        let allKeys = Set(localDict.keys).union(Set(remoteDict.keys))
        
        for key in allKeys {
            let strategy = fieldStrategies[key] ?? defaultStrategy
            let localValue = localDict[key]
            let remoteValue = remoteDict[key]
            
            mergedDict[key] = mergeField(
                local: localValue,
                remote: remoteValue,
                strategy: strategy,
                localDate: context.conflict.localRecord.localModificationDate,
                remoteDate: context.conflict.remoteRecord.serverModificationDate ?? Date.distantPast
            )
        }
        
        let mergedData = try JSONSerialization.data(withJSONObject: mergedDict)
        return .useMerged(mergedData)
    }
    
    private func mergeField(
        local: Any?,
        remote: Any?,
        strategy: FieldMergeStrategy,
        localDate: Date,
        remoteDate: Date
    ) -> Any? {
        switch strategy {
        case .useLocal:
            return local ?? remote
            
        case .useRemote:
            return remote ?? local
            
        case .useLatest:
            return localDate > remoteDate ? (local ?? remote) : (remote ?? local)
            
        case .concatenate:
            if let localStr = local as? String, let remoteStr = remote as? String {
                return localDate > remoteDate ? "\(localStr) \(remoteStr)" : "\(remoteStr) \(localStr)"
            }
            if let localArr = local as? [Any], let remoteArr = remote as? [Any] {
                return localArr + remoteArr
            }
            return local ?? remote
            
        case .sum:
            if let localNum = local as? Double, let remoteNum = remote as? Double {
                return localNum + remoteNum
            }
            if let localNum = local as? Int, let remoteNum = remote as? Int {
                return localNum + remoteNum
            }
            return local ?? remote
            
        case .max:
            if let localNum = local as? Double, let remoteNum = remote as? Double {
                return Swift.max(localNum, remoteNum)
            }
            if let localNum = local as? Int, let remoteNum = remote as? Int {
                return Swift.max(localNum, remoteNum)
            }
            return local ?? remote
            
        case .min:
            if let localNum = local as? Double, let remoteNum = remote as? Double {
                return Swift.min(localNum, remoteNum)
            }
            if let localNum = local as? Int, let remoteNum = remote as? Int {
                return Swift.min(localNum, remoteNum)
            }
            return local ?? remote
            
        case .custom(let merger):
            if let l = local, let r = remote {
                return merger(l, r)
            }
            return local ?? remote
        }
    }
}

// MARK: - Three-Way Merge Resolver

/// Resolves conflicts using three-way merge with a base version
public final class ThreeWayMergeResolver: ConflictResolverProtocol, @unchecked Sendable {
    
    /// Function to get the base version
    public typealias BaseVersionProvider = @Sendable (String, String) async throws -> Data?
    
    private let baseProvider: BaseVersionProvider
    
    public init(baseProvider: @escaping BaseVersionProvider) {
        self.baseProvider = baseProvider
    }
    
    public func resolve(_ context: ConflictContext) async throws -> ConflictResolutionResult {
        // Try to get the base version
        guard let baseData = try await baseProvider(
            context.conflict.recordType,
            context.conflict.recordId
        ) else {
            // Fall back to two-way merge if no base available
            return try await twoWayMerge(context)
        }
        
        guard let baseDict = try? JSONSerialization.jsonObject(with: baseData) as? [String: Any],
              let localDict = try? JSONSerialization.jsonObject(with: context.conflict.localRecord.data) as? [String: Any],
              let remoteDict = try? JSONSerialization.jsonObject(with: context.conflict.remoteRecord.data) as? [String: Any] else {
            throw ConflictResolutionError.invalidData
        }
        
        var mergedDict: [String: Any] = baseDict
        
        // Get all keys
        let allKeys = Set(baseDict.keys)
            .union(Set(localDict.keys))
            .union(Set(remoteDict.keys))
        
        for key in allKeys {
            let baseValue = baseDict[key]
            let localValue = localDict[key]
            let remoteValue = remoteDict[key]
            
            mergedDict[key] = threeWayMergeField(
                base: baseValue,
                local: localValue,
                remote: remoteValue
            )
        }
        
        let mergedData = try JSONSerialization.data(withJSONObject: mergedDict)
        return .useMerged(mergedData)
    }
    
    private func twoWayMerge(_ context: ConflictContext) async throws -> ConflictResolutionResult {
        // Simple two-way merge using timestamps
        let localDate = context.conflict.localRecord.localModificationDate
        let remoteDate = context.conflict.remoteRecord.serverModificationDate ?? Date.distantPast
        
        return localDate > remoteDate ? .useLocal : .useRemote
    }
    
    private func threeWayMergeField(base: Any?, local: Any?, remote: Any?) -> Any? {
        // If local and remote are the same, use that value
        if isEqual(local, remote) {
            return local
        }
        
        // If only local changed from base, use local
        if isEqual(base, remote) && !isEqual(base, local) {
            return local
        }
        
        // If only remote changed from base, use remote
        if isEqual(base, local) && !isEqual(base, remote) {
            return remote
        }
        
        // Both changed - try to merge arrays/strings
        if let localArr = local as? [Any], let remoteArr = remote as? [Any] {
            // Union of arrays
            return Array(Set(localArr.map { "\($0)" }).union(Set(remoteArr.map { "\($0)" })))
        }
        
        // Default to remote (server wins for true conflicts)
        return remote ?? local
    }
    
    private func isEqual(_ a: Any?, _ b: Any?) -> Bool {
        if a == nil && b == nil { return true }
        guard let a = a, let b = b else { return false }
        
        if let aStr = a as? String, let bStr = b as? String {
            return aStr == bStr
        }
        if let aNum = a as? Double, let bNum = b as? Double {
            return aNum == bNum
        }
        if let aInt = a as? Int, let bInt = b as? Int {
            return aInt == bInt
        }
        if let aBool = a as? Bool, let bBool = b as? Bool {
            return aBool == bBool
        }
        
        return false
    }
}

// MARK: - Conflict Resolver Manager

/// Manages multiple conflict resolvers
public actor ConflictResolverManager {
    
    /// Registered resolvers
    private var resolvers: [any ConflictResolverProtocol]
    
    /// Resolution history
    private var history: [ConflictResolutionHistoryEntry]
    
    /// Maximum history entries
    private let maxHistoryEntries: Int
    
    /// Statistics
    private var stats: ConflictResolutionStats
    
    /// Creates a new resolver manager
    public init(maxHistoryEntries: Int = 1000) {
        self.resolvers = []
        self.history = []
        self.maxHistoryEntries = maxHistoryEntries
        self.stats = ConflictResolutionStats()
        
        // Add default resolvers
        registerResolver(LastWriteWinsResolver())
    }
    
    /// Registers a resolver
    public func registerResolver(_ resolver: any ConflictResolverProtocol) {
        resolvers.append(resolver)
        resolvers.sort { $0.priority > $1.priority }
    }
    
    /// Removes all resolvers
    public func clearResolvers() {
        resolvers.removeAll()
    }
    
    /// Resolves a conflict
    public func resolve(_ conflict: SyncConflict, strategy: ConflictResolutionStrategy) async throws -> ConflictResolutionResult {
        let context = ConflictContext(
            conflict: conflict,
            strategy: strategy
        )
        
        stats.totalConflicts += 1
        
        // Find a resolver that can handle this conflict
        for resolver in resolvers {
            if resolver.canHandle(conflict) {
                let startTime = Date()
                
                do {
                    let result = try await resolver.resolve(context)
                    
                    // Record in history
                    let entry = ConflictResolutionHistoryEntry(
                        conflictId: conflict.id,
                        recordType: conflict.recordType,
                        recordId: conflict.recordId,
                        resolverType: String(describing: type(of: resolver)),
                        result: result,
                        resolvedAt: Date(),
                        duration: Date().timeIntervalSince(startTime)
                    )
                    addToHistory(entry)
                    
                    updateStats(for: result)
                    
                    return result
                } catch {
                    stats.failedResolutions += 1
                    throw error
                }
            }
        }
        
        // No resolver found, use default
        stats.failedResolutions += 1
        throw ConflictResolutionError.noResolverFound
    }
    
    /// Batch resolve multiple conflicts
    public func batchResolve(
        _ conflicts: [SyncConflict],
        strategy: ConflictResolutionStrategy
    ) async throws -> [UUID: ConflictResolutionResult] {
        var results: [UUID: ConflictResolutionResult] = [:]
        
        for conflict in conflicts {
            do {
                let result = try await resolve(conflict, strategy: strategy)
                results[conflict.id] = result
            } catch {
                results[conflict.id] = .retryLater
            }
        }
        
        return results
    }
    
    /// Gets resolution history
    public func getHistory(limit: Int? = nil) -> [ConflictResolutionHistoryEntry] {
        if let limit = limit {
            return Array(history.suffix(limit))
        }
        return history
    }
    
    /// Gets statistics
    public func getStats() -> ConflictResolutionStats {
        stats
    }
    
    /// Resets statistics
    public func resetStats() {
        stats = ConflictResolutionStats()
    }
    
    /// Clears history
    public func clearHistory() {
        history.removeAll()
    }
    
    private func addToHistory(_ entry: ConflictResolutionHistoryEntry) {
        history.append(entry)
        
        // Trim if needed
        if history.count > maxHistoryEntries {
            history.removeFirst(history.count - maxHistoryEntries)
        }
    }
    
    private func updateStats(for result: ConflictResolutionResult) {
        switch result {
        case .useLocal:
            stats.localWins += 1
        case .useRemote:
            stats.remoteWins += 1
        case .useMerged:
            stats.mergedResolutions += 1
        case .skip:
            stats.skippedConflicts += 1
        case .retryLater:
            stats.deferredConflicts += 1
        }
    }
}

// MARK: - Conflict Resolution History Entry

/// An entry in the resolution history
public struct ConflictResolutionHistoryEntry: Identifiable, Sendable {
    
    /// The entry identifier
    public let id: UUID
    
    /// The conflict identifier
    public let conflictId: UUID
    
    /// The record type
    public let recordType: String
    
    /// The record identifier
    public let recordId: String
    
    /// The resolver type used
    public let resolverType: String
    
    /// The resolution result
    public let result: ConflictResolutionResult
    
    /// When the conflict was resolved
    public let resolvedAt: Date
    
    /// Resolution duration in seconds
    public let duration: TimeInterval
    
    public init(
        id: UUID = UUID(),
        conflictId: UUID,
        recordType: String,
        recordId: String,
        resolverType: String,
        result: ConflictResolutionResult,
        resolvedAt: Date,
        duration: TimeInterval
    ) {
        self.id = id
        self.conflictId = conflictId
        self.recordType = recordType
        self.recordId = recordId
        self.resolverType = resolverType
        self.result = result
        self.resolvedAt = resolvedAt
        self.duration = duration
    }
}

// MARK: - Conflict Resolution Stats

/// Statistics for conflict resolution
public struct ConflictResolutionStats: Sendable {
    
    /// Total conflicts encountered
    public var totalConflicts: Int = 0
    
    /// Number of times local version won
    public var localWins: Int = 0
    
    /// Number of times remote version won
    public var remoteWins: Int = 0
    
    /// Number of merged resolutions
    public var mergedResolutions: Int = 0
    
    /// Number of skipped conflicts
    public var skippedConflicts: Int = 0
    
    /// Number of deferred conflicts
    public var deferredConflicts: Int = 0
    
    /// Number of failed resolutions
    public var failedResolutions: Int = 0
    
    /// Success rate
    public var successRate: Double {
        guard totalConflicts > 0 else { return 1.0 }
        let successful = totalConflicts - failedResolutions
        return Double(successful) / Double(totalConflicts)
    }
}

// MARK: - Conflict Resolution Error

/// Errors that can occur during conflict resolution
public enum ConflictResolutionError: Error, LocalizedError, Sendable {
    case invalidData
    case noResolverFound
    case mergeFailure(String)
    case baseVersionUnavailable
    case customResolverFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data format for conflict resolution"
        case .noResolverFound:
            return "No resolver found for this conflict type"
        case .mergeFailure(let reason):
            return "Merge failed: \(reason)"
        case .baseVersionUnavailable:
            return "Base version not available for three-way merge"
        case .customResolverFailed(let reason):
            return "Custom resolver failed: \(reason)"
        }
    }
}

// MARK: - Conflict Detection

/// Detects conflicts between records
public struct ConflictDetector: Sendable {
    
    /// Conflict detection mode
    public enum DetectionMode: Sendable {
        /// Detect based on modification dates
        case timestamp
        
        /// Detect based on change tags/versions
        case changeTag
        
        /// Detect based on content comparison
        case content
        
        /// Combine multiple detection methods
        case combined
    }
    
    private let mode: DetectionMode
    
    public init(mode: DetectionMode = .combined) {
        self.mode = mode
    }
    
    /// Detects if there's a conflict between local and remote records
    public func detectConflict(local: SyncRecord, remote: SyncRecord) -> Bool {
        switch mode {
        case .timestamp:
            return detectTimestampConflict(local: local, remote: remote)
            
        case .changeTag:
            return detectChangeTagConflict(local: local, remote: remote)
            
        case .content:
            return detectContentConflict(local: local, remote: remote)
            
        case .combined:
            return detectTimestampConflict(local: local, remote: remote) ||
                   detectChangeTagConflict(local: local, remote: remote)
        }
    }
    
    private func detectTimestampConflict(local: SyncRecord, remote: SyncRecord) -> Bool {
        guard let serverDate = remote.serverModificationDate else {
            return false
        }
        
        // Conflict if both were modified after the last sync
        let threshold: TimeInterval = 1.0 // 1 second tolerance
        return abs(local.localModificationDate.timeIntervalSince(serverDate)) > threshold
    }
    
    private func detectChangeTagConflict(local: SyncRecord, remote: SyncRecord) -> Bool {
        guard let localTag = local.changeTag, let remoteTag = remote.changeTag else {
            return false
        }
        return localTag != remoteTag
    }
    
    private func detectContentConflict(local: SyncRecord, remote: SyncRecord) -> Bool {
        return local.data != remote.data
    }
}

// MARK: - Automatic Conflict Resolution

/// Automatically resolves conflicts based on rules
public actor AutomaticConflictResolver {
    
    /// Resolution rules
    private var rules: [ConflictRule]
    
    /// The fallback strategy
    private let fallbackStrategy: ConflictResolutionStrategy
    
    /// Creates a new automatic resolver
    public init(fallbackStrategy: ConflictResolutionStrategy = .lastWriteWins) {
        self.rules = []
        self.fallbackStrategy = fallbackStrategy
    }
    
    /// Adds a rule
    public func addRule(_ rule: ConflictRule) {
        rules.append(rule)
        rules.sort { $0.priority > $1.priority }
    }
    
    /// Removes rules for a record type
    public func removeRules(for recordType: String) {
        rules.removeAll { $0.recordType == recordType || $0.recordType == "*" }
    }
    
    /// Resolves a conflict automatically
    public func resolve(_ conflict: SyncConflict) -> ConflictResolutionResult {
        // Find matching rule
        for rule in rules {
            if rule.matches(conflict) {
                return rule.resolution
            }
        }
        
        // Apply fallback
        switch fallbackStrategy {
        case .lastWriteWins:
            let localDate = conflict.localRecord.localModificationDate
            let remoteDate = conflict.remoteRecord.serverModificationDate ?? Date.distantPast
            return localDate > remoteDate ? .useLocal : .useRemote
            
        case .serverWins:
            return .useRemote
            
        case .clientWins:
            return .useLocal
            
        case .merge, .custom:
            return .retryLater
        }
    }
}

/// A rule for automatic conflict resolution
public struct ConflictRule: Sendable {
    
    /// The record type this rule applies to ("*" for all)
    public let recordType: String
    
    /// The condition for this rule
    public let condition: ConflictCondition
    
    /// The resolution to apply
    public let resolution: ConflictResolutionResult
    
    /// The priority of this rule
    public let priority: Int
    
    /// Creates a new conflict rule
    public init(
        recordType: String,
        condition: ConflictCondition = .always,
        resolution: ConflictResolutionResult,
        priority: Int = 0
    ) {
        self.recordType = recordType
        self.condition = condition
        self.resolution = resolution
        self.priority = priority
    }
    
    /// Checks if this rule matches a conflict
    public func matches(_ conflict: SyncConflict) -> Bool {
        guard recordType == "*" || recordType == conflict.recordType else {
            return false
        }
        return condition.evaluate(conflict)
    }
}

/// Conditions for conflict rules
public enum ConflictCondition: Sendable {
    /// Always matches
    case always
    
    /// Local is newer
    case localIsNewer
    
    /// Remote is newer
    case remoteIsNewer
    
    /// Local is deleted
    case localIsDeleted
    
    /// Remote is deleted
    case remoteIsDeleted
    
    /// Custom condition
    case custom(@Sendable (SyncConflict) -> Bool)
    
    /// Evaluates the condition
    public func evaluate(_ conflict: SyncConflict) -> Bool {
        switch self {
        case .always:
            return true
            
        case .localIsNewer:
            let localDate = conflict.localRecord.localModificationDate
            let remoteDate = conflict.remoteRecord.serverModificationDate ?? Date.distantPast
            return localDate > remoteDate
            
        case .remoteIsNewer:
            let localDate = conflict.localRecord.localModificationDate
            let remoteDate = conflict.remoteRecord.serverModificationDate ?? Date.distantPast
            return remoteDate > localDate
            
        case .localIsDeleted:
            return conflict.localRecord.isDeleted
            
        case .remoteIsDeleted:
            return conflict.remoteRecord.isDeleted
            
        case .custom(let evaluate):
            return evaluate(conflict)
        }
    }
}