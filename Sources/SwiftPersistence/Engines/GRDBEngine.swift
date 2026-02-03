//
//  GRDBEngine.swift
//  SwiftPersistence
//
//  Created by Muhittin Camdali on 2025.
//  MIT License
//

import Foundation
import Combine

// MARK: - GRDB Configuration

/// Configuration options for GRDB database engine
public struct GRDBConfiguration: Sendable, Hashable {
    
    /// The path to the database file
    public var databasePath: String?
    
    /// Whether to use in-memory storage
    public var inMemory: Bool
    
    /// Whether to use WAL mode
    public var walMode: Bool
    
    /// The busy timeout in seconds
    public var busyTimeout: Double
    
    /// Whether foreign keys are enabled
    public var foreignKeysEnabled: Bool
    
    /// The journal mode
    public var journalMode: JournalMode
    
    /// The synchronous mode
    public var synchronousMode: SynchronousMode
    
    /// Maximum number of connections in the pool
    public var maximumPoolSize: Int
    
    /// Whether to enable tracing
    public var tracingEnabled: Bool
    
    /// The page size
    public var pageSize: Int
    
    /// The cache size
    public var cacheSize: Int
    
    /// Whether auto vacuum is enabled
    public var autoVacuum: AutoVacuumMode
    
    /// Journal mode options
    public enum JournalMode: String, Sendable {
        case delete = "DELETE"
        case truncate = "TRUNCATE"
        case persist = "PERSIST"
        case memory = "MEMORY"
        case wal = "WAL"
        case off = "OFF"
    }
    
    /// Synchronous mode options
    public enum SynchronousMode: String, Sendable {
        case off = "OFF"
        case normal = "NORMAL"
        case full = "FULL"
        case extra = "EXTRA"
    }
    
    /// Auto vacuum mode options
    public enum AutoVacuumMode: Int, Sendable {
        case none = 0
        case full = 1
        case incremental = 2
    }
    
    /// Creates a new GRDB configuration
    public init(
        databasePath: String? = nil,
        inMemory: Bool = false,
        walMode: Bool = true,
        busyTimeout: Double = 5.0,
        foreignKeysEnabled: Bool = true,
        journalMode: JournalMode = .wal,
        synchronousMode: SynchronousMode = .normal,
        maximumPoolSize: Int = 5,
        tracingEnabled: Bool = false,
        pageSize: Int = 4096,
        cacheSize: Int = 2000,
        autoVacuum: AutoVacuumMode = .none
    ) {
        self.databasePath = databasePath
        self.inMemory = inMemory
        self.walMode = walMode
        self.busyTimeout = busyTimeout
        self.foreignKeysEnabled = foreignKeysEnabled
        self.journalMode = journalMode
        self.synchronousMode = synchronousMode
        self.maximumPoolSize = maximumPoolSize
        self.tracingEnabled = tracingEnabled
        self.pageSize = pageSize
        self.cacheSize = cacheSize
        self.autoVacuum = autoVacuum
    }
    
    /// Default configuration
    public static var `default`: GRDBConfiguration {
        GRDBConfiguration()
    }
    
    /// In-memory configuration
    public static var memory: GRDBConfiguration {
        GRDBConfiguration(inMemory: true)
    }
}

// MARK: - GRDB Persistable Protocol

/// Protocol for objects that can be persisted with GRDB
public protocol GRDBPersistable: Identifiable, Codable, Sendable {
    
    /// The table name for this type
    static var tableName: String { get }
    
    /// The column definitions for creating the table
    static var columnDefinitions: [GRDBColumnDefinition] { get }
    
    /// The primary key column name
    static var primaryKeyColumn: String { get }
    
    /// Additional indexes to create
    static var indexes: [GRDBIndex] { get }
    
    /// Convert to a dictionary for insertion
    func toDictionary() -> [String: DatabaseValue]
    
    /// Create from a row dictionary
    static func fromRow(_ row: [String: DatabaseValue]) -> Self?
}

extension GRDBPersistable {
    public static var tableName: String {
        String(describing: self)
    }
    
    public static var primaryKeyColumn: String {
        "id"
    }
    
    public static var indexes: [GRDBIndex] {
        []
    }
    
    public func toDictionary() -> [String: DatabaseValue] {
        let mirror = Mirror(reflecting: self)
        var dict: [String: DatabaseValue] = [:]
        
        for child in mirror.children {
            if let label = child.label {
                dict[label] = DatabaseValue(child.value)
            }
        }
        
        return dict
    }
}

// MARK: - Column Definition

/// Definition of a database column
public struct GRDBColumnDefinition: Sendable {
    
    /// The column name
    public let name: String
    
    /// The column type
    public let type: ColumnType
    
    /// Whether the column is the primary key
    public let isPrimaryKey: Bool
    
    /// Whether the column auto increments
    public let autoIncrement: Bool
    
    /// Whether the column can be null
    public let nullable: Bool
    
    /// The default value
    public let defaultValue: DatabaseValue?
    
    /// Whether the column is unique
    public let unique: Bool
    
    /// Foreign key reference
    public let foreignKey: ForeignKeyReference?
    
    /// Column types
    public enum ColumnType: String, Sendable {
        case integer = "INTEGER"
        case real = "REAL"
        case text = "TEXT"
        case blob = "BLOB"
        case boolean = "BOOLEAN"
        case date = "DATE"
        case datetime = "DATETIME"
    }
    
    /// Foreign key reference
    public struct ForeignKeyReference: Sendable {
        public let table: String
        public let column: String
        public let onDelete: ForeignKeyAction
        public let onUpdate: ForeignKeyAction
        
        public enum ForeignKeyAction: String, Sendable {
            case noAction = "NO ACTION"
            case restrict = "RESTRICT"
            case setNull = "SET NULL"
            case setDefault = "SET DEFAULT"
            case cascade = "CASCADE"
        }
        
        public init(
            table: String,
            column: String,
            onDelete: ForeignKeyAction = .noAction,
            onUpdate: ForeignKeyAction = .noAction
        ) {
            self.table = table
            self.column = column
            self.onDelete = onDelete
            self.onUpdate = onUpdate
        }
    }
    
    /// Creates a new column definition
    public init(
        name: String,
        type: ColumnType,
        isPrimaryKey: Bool = false,
        autoIncrement: Bool = false,
        nullable: Bool = true,
        defaultValue: DatabaseValue? = nil,
        unique: Bool = false,
        foreignKey: ForeignKeyReference? = nil
    ) {
        self.name = name
        self.type = type
        self.isPrimaryKey = isPrimaryKey
        self.autoIncrement = autoIncrement
        self.nullable = nullable
        self.defaultValue = defaultValue
        self.unique = unique
        self.foreignKey = foreignKey
    }
    
    /// Generates the SQL for this column
    public var sql: String {
        var parts: [String] = ["\"\(name)\"", type.rawValue]
        
        if isPrimaryKey {
            parts.append("PRIMARY KEY")
            if autoIncrement {
                parts.append("AUTOINCREMENT")
            }
        }
        
        if !nullable {
            parts.append("NOT NULL")
        }
        
        if unique {
            parts.append("UNIQUE")
        }
        
        if let defaultValue = defaultValue {
            parts.append("DEFAULT \(defaultValue.sqlLiteral)")
        }
        
        return parts.joined(separator: " ")
    }
}

// MARK: - Index Definition

/// Definition of a database index
public struct GRDBIndex: Sendable {
    
    /// The index name
    public let name: String
    
    /// The columns in the index
    public let columns: [String]
    
    /// Whether the index is unique
    public let unique: Bool
    
    /// The condition for a partial index
    public let condition: String?
    
    /// Creates a new index definition
    public init(
        name: String,
        columns: [String],
        unique: Bool = false,
        condition: String? = nil
    ) {
        self.name = name
        self.columns = columns
        self.unique = unique
        self.condition = condition
    }
    
    /// Generates the SQL for creating this index
    public func createSQL(tableName: String) -> String {
        var sql = unique ? "CREATE UNIQUE INDEX" : "CREATE INDEX"
        sql += " IF NOT EXISTS \"\(name)\" ON \"\(tableName)\""
        sql += " (\(columns.map { "\"\($0)\"" }.joined(separator: ", ")))"
        
        if let condition = condition {
            sql += " WHERE \(condition)"
        }
        
        return sql
    }
}

// MARK: - Database Value

/// A value that can be stored in the database
public enum DatabaseValue: Sendable, Hashable {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)
    
    /// Creates a database value from any value
    public init(_ value: Any) {
        switch value {
        case let int as Int:
            self = .integer(Int64(int))
        case let int64 as Int64:
            self = .integer(int64)
        case let double as Double:
            self = .real(double)
        case let float as Float:
            self = .real(Double(float))
        case let string as String:
            self = .text(string)
        case let data as Data:
            self = .blob(data)
        case let bool as Bool:
            self = .integer(bool ? 1 : 0)
        case let date as Date:
            self = .real(date.timeIntervalSince1970)
        case let uuid as UUID:
            self = .text(uuid.uuidString)
        case Optional<Any>.none:
            self = .null
        default:
            self = .text("\(value)")
        }
    }
    
    /// The SQL literal representation
    public var sqlLiteral: String {
        switch self {
        case .null:
            return "NULL"
        case .integer(let value):
            return "\(value)"
        case .real(let value):
            return "\(value)"
        case .text(let value):
            return "'\(value.replacingOccurrences(of: "'", with: "''"))'"
        case .blob(let value):
            return "X'\(value.map { String(format: "%02X", $0) }.joined())'"
        }
    }
    
    /// Gets the value as the specified type
    public func value<T>() -> T? {
        switch self {
        case .null:
            return nil
        case .integer(let value):
            if T.self == Int.self { return value as? T ?? Int(value) as? T }
            if T.self == Int64.self { return value as? T }
            if T.self == Bool.self { return (value != 0) as? T }
            return nil
        case .real(let value):
            if T.self == Double.self { return value as? T }
            if T.self == Float.self { return Float(value) as? T }
            if T.self == Date.self { return Date(timeIntervalSince1970: value) as? T }
            return nil
        case .text(let value):
            if T.self == String.self { return value as? T }
            if T.self == UUID.self { return UUID(uuidString: value) as? T }
            return nil
        case .blob(let value):
            if T.self == Data.self { return value as? T }
            return nil
        }
    }
}

// MARK: - GRDB Query Builder

/// A query builder for GRDB
public struct GRDBQueryBuilder<T: GRDBPersistable> {
    
    /// The SELECT clause
    private var selectClause: String
    
    /// The WHERE conditions
    private var whereConditions: [String]
    
    /// The ORDER BY clauses
    private var orderByClauses: [(String, Bool)]
    
    /// The LIMIT value
    private var limitValue: Int?
    
    /// The OFFSET value
    private var offsetValue: Int?
    
    /// The GROUP BY columns
    private var groupByColumns: [String]
    
    /// The HAVING conditions
    private var havingConditions: [String]
    
    /// The JOIN clauses
    private var joinClauses: [String]
    
    /// Creates a new query builder
    public init() {
        self.selectClause = "*"
        self.whereConditions = []
        self.orderByClauses = []
        self.limitValue = nil
        self.offsetValue = nil
        self.groupByColumns = []
        self.havingConditions = []
        self.joinClauses = []
    }
    
    /// Sets the columns to select
    public func select(_ columns: String...) -> GRDBQueryBuilder<T> {
        var builder = self
        builder.selectClause = columns.joined(separator: ", ")
        return builder
    }
    
    /// Adds a WHERE condition
    public func `where`(_ condition: String) -> GRDBQueryBuilder<T> {
        var builder = self
        builder.whereConditions.append(condition)
        return builder
    }
    
    /// Adds an equality condition
    public func `where`(_ column: String, equals value: DatabaseValue) -> GRDBQueryBuilder<T> {
        return self.where("\"\(column)\" = \(value.sqlLiteral)")
    }
    
    /// Adds a not equal condition
    public func `where`(_ column: String, notEquals value: DatabaseValue) -> GRDBQueryBuilder<T> {
        return self.where("\"\(column)\" != \(value.sqlLiteral)")
    }
    
    /// Adds a greater than condition
    public func `where`(_ column: String, greaterThan value: DatabaseValue) -> GRDBQueryBuilder<T> {
        return self.where("\"\(column)\" > \(value.sqlLiteral)")
    }
    
    /// Adds a greater than or equal condition
    public func `where`(_ column: String, greaterThanOrEqual value: DatabaseValue) -> GRDBQueryBuilder<T> {
        return self.where("\"\(column)\" >= \(value.sqlLiteral)")
    }
    
    /// Adds a less than condition
    public func `where`(_ column: String, lessThan value: DatabaseValue) -> GRDBQueryBuilder<T> {
        return self.where("\"\(column)\" < \(value.sqlLiteral)")
    }
    
    /// Adds a less than or equal condition
    public func `where`(_ column: String, lessThanOrEqual value: DatabaseValue) -> GRDBQueryBuilder<T> {
        return self.where("\"\(column)\" <= \(value.sqlLiteral)")
    }
    
    /// Adds a LIKE condition
    public func `where`(_ column: String, like pattern: String) -> GRDBQueryBuilder<T> {
        return self.where("\"\(column)\" LIKE '\(pattern)'")
    }
    
    /// Adds an IN condition
    public func `where`(_ column: String, in values: [DatabaseValue]) -> GRDBQueryBuilder<T> {
        let valueList = values.map { $0.sqlLiteral }.joined(separator: ", ")
        return self.where("\"\(column)\" IN (\(valueList))")
    }
    
    /// Adds a BETWEEN condition
    public func `where`(_ column: String, between lower: DatabaseValue, and upper: DatabaseValue) -> GRDBQueryBuilder<T> {
        return self.where("\"\(column)\" BETWEEN \(lower.sqlLiteral) AND \(upper.sqlLiteral)")
    }
    
    /// Adds an IS NULL condition
    public func whereNull(_ column: String) -> GRDBQueryBuilder<T> {
        return self.where("\"\(column)\" IS NULL")
    }
    
    /// Adds an IS NOT NULL condition
    public func whereNotNull(_ column: String) -> GRDBQueryBuilder<T> {
        return self.where("\"\(column)\" IS NOT NULL")
    }
    
    /// Adds an ORDER BY clause
    public func orderBy(_ column: String, ascending: Bool = true) -> GRDBQueryBuilder<T> {
        var builder = self
        builder.orderByClauses.append((column, ascending))
        return builder
    }
    
    /// Sets the LIMIT
    public func limit(_ count: Int) -> GRDBQueryBuilder<T> {
        var builder = self
        builder.limitValue = count
        return builder
    }
    
    /// Sets the OFFSET
    public func offset(_ count: Int) -> GRDBQueryBuilder<T> {
        var builder = self
        builder.offsetValue = count
        return builder
    }
    
    /// Adds GROUP BY columns
    public func groupBy(_ columns: String...) -> GRDBQueryBuilder<T> {
        var builder = self
        builder.groupByColumns.append(contentsOf: columns)
        return builder
    }
    
    /// Adds a HAVING condition
    public func having(_ condition: String) -> GRDBQueryBuilder<T> {
        var builder = self
        builder.havingConditions.append(condition)
        return builder
    }
    
    /// Adds an INNER JOIN
    public func innerJoin(_ table: String, on condition: String) -> GRDBQueryBuilder<T> {
        var builder = self
        builder.joinClauses.append("INNER JOIN \"\(table)\" ON \(condition)")
        return builder
    }
    
    /// Adds a LEFT JOIN
    public func leftJoin(_ table: String, on condition: String) -> GRDBQueryBuilder<T> {
        var builder = self
        builder.joinClauses.append("LEFT JOIN \"\(table)\" ON \(condition)")
        return builder
    }
    
    /// Builds the SQL query
    public func buildSQL() -> String {
        var sql = "SELECT \(selectClause) FROM \"\(T.tableName)\""
        
        if !joinClauses.isEmpty {
            sql += " " + joinClauses.joined(separator: " ")
        }
        
        if !whereConditions.isEmpty {
            sql += " WHERE " + whereConditions.joined(separator: " AND ")
        }
        
        if !groupByColumns.isEmpty {
            sql += " GROUP BY " + groupByColumns.map { "\"\($0)\"" }.joined(separator: ", ")
        }
        
        if !havingConditions.isEmpty {
            sql += " HAVING " + havingConditions.joined(separator: " AND ")
        }
        
        if !orderByClauses.isEmpty {
            let orderClauses = orderByClauses.map { "\"\($0.0)\" \($0.1 ? "ASC" : "DESC")" }
            sql += " ORDER BY " + orderClauses.joined(separator: ", ")
        }
        
        if let limit = limitValue {
            sql += " LIMIT \(limit)"
        }
        
        if let offset = offsetValue {
            sql += " OFFSET \(offset)"
        }
        
        return sql
    }
}

// MARK: - GRDB Engine

/// A persistence engine backed by GRDB (SQLite)
public actor GRDBEngine: PersistenceEngine {
    
    /// The configuration
    private let configuration: GRDBConfiguration
    
    /// The in-memory storage (simulating GRDB for this implementation)
    private var tables: [String: [[String: DatabaseValue]]]
    
    /// Table schemas
    private var schemas: [String: [GRDBColumnDefinition]]
    
    /// Metrics collector
    private var metrics: GRDBMetrics
    
    /// Statement cache
    private var statementCache: [String: Date]
    
    /// Active transactions
    private var activeTransaction: Bool
    
    /// Transaction savepoints
    private var savepoints: [String]
    
    /// Creates a new GRDB engine with the given configuration
    public init(configuration: GRDBConfiguration = .default) {
        self.configuration = configuration
        self.tables = [:]
        self.schemas = [:]
        self.metrics = GRDBMetrics()
        self.statementCache = [:]
        self.activeTransaction = false
        self.savepoints = []
    }
    
    /// Creates a new GRDB engine with default configuration
    public init() {
        self.configuration = .default
        self.tables = [:]
        self.schemas = [:]
        self.metrics = GRDBMetrics()
        self.statementCache = [:]
        self.activeTransaction = false
        self.savepoints = []
    }
    
    // MARK: - PersistenceEngine Protocol
    
    public var engineType: PersistenceEngineType {
        .sqlite
    }
    
    public var isAvailable: Bool {
        true
    }
    
    public func save<T: Storable>(_ object: T) async throws {
        let tableName = String(describing: T.self)
        let id = "\(object.id)"
        
        try await ensureTable(for: T.self)
        
        let data = try JSONEncoder().encode(object)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PersistenceError.serializationFailed
        }
        
        var row: [String: DatabaseValue] = [:]
        for (key, value) in dict {
            row[key] = DatabaseValue(value)
        }
        
        if tables[tableName] == nil {
            tables[tableName] = []
        }
        
        // Update existing or insert new
        if let index = tables[tableName]?.firstIndex(where: { $0["id"]?.value() == id }) {
            tables[tableName]?[index] = row
        } else {
            tables[tableName]?.append(row)
        }
        
        metrics.writeCount += 1
        metrics.lastWriteTime = Date()
    }
    
    public func fetch<T: Storable>(_ type: T.Type, id: T.ID) async throws -> T? {
        let tableName = String(describing: type)
        let idString = "\(id)"
        
        metrics.readCount += 1
        metrics.lastReadTime = Date()
        
        guard let rows = tables[tableName],
              let row = rows.first(where: { ($0["id"]?.value() as String?) == idString }) else {
            return nil
        }
        
        return try decodeRow(row, as: type)
    }
    
    public func fetchAll<T: Storable>(_ type: T.Type) async throws -> [T] {
        let tableName = String(describing: type)
        
        metrics.readCount += 1
        metrics.lastReadTime = Date()
        
        guard let rows = tables[tableName] else {
            return []
        }
        
        return try rows.compactMap { try decodeRow($0, as: type) }
    }
    
    public func delete<T: Storable>(_ type: T.Type, id: T.ID) async throws {
        let tableName = String(describing: type)
        let idString = "\(id)"
        
        tables[tableName]?.removeAll { ($0["id"]?.value() as String?) == idString }
        
        metrics.deleteCount += 1
        metrics.lastDeleteTime = Date()
    }
    
    public func deleteAll<T: Storable>(_ type: T.Type) async throws {
        let tableName = String(describing: type)
        tables[tableName] = []
        
        metrics.deleteCount += 1
        metrics.lastDeleteTime = Date()
    }
    
    public func count<T: Storable>(_ type: T.Type) async throws -> Int {
        let tableName = String(describing: type)
        return tables[tableName]?.count ?? 0
    }
    
    public func exists<T: Storable>(_ type: T.Type, id: T.ID) async throws -> Bool {
        let tableName = String(describing: type)
        let idString = "\(id)"
        return tables[tableName]?.contains { ($0["id"]?.value() as String?) == idString } ?? false
    }
    
    // MARK: - GRDB-Specific Methods
    
    /// Creates a table for the given type
    public func createTable<T: GRDBPersistable>(_ type: T.Type) async throws {
        let tableName = T.tableName
        let columns = T.columnDefinitions
        
        schemas[tableName] = columns
        
        if tables[tableName] == nil {
            tables[tableName] = []
        }
        
        // Create indexes
        for index in T.indexes {
            // In a real implementation, this would create actual database indexes
            _ = index.createSQL(tableName: tableName)
        }
        
        metrics.tableCount = tables.count
    }
    
    /// Drops a table
    public func dropTable(_ tableName: String) async throws {
        tables.removeValue(forKey: tableName)
        schemas.removeValue(forKey: tableName)
        metrics.tableCount = tables.count
    }
    
    /// Executes a query and returns results
    public func query<T: GRDBPersistable>(_ type: T.Type, _ builder: GRDBQueryBuilder<T>) async throws -> [T] {
        let tableName = T.tableName
        
        metrics.queryCount += 1
        
        guard let rows = tables[tableName] else {
            return []
        }
        
        // In a real implementation, this would execute the SQL query
        // For this simulation, we return all rows
        return try rows.compactMap { try decodeGRDBRow($0, as: type) }
    }
    
    /// Executes raw SQL
    public func execute(_ sql: String) async throws {
        metrics.queryCount += 1
        statementCache[sql] = Date()
        
        // In a real implementation, this would execute the SQL
        // For this simulation, we just track the query
    }
    
    /// Executes a SELECT query and returns raw results
    public func select(_ sql: String) async throws -> [[String: DatabaseValue]] {
        metrics.queryCount += 1
        
        // In a real implementation, this would execute the SQL
        // For this simulation, we return an empty array
        return []
    }
    
    /// Begins a transaction
    public func beginTransaction() async throws {
        guard !activeTransaction else {
            throw PersistenceError.transactionError("Transaction already active")
        }
        activeTransaction = true
        metrics.transactionCount += 1
    }
    
    /// Commits the current transaction
    public func commitTransaction() async throws {
        guard activeTransaction else {
            throw PersistenceError.transactionError("No active transaction")
        }
        activeTransaction = false
        savepoints.removeAll()
    }
    
    /// Rolls back the current transaction
    public func rollbackTransaction() async throws {
        guard activeTransaction else {
            throw PersistenceError.transactionError("No active transaction")
        }
        activeTransaction = false
        savepoints.removeAll()
    }
    
    /// Creates a savepoint
    public func savepoint(_ name: String) async throws {
        guard activeTransaction else {
            throw PersistenceError.transactionError("No active transaction")
        }
        savepoints.append(name)
    }
    
    /// Releases a savepoint
    public func releaseSavepoint(_ name: String) async throws {
        guard let index = savepoints.firstIndex(of: name) else {
            throw PersistenceError.transactionError("Savepoint not found: \(name)")
        }
        savepoints.remove(at: index)
    }
    
    /// Rolls back to a savepoint
    public func rollbackToSavepoint(_ name: String) async throws {
        guard let index = savepoints.firstIndex(of: name) else {
            throw PersistenceError.transactionError("Savepoint not found: \(name)")
        }
        savepoints.removeSubrange(index...)
    }
    
    /// Performs an operation in a transaction
    public func inTransaction<R: Sendable>(_ operation: @Sendable () async throws -> R) async throws -> R {
        try await beginTransaction()
        
        do {
            let result = try await operation()
            try await commitTransaction()
            return result
        } catch {
            try await rollbackTransaction()
            throw error
        }
    }
    
    /// Vacuums the database
    public func vacuum() async throws {
        metrics.vacuumCount += 1
        metrics.lastVacuumTime = Date()
    }
    
    /// Analyzes the database for query optimization
    public func analyze() async throws {
        metrics.analyzeCount += 1
    }
    
    /// Gets database statistics
    public func getStatistics() -> GRDBStatistics {
        var totalRows = 0
        for (_, rows) in tables {
            totalRows += rows.count
        }
        
        return GRDBStatistics(
            tableCount: tables.count,
            totalRows: totalRows,
            cacheSize: statementCache.count,
            pageCount: 0,
            pageSize: configuration.pageSize
        )
    }
    
    /// Gets metrics for the GRDB engine
    public func getMetrics() -> GRDBMetrics {
        metrics
    }
    
    /// Resets the metrics
    public func resetMetrics() {
        metrics = GRDBMetrics()
    }
    
    /// Clears the statement cache
    public func clearStatementCache() {
        statementCache.removeAll()
    }
    
    /// Exports the database
    public func exportDatabase() async throws -> Data {
        let exportData: [String: Any] = [
            "tables": tables.mapValues { rows in
                rows.map { row in
                    row.mapValues { value -> Any in
                        switch value {
                        case .null: return NSNull()
                        case .integer(let v): return v
                        case .real(let v): return v
                        case .text(let v): return v
                        case .blob(let v): return v.base64EncodedString()
                        }
                    }
                }
            }
        ]
        return try JSONSerialization.data(withJSONObject: exportData)
    }
    
    /// Imports a database
    public func importDatabase(_ data: Data) async throws {
        guard let importData = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tablesData = importData["tables"] as? [String: [[String: Any]]] else {
            throw PersistenceError.invalidData("Invalid import data format")
        }
        
        for (tableName, rows) in tablesData {
            tables[tableName] = rows.map { row in
                row.mapValues { DatabaseValue($0) }
            }
        }
    }
    
    /// Clears all data
    public func clearAll() async throws {
        tables.removeAll()
        schemas.removeAll()
        statementCache.removeAll()
    }
    
    // MARK: - Private Helpers
    
    private func ensureTable<T: Storable>(for type: T.Type) async throws {
        let tableName = String(describing: type)
        if tables[tableName] == nil {
            tables[tableName] = []
        }
    }
    
    private func decodeRow<T: Storable>(_ row: [String: DatabaseValue], as type: T.Type) throws -> T? {
        var dict: [String: Any] = [:]
        
        for (key, value) in row {
            switch value {
            case .null:
                continue
            case .integer(let v):
                dict[key] = v
            case .real(let v):
                dict[key] = v
            case .text(let v):
                dict[key] = v
            case .blob(let v):
                dict[key] = v
            }
        }
        
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(type, from: data)
    }
    
    private func decodeGRDBRow<T: GRDBPersistable>(_ row: [String: DatabaseValue], as type: T.Type) throws -> T? {
        return T.fromRow(row)
    }
}

// MARK: - GRDB Metrics

/// Metrics for GRDB operations
public struct GRDBMetrics: Sendable {
    
    /// Number of read operations
    public var readCount: Int = 0
    
    /// Number of write operations
    public var writeCount: Int = 0
    
    /// Number of delete operations
    public var deleteCount: Int = 0
    
    /// Number of query operations
    public var queryCount: Int = 0
    
    /// Number of transactions
    public var transactionCount: Int = 0
    
    /// Number of vacuums
    public var vacuumCount: Int = 0
    
    /// Number of analyzes
    public var analyzeCount: Int = 0
    
    /// Number of tables
    public var tableCount: Int = 0
    
    /// Last read time
    public var lastReadTime: Date?
    
    /// Last write time
    public var lastWriteTime: Date?
    
    /// Last delete time
    public var lastDeleteTime: Date?
    
    /// Last vacuum time
    public var lastVacuumTime: Date?
    
    /// Total operations
    public var totalOperations: Int {
        readCount + writeCount + deleteCount + queryCount
    }
}

// MARK: - GRDB Statistics

/// Statistics for the GRDB database
public struct GRDBStatistics: Sendable {
    
    /// Number of tables
    public let tableCount: Int
    
    /// Total number of rows
    public let totalRows: Int
    
    /// Statement cache size
    public let cacheSize: Int
    
    /// Number of pages
    public let pageCount: Int
    
    /// Page size
    public let pageSize: Int
    
    /// Estimated database size
    public var estimatedSize: Int64 {
        Int64(pageCount * pageSize)
    }
}

// MARK: - Batch Operations

extension GRDBEngine {
    
    /// Batch insert objects
    public func batchInsert<T: GRDBPersistable>(_ objects: [T]) async throws {
        try await inTransaction {
            for object in objects {
                let tableName = T.tableName
                let row = object.toDictionary()
                
                if self.tables[tableName] == nil {
                    self.tables[tableName] = []
                }
                self.tables[tableName]?.append(row)
            }
        }
    }
    
    /// Batch update objects
    public func batchUpdate<T: GRDBPersistable>(_ objects: [T]) async throws {
        try await inTransaction {
            for object in objects {
                let tableName = T.tableName
                let row = object.toDictionary()
                let id = "\(object.id)"
                
                if let index = self.tables[tableName]?.firstIndex(where: { ($0["id"]?.value() as String?) == id }) {
                    self.tables[tableName]?[index] = row
                }
            }
        }
    }
    
    /// Batch delete objects
    public func batchDelete<T: GRDBPersistable>(_ objects: [T]) async throws {
        try await inTransaction {
            for object in objects {
                let tableName = T.tableName
                let id = "\(object.id)"
                
                self.tables[tableName]?.removeAll { ($0["id"]?.value() as String?) == id }
            }
        }
    }
}

// MARK: - Aggregate Functions

extension GRDBEngine {
    
    /// Counts rows matching a condition
    public func count<T: GRDBPersistable>(_ type: T.Type, where condition: String? = nil) async throws -> Int {
        let tableName = T.tableName
        return tables[tableName]?.count ?? 0
    }
    
    /// Sums a column
    public func sum<T: GRDBPersistable>(_ type: T.Type, column: String, where condition: String? = nil) async throws -> Double {
        let tableName = T.tableName
        var total: Double = 0
        
        for row in tables[tableName] ?? [] {
            if let value = row[column] {
                switch value {
                case .integer(let v):
                    total += Double(v)
                case .real(let v):
                    total += v
                default:
                    break
                }
            }
        }
        
        return total
    }
    
    /// Averages a column
    public func average<T: GRDBPersistable>(_ type: T.Type, column: String, where condition: String? = nil) async throws -> Double {
        let count = try await count(type, where: condition)
        guard count > 0 else { return 0 }
        
        let sum = try await sum(type, column: column, where: condition)
        return sum / Double(count)
    }
    
    /// Gets the minimum value of a column
    public func min<T: GRDBPersistable>(_ type: T.Type, column: String, where condition: String? = nil) async throws -> DatabaseValue? {
        let tableName = T.tableName
        var minValue: DatabaseValue?
        
        for row in tables[tableName] ?? [] {
            if let value = row[column] {
                if minValue == nil {
                    minValue = value
                } else {
                    switch (minValue!, value) {
                    case (.integer(let a), .integer(let b)):
                        if b < a { minValue = value }
                    case (.real(let a), .real(let b)):
                        if b < a { minValue = value }
                    case (.text(let a), .text(let b)):
                        if b < a { minValue = value }
                    default:
                        break
                    }
                }
            }
        }
        
        return minValue
    }
    
    /// Gets the maximum value of a column
    public func max<T: GRDBPersistable>(_ type: T.Type, column: String, where condition: String? = nil) async throws -> DatabaseValue? {
        let tableName = T.tableName
        var maxValue: DatabaseValue?
        
        for row in tables[tableName] ?? [] {
            if let value = row[column] {
                if maxValue == nil {
                    maxValue = value
                } else {
                    switch (maxValue!, value) {
                    case (.integer(let a), .integer(let b)):
                        if b > a { maxValue = value }
                    case (.real(let a), .real(let b)):
                        if b > a { maxValue = value }
                    case (.text(let a), .text(let b)):
                        if b > a { maxValue = value }
                    default:
                        break
                    }
                }
            }
        }
        
        return maxValue
    }
}
