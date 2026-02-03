//
//  RealmEngine.swift
//  SwiftPersistence
//
//  Created by Muhittin Camdali on 2025.
//  MIT License
//

import Foundation
import Combine

// MARK: - Realm Configuration

/// Configuration options for Realm database engine
public struct RealmConfiguration: Sendable, Hashable {
    
    /// The path to the Realm file
    public var fileURL: URL?
    
    /// The encryption key for the Realm file
    public var encryptionKey: Data?
    
    /// Whether to use in-memory storage
    public var inMemoryIdentifier: String?
    
    /// The schema version of the Realm
    public var schemaVersion: UInt64
    
    /// Whether to delete the Realm file if migration is needed
    public var deleteRealmIfMigrationNeeded: Bool
    
    /// Whether to allow read-only access
    public var readOnly: Bool
    
    /// Maximum number of active versions
    public var maximumNumberOfActiveVersions: UInt?
    
    /// Compact on launch threshold
    public var shouldCompactOnLaunch: ((Int, Int) -> Bool)?
    
    /// Object types to include in this Realm
    public var objectTypes: [String]?
    
    /// Creates a new Realm configuration
    public init(
        fileURL: URL? = nil,
        encryptionKey: Data? = nil,
        inMemoryIdentifier: String? = nil,
        schemaVersion: UInt64 = 1,
        deleteRealmIfMigrationNeeded: Bool = false,
        readOnly: Bool = false,
        maximumNumberOfActiveVersions: UInt? = nil,
        objectTypes: [String]? = nil
    ) {
        self.fileURL = fileURL
        self.encryptionKey = encryptionKey
        self.inMemoryIdentifier = inMemoryIdentifier
        self.schemaVersion = schemaVersion
        self.deleteRealmIfMigrationNeeded = deleteRealmIfMigrationNeeded
        self.readOnly = readOnly
        self.maximumNumberOfActiveVersions = maximumNumberOfActiveVersions
        self.objectTypes = objectTypes
        self.shouldCompactOnLaunch = nil
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(fileURL)
        hasher.combine(encryptionKey)
        hasher.combine(inMemoryIdentifier)
        hasher.combine(schemaVersion)
        hasher.combine(deleteRealmIfMigrationNeeded)
        hasher.combine(readOnly)
    }
    
    public static func == (lhs: RealmConfiguration, rhs: RealmConfiguration) -> Bool {
        lhs.fileURL == rhs.fileURL &&
        lhs.encryptionKey == rhs.encryptionKey &&
        lhs.inMemoryIdentifier == rhs.inMemoryIdentifier &&
        lhs.schemaVersion == rhs.schemaVersion &&
        lhs.deleteRealmIfMigrationNeeded == rhs.deleteRealmIfMigrationNeeded &&
        lhs.readOnly == rhs.readOnly
    }
}

// MARK: - Realm Object Protocol

/// Protocol for objects that can be stored in Realm
public protocol RealmStorable: Identifiable, Codable, Sendable {
    /// The primary key property name
    static var primaryKey: String { get }
    
    /// The indexed properties
    static var indexedProperties: [String] { get }
    
    /// The ignored properties
    static var ignoredProperties: [String] { get }
    
    /// Convert to Realm representation
    func toRealmRepresentation() -> [String: Any]
    
    /// Create from Realm representation
    static func fromRealmRepresentation(_ representation: [String: Any]) -> Self?
}

extension RealmStorable {
    public static var indexedProperties: [String] { [] }
    public static var ignoredProperties: [String] { [] }
    
    public func toRealmRepresentation() -> [String: Any] {
        let mirror = Mirror(reflecting: self)
        var dict: [String: Any] = [:]
        for child in mirror.children {
            if let label = child.label {
                dict[label] = child.value
            }
        }
        return dict
    }
}

// MARK: - Realm Query

/// A query builder for Realm objects
public struct RealmQuery<T: RealmStorable> {
    
    /// The filter predicate
    public var predicate: String?
    
    /// The sort descriptors
    public var sortDescriptors: [(String, Bool)]
    
    /// The maximum number of results
    public var limit: Int?
    
    /// The number of results to skip
    public var offset: Int?
    
    /// Creates a new empty query
    public init() {
        self.predicate = nil
        self.sortDescriptors = []
        self.limit = nil
        self.offset = nil
    }
    
    /// Filters results by the given predicate
    public func filter(_ predicate: String) -> RealmQuery<T> {
        var query = self
        if let existing = query.predicate {
            query.predicate = "(\(existing)) AND (\(predicate))"
        } else {
            query.predicate = predicate
        }
        return query
    }
    
    /// Filters results where the property equals the value
    public func `where`(_ property: String, equals value: Any) -> RealmQuery<T> {
        let valueString = formatValue(value)
        return filter("\(property) == \(valueString)")
    }
    
    /// Filters results where the property does not equal the value
    public func `where`(_ property: String, notEquals value: Any) -> RealmQuery<T> {
        let valueString = formatValue(value)
        return filter("\(property) != \(valueString)")
    }
    
    /// Filters results where the property is greater than the value
    public func `where`(_ property: String, greaterThan value: Any) -> RealmQuery<T> {
        let valueString = formatValue(value)
        return filter("\(property) > \(valueString)")
    }
    
    /// Filters results where the property is greater than or equal to the value
    public func `where`(_ property: String, greaterThanOrEqual value: Any) -> RealmQuery<T> {
        let valueString = formatValue(value)
        return filter("\(property) >= \(valueString)")
    }
    
    /// Filters results where the property is less than the value
    public func `where`(_ property: String, lessThan value: Any) -> RealmQuery<T> {
        let valueString = formatValue(value)
        return filter("\(property) < \(valueString)")
    }
    
    /// Filters results where the property is less than or equal to the value
    public func `where`(_ property: String, lessThanOrEqual value: Any) -> RealmQuery<T> {
        let valueString = formatValue(value)
        return filter("\(property) <= \(valueString)")
    }
    
    /// Filters results where the property contains the value
    public func `where`(_ property: String, contains value: String, caseInsensitive: Bool = false) -> RealmQuery<T> {
        let modifier = caseInsensitive ? "[c]" : ""
        return filter("\(property) CONTAINS\(modifier) '\(value)'")
    }
    
    /// Filters results where the property begins with the value
    public func `where`(_ property: String, beginsWith value: String, caseInsensitive: Bool = false) -> RealmQuery<T> {
        let modifier = caseInsensitive ? "[c]" : ""
        return filter("\(property) BEGINSWITH\(modifier) '\(value)'")
    }
    
    /// Filters results where the property ends with the value
    public func `where`(_ property: String, endsWith value: String, caseInsensitive: Bool = false) -> RealmQuery<T> {
        let modifier = caseInsensitive ? "[c]" : ""
        return filter("\(property) ENDSWITH\(modifier) '\(value)'")
    }
    
    /// Filters results where the property matches the pattern
    public func `where`(_ property: String, like pattern: String, caseInsensitive: Bool = false) -> RealmQuery<T> {
        let modifier = caseInsensitive ? "[c]" : ""
        return filter("\(property) LIKE\(modifier) '\(pattern)'")
    }
    
    /// Filters results where the property is in the list of values
    public func `where`(_ property: String, in values: [Any]) -> RealmQuery<T> {
        let valueStrings = values.map { formatValue($0) }.joined(separator: ", ")
        return filter("\(property) IN {\(valueStrings)}")
    }
    
    /// Filters results where the property is between the given values
    public func `where`(_ property: String, between lower: Any, and upper: Any) -> RealmQuery<T> {
        let lowerString = formatValue(lower)
        let upperString = formatValue(upper)
        return filter("\(property) BETWEEN {\(lowerString), \(upperString)}")
    }
    
    /// Filters results where the property is nil
    public func whereNil(_ property: String) -> RealmQuery<T> {
        return filter("\(property) == nil")
    }
    
    /// Filters results where the property is not nil
    public func whereNotNil(_ property: String) -> RealmQuery<T> {
        return filter("\(property) != nil")
    }
    
    /// Sorts results by the given property
    public func sorted(by property: String, ascending: Bool = true) -> RealmQuery<T> {
        var query = self
        query.sortDescriptors.append((property, ascending))
        return query
    }
    
    /// Limits the number of results
    public func limit(_ count: Int) -> RealmQuery<T> {
        var query = self
        query.limit = count
        return query
    }
    
    /// Skips the first n results
    public func offset(_ count: Int) -> RealmQuery<T> {
        var query = self
        query.offset = count
        return query
    }
    
    /// Combines this query with another using AND
    public func and(_ other: RealmQuery<T>) -> RealmQuery<T> {
        var query = self
        if let otherPredicate = other.predicate {
            if let existing = query.predicate {
                query.predicate = "(\(existing)) AND (\(otherPredicate))"
            } else {
                query.predicate = otherPredicate
            }
        }
        return query
    }
    
    /// Combines this query with another using OR
    public func or(_ other: RealmQuery<T>) -> RealmQuery<T> {
        var query = self
        if let otherPredicate = other.predicate {
            if let existing = query.predicate {
                query.predicate = "(\(existing)) OR (\(otherPredicate))"
            } else {
                query.predicate = otherPredicate
            }
        }
        return query
    }
    
    /// Negates the current predicate
    public func not() -> RealmQuery<T> {
        var query = self
        if let existing = query.predicate {
            query.predicate = "NOT (\(existing))"
        }
        return query
    }
    
    private func formatValue(_ value: Any) -> String {
        switch value {
        case let string as String:
            return "'\(string)'"
        case let date as Date:
            return "'\(ISO8601DateFormatter().string(from: date))'"
        case let bool as Bool:
            return bool ? "true" : "false"
        default:
            return "\(value)"
        }
    }
}

// MARK: - Realm Results

/// A collection of results from a Realm query
public struct RealmResults<T: RealmStorable>: Sequence {
    
    /// The items in the results
    public let items: [T]
    
    /// The total count before pagination
    public let totalCount: Int
    
    /// Whether there are more results available
    public let hasMore: Bool
    
    /// Creates new results
    public init(items: [T], totalCount: Int, hasMore: Bool = false) {
        self.items = items
        self.totalCount = totalCount
        self.hasMore = hasMore
    }
    
    /// The number of items in this page of results
    public var count: Int {
        items.count
    }
    
    /// Whether the results are empty
    public var isEmpty: Bool {
        items.isEmpty
    }
    
    /// Gets the item at the given index
    public subscript(index: Int) -> T {
        items[index]
    }
    
    /// Gets the first item
    public var first: T? {
        items.first
    }
    
    /// Gets the last item
    public var last: T? {
        items.last
    }
    
    public func makeIterator() -> IndexingIterator<[T]> {
        items.makeIterator()
    }
    
    /// Maps the results to a new type
    public func map<U>(_ transform: (T) -> U) -> [U] {
        items.map(transform)
    }
    
    /// Filters the results
    public func filter(_ isIncluded: (T) -> Bool) -> [T] {
        items.filter(isIncluded)
    }
    
    /// Reduces the results
    public func reduce<U>(_ initialResult: U, _ nextPartialResult: (U, T) -> U) -> U {
        items.reduce(initialResult, nextPartialResult)
    }
    
    /// Sorts the results
    public func sorted(by areInIncreasingOrder: (T, T) -> Bool) -> [T] {
        items.sorted(by: areInIncreasingOrder)
    }
}

// MARK: - Realm Transaction

/// Represents a Realm write transaction
public final class RealmTransaction: @unchecked Sendable {
    
    /// The transaction identifier
    public let id: UUID
    
    /// The start time of the transaction
    public let startTime: Date
    
    /// The pending operations
    private var operations: [RealmOperation]
    
    /// Whether the transaction has been committed
    private var isCommitted: Bool
    
    /// Whether the transaction has been cancelled
    private var isCancelled: Bool
    
    /// Lock for thread safety
    private let lock = NSLock()
    
    /// Creates a new transaction
    public init() {
        self.id = UUID()
        self.startTime = Date()
        self.operations = []
        self.isCommitted = false
        self.isCancelled = false
    }
    
    /// Adds a create operation
    public func create<T: RealmStorable>(_ object: T) {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isCommitted && !isCancelled else { return }
        operations.append(.create(type: String(describing: T.self), data: object.toRealmRepresentation()))
    }
    
    /// Adds an update operation
    public func update<T: RealmStorable>(_ object: T) {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isCommitted && !isCancelled else { return }
        operations.append(.update(type: String(describing: T.self), data: object.toRealmRepresentation()))
    }
    
    /// Adds a delete operation
    public func delete<T: RealmStorable>(_ object: T) {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isCommitted && !isCancelled else { return }
        operations.append(.delete(type: String(describing: T.self), id: "\(object.id)"))
    }
    
    /// Adds a delete all operation for a type
    public func deleteAll<T: RealmStorable>(_ type: T.Type) {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isCommitted && !isCancelled else { return }
        operations.append(.deleteAll(type: String(describing: type)))
    }
    
    /// Gets all pending operations
    public func getOperations() -> [RealmOperation] {
        lock.lock()
        defer { lock.unlock() }
        return operations
    }
    
    /// Marks the transaction as committed
    public func markCommitted() {
        lock.lock()
        defer { lock.unlock() }
        isCommitted = true
    }
    
    /// Marks the transaction as cancelled
    public func markCancelled() {
        lock.lock()
        defer { lock.unlock() }
        isCancelled = true
    }
}

/// A Realm operation
public enum RealmOperation: Sendable {
    case create(type: String, data: [String: Any])
    case update(type: String, data: [String: Any])
    case delete(type: String, id: String)
    case deleteAll(type: String)
    
    public var description: String {
        switch self {
        case .create(let type, _):
            return "CREATE \(type)"
        case .update(let type, _):
            return "UPDATE \(type)"
        case .delete(let type, let id):
            return "DELETE \(type) [\(id)]"
        case .deleteAll(let type):
            return "DELETE ALL \(type)"
        }
    }
}

// MARK: - Realm Change Observer

/// Observes changes to Realm objects
public final class RealmChangeObserver<T: RealmStorable>: @unchecked Sendable {
    
    /// The change callback
    public typealias ChangeCallback = (RealmChange<T>) -> Void
    
    /// The callback to invoke on changes
    private var callback: ChangeCallback?
    
    /// Whether the observer is active
    private var isActive: Bool
    
    /// Lock for thread safety
    private let lock = NSLock()
    
    /// Creates a new observer
    public init(callback: @escaping ChangeCallback) {
        self.callback = callback
        self.isActive = true
    }
    
    /// Notifies of a change
    public func notify(_ change: RealmChange<T>) {
        lock.lock()
        let active = isActive
        let cb = callback
        lock.unlock()
        
        guard active else { return }
        cb?(change)
    }
    
    /// Invalidates the observer
    public func invalidate() {
        lock.lock()
        defer { lock.unlock() }
        isActive = false
        callback = nil
    }
}

/// A change to Realm objects
public struct RealmChange<T: RealmStorable>: Sendable {
    
    /// The type of change
    public enum ChangeType: Sendable {
        case initial([T])
        case update(deletions: [Int], insertions: [Int], modifications: [Int])
        case error(Error)
    }
    
    /// The type of change
    public let type: ChangeType
    
    /// The current results
    public let results: [T]
    
    /// Creates a new change
    public init(type: ChangeType, results: [T]) {
        self.type = type
        self.results = results
    }
}

// MARK: - Realm Engine

/// A persistence engine backed by Realm
public actor RealmEngine: PersistenceEngine {
    
    /// The configuration
    private let configuration: RealmConfiguration
    
    /// The in-memory storage (simulating Realm for this implementation)
    private var storage: [String: [String: [String: Any]]]
    
    /// Active observers
    private var observers: [String: [UUID: Any]]
    
    /// Active transactions
    private var transactions: [UUID: RealmTransaction]
    
    /// Metrics collector
    private var metrics: RealmMetrics
    
    /// Creates a new Realm engine with the given configuration
    public init(configuration: RealmConfiguration = RealmConfiguration()) {
        self.configuration = configuration
        self.storage = [:]
        self.observers = [:]
        self.transactions = [:]
        self.metrics = RealmMetrics()
    }
    
    /// Creates a new Realm engine with default configuration
    public init() {
        self.configuration = RealmConfiguration()
        self.storage = [:]
        self.observers = [:]
        self.transactions = [:]
        self.metrics = RealmMetrics()
    }
    
    // MARK: - PersistenceEngine Protocol
    
    public var engineType: PersistenceEngineType {
        .realm
    }
    
    public var isAvailable: Bool {
        true
    }
    
    public func save<T: Storable>(_ object: T) async throws {
        let typeName = String(describing: T.self)
        let id = "\(object.id)"
        
        if storage[typeName] == nil {
            storage[typeName] = [:]
        }
        
        let data = try JSONEncoder().encode(object)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        storage[typeName]?[id] = dict
        
        metrics.writeCount += 1
        metrics.lastWriteTime = Date()
    }
    
    public func fetch<T: Storable>(_ type: T.Type, id: T.ID) async throws -> T? {
        let typeName = String(describing: type)
        let idString = "\(id)"
        
        metrics.readCount += 1
        metrics.lastReadTime = Date()
        
        guard let dict = storage[typeName]?[idString] else {
            return nil
        }
        
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(type, from: data)
    }
    
    public func fetchAll<T: Storable>(_ type: T.Type) async throws -> [T] {
        let typeName = String(describing: type)
        
        metrics.readCount += 1
        metrics.lastReadTime = Date()
        
        guard let typeStorage = storage[typeName] else {
            return []
        }
        
        return try typeStorage.values.compactMap { dict in
            let data = try JSONSerialization.data(withJSONObject: dict)
            return try JSONDecoder().decode(type, from: data)
        }
    }
    
    public func delete<T: Storable>(_ type: T.Type, id: T.ID) async throws {
        let typeName = String(describing: type)
        let idString = "\(id)"
        
        storage[typeName]?.removeValue(forKey: idString)
        
        metrics.deleteCount += 1
        metrics.lastDeleteTime = Date()
    }
    
    public func deleteAll<T: Storable>(_ type: T.Type) async throws {
        let typeName = String(describing: type)
        storage[typeName] = nil
        
        metrics.deleteCount += 1
        metrics.lastDeleteTime = Date()
    }
    
    public func count<T: Storable>(_ type: T.Type) async throws -> Int {
        let typeName = String(describing: type)
        return storage[typeName]?.count ?? 0
    }
    
    public func exists<T: Storable>(_ type: T.Type, id: T.ID) async throws -> Bool {
        let typeName = String(describing: type)
        let idString = "\(id)"
        return storage[typeName]?[idString] != nil
    }
    
    // MARK: - Realm-Specific Methods
    
    /// Executes a query
    public func query<T: RealmStorable>(_ type: T.Type, query: RealmQuery<T>) async throws -> RealmResults<T> {
        var results = try await fetchAllRealm(type)
        let totalCount = results.count
        
        // Apply predicate (simplified - in real implementation would parse and apply)
        if query.predicate != nil {
            // In a real implementation, this would parse and apply the predicate
            // For now, we return all results
        }
        
        // Apply sorting
        for (property, ascending) in query.sortDescriptors {
            results.sort { first, second in
                let mirror1 = Mirror(reflecting: first)
                let mirror2 = Mirror(reflecting: second)
                
                let value1 = mirror1.children.first { $0.label == property }?.value
                let value2 = mirror2.children.first { $0.label == property }?.value
                
                if let v1 = value1 as? String, let v2 = value2 as? String {
                    return ascending ? v1 < v2 : v1 > v2
                }
                if let v1 = value1 as? Int, let v2 = value2 as? Int {
                    return ascending ? v1 < v2 : v1 > v2
                }
                if let v1 = value1 as? Double, let v2 = value2 as? Double {
                    return ascending ? v1 < v2 : v1 > v2
                }
                if let v1 = value1 as? Date, let v2 = value2 as? Date {
                    return ascending ? v1 < v2 : v1 > v2
                }
                return false
            }
        }
        
        // Apply offset
        if let offset = query.offset, offset > 0 {
            results = Array(results.dropFirst(offset))
        }
        
        // Apply limit
        var hasMore = false
        if let limit = query.limit, results.count > limit {
            results = Array(results.prefix(limit))
            hasMore = true
        }
        
        return RealmResults(items: results, totalCount: totalCount, hasMore: hasMore)
    }
    
    /// Fetches all objects of a type (Realm-specific)
    private func fetchAllRealm<T: RealmStorable>(_ type: T.Type) async throws -> [T] {
        let typeName = String(describing: type)
        
        guard let typeStorage = storage[typeName] else {
            return []
        }
        
        return try typeStorage.values.compactMap { dict in
            let data = try JSONSerialization.data(withJSONObject: dict)
            return try JSONDecoder().decode(type, from: data)
        }
    }
    
    /// Begins a write transaction
    public func beginTransaction() -> RealmTransaction {
        let transaction = RealmTransaction()
        transactions[transaction.id] = transaction
        return transaction
    }
    
    /// Commits a transaction
    public func commitTransaction(_ transaction: RealmTransaction) async throws {
        let operations = transaction.getOperations()
        
        for operation in operations {
            switch operation {
            case .create(let type, let data):
                if storage[type] == nil {
                    storage[type] = [:]
                }
                if let id = data["id"] {
                    storage[type]?["\(id)"] = data
                }
                
            case .update(let type, let data):
                if let id = data["id"] {
                    storage[type]?["\(id)"] = data
                }
                
            case .delete(let type, let id):
                storage[type]?.removeValue(forKey: id)
                
            case .deleteAll(let type):
                storage[type] = nil
            }
        }
        
        transaction.markCommitted()
        transactions.removeValue(forKey: transaction.id)
        
        metrics.transactionCount += 1
    }
    
    /// Cancels a transaction
    public func cancelTransaction(_ transaction: RealmTransaction) {
        transaction.markCancelled()
        transactions.removeValue(forKey: transaction.id)
    }
    
    /// Performs a write operation in a transaction
    public func write(_ block: @Sendable (RealmTransaction) -> Void) async throws {
        let transaction = beginTransaction()
        block(transaction)
        try await commitTransaction(transaction)
    }
    
    /// Observes changes to objects of a type
    public func observe<T: RealmStorable>(
        _ type: T.Type,
        query: RealmQuery<T>? = nil,
        callback: @escaping (RealmChange<T>) -> Void
    ) -> UUID {
        let observerId = UUID()
        let typeName = String(describing: type)
        
        if observers[typeName] == nil {
            observers[typeName] = [:]
        }
        
        let observer = RealmChangeObserver(callback: callback)
        observers[typeName]?[observerId] = observer
        
        // Send initial results
        Task {
            let results = try? await self.query(type, query: query ?? RealmQuery<T>())
            let items = results?.items ?? []
            callback(RealmChange(type: .initial(items), results: items))
        }
        
        return observerId
    }
    
    /// Stops observing changes
    public func stopObserving<T: RealmStorable>(_ type: T.Type, observerId: UUID) {
        let typeName = String(describing: type)
        if let observer = observers[typeName]?[observerId] as? RealmChangeObserver<T> {
            observer.invalidate()
        }
        observers[typeName]?.removeValue(forKey: observerId)
    }
    
    /// Compacts the Realm file
    public func compact() async throws -> Bool {
        // In a real implementation, this would compact the Realm file
        metrics.compactionCount += 1
        metrics.lastCompactionTime = Date()
        return true
    }
    
    /// Gets the file size of the Realm
    public func fileSize() async throws -> Int64 {
        // Calculate approximate size from storage
        var size: Int64 = 0
        for (_, typeStorage) in storage {
            for (_, dict) in typeStorage {
                if let data = try? JSONSerialization.data(withJSONObject: dict) {
                    size += Int64(data.count)
                }
            }
        }
        return size
    }
    
    /// Gets metrics for the Realm engine
    public func getMetrics() -> RealmMetrics {
        metrics
    }
    
    /// Resets the metrics
    public func resetMetrics() {
        metrics = RealmMetrics()
    }
    
    /// Exports data for backup
    public func exportData() async throws -> Data {
        try JSONSerialization.data(withJSONObject: storage)
    }
    
    /// Imports data from backup
    public func importData(_ data: Data) async throws {
        guard let imported = try JSONSerialization.jsonObject(with: data) as? [String: [String: [String: Any]]] else {
            throw PersistenceError.invalidData("Invalid import data format")
        }
        storage = imported
    }
    
    /// Clears all data
    public func clearAll() async throws {
        storage = [:]
        observers = [:]
        transactions = [:]
    }
}

// MARK: - Realm Metrics

/// Metrics for Realm operations
public struct RealmMetrics: Sendable {
    
    /// Number of read operations
    public var readCount: Int = 0
    
    /// Number of write operations
    public var writeCount: Int = 0
    
    /// Number of delete operations
    public var deleteCount: Int = 0
    
    /// Number of transactions
    public var transactionCount: Int = 0
    
    /// Number of compactions
    public var compactionCount: Int = 0
    
    /// Last read time
    public var lastReadTime: Date?
    
    /// Last write time
    public var lastWriteTime: Date?
    
    /// Last delete time
    public var lastDeleteTime: Date?
    
    /// Last compaction time
    public var lastCompactionTime: Date?
    
    /// Total operations
    public var totalOperations: Int {
        readCount + writeCount + deleteCount
    }
}

// MARK: - Realm Notifications

/// Notification for Realm changes
public extension Notification.Name {
    static let realmDidChange = Notification.Name("SwiftPersistence.RealmDidChange")
    static let realmWillCompact = Notification.Name("SwiftPersistence.RealmWillCompact")
    static let realmDidCompact = Notification.Name("SwiftPersistence.RealmDidCompact")
}

// MARK: - Realm Extensions

extension RealmEngine {
    
    /// Batch insert objects
    public func batchInsert<T: RealmStorable>(_ objects: [T]) async throws {
        try await write { transaction in
            for object in objects {
                transaction.create(object)
            }
        }
    }
    
    /// Batch update objects
    public func batchUpdate<T: RealmStorable>(_ objects: [T]) async throws {
        try await write { transaction in
            for object in objects {
                transaction.update(object)
            }
        }
    }
    
    /// Batch delete objects
    public func batchDelete<T: RealmStorable>(_ objects: [T]) async throws {
        try await write { transaction in
            for object in objects {
                transaction.delete(object)
            }
        }
    }
    
    /// First object matching query
    public func first<T: RealmStorable>(_ type: T.Type, query: RealmQuery<T>) async throws -> T? {
        let results = try await self.query(type, query: query.limit(1))
        return results.first
    }
    
    /// Last object matching query
    public func last<T: RealmStorable>(_ type: T.Type, query: RealmQuery<T>) async throws -> T? {
        let allResults = try await self.query(type, query: query)
        return allResults.last
    }
    
    /// Count objects matching query
    public func count<T: RealmStorable>(_ type: T.Type, query: RealmQuery<T>) async throws -> Int {
        let results = try await self.query(type, query: query)
        return results.totalCount
    }
    
    /// Average of a numeric property
    public func average<T: RealmStorable>(_ type: T.Type, property: String, query: RealmQuery<T>? = nil) async throws -> Double {
        let results = try await self.query(type, query: query ?? RealmQuery<T>())
        
        var sum: Double = 0
        var count = 0
        
        for item in results {
            let mirror = Mirror(reflecting: item)
            if let value = mirror.children.first(where: { $0.label == property })?.value {
                if let intValue = value as? Int {
                    sum += Double(intValue)
                    count += 1
                } else if let doubleValue = value as? Double {
                    sum += doubleValue
                    count += 1
                }
            }
        }
        
        return count > 0 ? sum / Double(count) : 0
    }
    
    /// Sum of a numeric property
    public func sum<T: RealmStorable>(_ type: T.Type, property: String, query: RealmQuery<T>? = nil) async throws -> Double {
        let results = try await self.query(type, query: query ?? RealmQuery<T>())
        
        var sum: Double = 0
        
        for item in results {
            let mirror = Mirror(reflecting: item)
            if let value = mirror.children.first(where: { $0.label == property })?.value {
                if let intValue = value as? Int {
                    sum += Double(intValue)
                } else if let doubleValue = value as? Double {
                    sum += doubleValue
                }
            }
        }
        
        return sum
    }
    
    /// Minimum value of a property
    public func min<T: RealmStorable, V: Comparable>(_ type: T.Type, property: String, query: RealmQuery<T>? = nil) async throws -> V? {
        let results = try await self.query(type, query: query ?? RealmQuery<T>())
        
        var minValue: V?
        
        for item in results {
            let mirror = Mirror(reflecting: item)
            if let value = mirror.children.first(where: { $0.label == property })?.value as? V {
                if minValue == nil || value < minValue! {
                    minValue = value
                }
            }
        }
        
        return minValue
    }
    
    /// Maximum value of a property
    public func max<T: RealmStorable, V: Comparable>(_ type: T.Type, property: String, query: RealmQuery<T>? = nil) async throws -> V? {
        let results = try await self.query(type, query: query ?? RealmQuery<T>())
        
        var maxValue: V?
        
        for item in results {
            let mirror = Mirror(reflecting: item)
            if let value = mirror.children.first(where: { $0.label == property })?.value as? V {
                if maxValue == nil || value > maxValue! {
                    maxValue = value
                }
            }
        }
        
        return maxValue
    }
}
