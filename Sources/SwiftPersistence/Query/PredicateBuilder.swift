//
//  PredicateBuilder.swift
//  SwiftPersistence
//
//  Created by Muhittin Camdali on 2025.
//  MIT License
//

import Foundation

// MARK: - Predicate

/// A type-safe predicate for querying data
public struct Predicate<T>: Sendable {
    
    /// The predicate expression
    public let expression: PredicateExpression
    
    /// Creates a predicate from an expression
    public init(_ expression: PredicateExpression) {
        self.expression = expression
    }
    
    /// Creates an always-true predicate
    public static var `true`: Predicate<T> {
        Predicate(.literal(true))
    }
    
    /// Creates an always-false predicate
    public static var `false`: Predicate<T> {
        Predicate(.literal(false))
    }
    
    /// Combines this predicate with another using AND
    public func and(_ other: Predicate<T>) -> Predicate<T> {
        Predicate(.and(expression, other.expression))
    }
    
    /// Combines this predicate with another using OR
    public func or(_ other: Predicate<T>) -> Predicate<T> {
        Predicate(.or(expression, other.expression))
    }
    
    /// Negates this predicate
    public var not: Predicate<T> {
        Predicate(.not(expression))
    }
    
    /// Evaluates the predicate against a value
    public func evaluate(_ value: T) -> Bool {
        expression.evaluate(value)
    }
    
    /// Converts to an NSPredicate string
    public func toPredicateString() -> String {
        expression.toPredicateString()
    }
    
    /// Converts to SQL WHERE clause
    public func toSQL() -> String {
        expression.toSQL()
    }
}

// MARK: - Predicate Expression

/// An expression in a predicate
public indirect enum PredicateExpression: Sendable {
    
    /// A literal boolean value
    case literal(Bool)
    
    /// A key path comparison
    case comparison(keyPath: String, op: ComparisonOperator, value: PredicateValue)
    
    /// A range check
    case range(keyPath: String, lower: PredicateValue, upper: PredicateValue)
    
    /// A membership check
    case `in`(keyPath: String, values: [PredicateValue])
    
    /// A null check
    case isNull(keyPath: String)
    
    /// A not-null check
    case isNotNull(keyPath: String)
    
    /// A string contains check
    case contains(keyPath: String, substring: String, caseInsensitive: Bool)
    
    /// A string starts with check
    case beginsWith(keyPath: String, prefix: String, caseInsensitive: Bool)
    
    /// A string ends with check
    case endsWith(keyPath: String, suffix: String, caseInsensitive: Bool)
    
    /// A string matches pattern
    case matches(keyPath: String, pattern: String)
    
    /// A LIKE pattern match
    case like(keyPath: String, pattern: String, caseInsensitive: Bool)
    
    /// Logical AND
    case and(PredicateExpression, PredicateExpression)
    
    /// Logical OR
    case or(PredicateExpression, PredicateExpression)
    
    /// Logical NOT
    case not(PredicateExpression)
    
    /// A subquery
    case subquery(collection: String, variable: String, predicate: PredicateExpression)
    
    /// Evaluates the expression
    public func evaluate(_ value: Any) -> Bool {
        switch self {
        case .literal(let bool):
            return bool
            
        case .comparison(let keyPath, let op, let compareValue):
            guard let actual = getValue(from: value, keyPath: keyPath) else { return false }
            return op.compare(actual, to: compareValue)
            
        case .range(let keyPath, let lower, let upper):
            guard let actual = getValue(from: value, keyPath: keyPath) else { return false }
            return ComparisonOperator.greaterThanOrEqual.compare(actual, to: lower) &&
                   ComparisonOperator.lessThanOrEqual.compare(actual, to: upper)
            
        case .in(let keyPath, let values):
            guard let actual = getValue(from: value, keyPath: keyPath) else { return false }
            return values.contains { ComparisonOperator.equal.compare(actual, to: $0) }
            
        case .isNull(let keyPath):
            return getValue(from: value, keyPath: keyPath) == nil
            
        case .isNotNull(let keyPath):
            return getValue(from: value, keyPath: keyPath) != nil
            
        case .contains(let keyPath, let substring, let caseInsensitive):
            guard let actual = getValue(from: value, keyPath: keyPath) as? String else { return false }
            if caseInsensitive {
                return actual.localizedCaseInsensitiveContains(substring)
            }
            return actual.contains(substring)
            
        case .beginsWith(let keyPath, let prefix, let caseInsensitive):
            guard let actual = getValue(from: value, keyPath: keyPath) as? String else { return false }
            if caseInsensitive {
                return actual.lowercased().hasPrefix(prefix.lowercased())
            }
            return actual.hasPrefix(prefix)
            
        case .endsWith(let keyPath, let suffix, let caseInsensitive):
            guard let actual = getValue(from: value, keyPath: keyPath) as? String else { return false }
            if caseInsensitive {
                return actual.lowercased().hasSuffix(suffix.lowercased())
            }
            return actual.hasSuffix(suffix)
            
        case .matches(let keyPath, let pattern):
            guard let actual = getValue(from: value, keyPath: keyPath) as? String else { return false }
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
            let range = NSRange(actual.startIndex..., in: actual)
            return regex.firstMatch(in: actual, range: range) != nil
            
        case .like(let keyPath, let pattern, let caseInsensitive):
            guard let actual = getValue(from: value, keyPath: keyPath) as? String else { return false }
            let regexPattern = pattern
                .replacingOccurrences(of: "%", with: ".*")
                .replacingOccurrences(of: "_", with: ".")
            let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
            guard let regex = try? NSRegularExpression(pattern: "^" + regexPattern + "$", options: options) else {
                return false
            }
            let range = NSRange(actual.startIndex..., in: actual)
            return regex.firstMatch(in: actual, range: range) != nil
            
        case .and(let left, let right):
            return left.evaluate(value) && right.evaluate(value)
            
        case .or(let left, let right):
            return left.evaluate(value) || right.evaluate(value)
            
        case .not(let expr):
            return !expr.evaluate(value)
            
        case .subquery:
            // Subqueries require collection access
            return false
        }
    }
    
    /// Converts to an NSPredicate format string
    public func toPredicateString() -> String {
        switch self {
        case .literal(let bool):
            return bool ? "TRUEPREDICATE" : "FALSEPREDICATE"
            
        case .comparison(let keyPath, let op, let value):
            return "\(keyPath) \(op.predicateSymbol) \(value.predicateString)"
            
        case .range(let keyPath, let lower, let upper):
            return "\(keyPath) BETWEEN {\(lower.predicateString), \(upper.predicateString)}"
            
        case .in(let keyPath, let values):
            let valueStrings = values.map { $0.predicateString }.joined(separator: ", ")
            return "\(keyPath) IN {\(valueStrings)}"
            
        case .isNull(let keyPath):
            return "\(keyPath) == nil"
            
        case .isNotNull(let keyPath):
            return "\(keyPath) != nil"
            
        case .contains(let keyPath, let substring, let caseInsensitive):
            let modifier = caseInsensitive ? "[c]" : ""
            return "\(keyPath) CONTAINS\(modifier) '\(substring)'"
            
        case .beginsWith(let keyPath, let prefix, let caseInsensitive):
            let modifier = caseInsensitive ? "[c]" : ""
            return "\(keyPath) BEGINSWITH\(modifier) '\(prefix)'"
            
        case .endsWith(let keyPath, let suffix, let caseInsensitive):
            let modifier = caseInsensitive ? "[c]" : ""
            return "\(keyPath) ENDSWITH\(modifier) '\(suffix)'"
            
        case .matches(let keyPath, let pattern):
            return "\(keyPath) MATCHES '\(pattern)'"
            
        case .like(let keyPath, let pattern, let caseInsensitive):
            let modifier = caseInsensitive ? "[c]" : ""
            return "\(keyPath) LIKE\(modifier) '\(pattern)'"
            
        case .and(let left, let right):
            return "(\(left.toPredicateString())) AND (\(right.toPredicateString()))"
            
        case .or(let left, let right):
            return "(\(left.toPredicateString())) OR (\(right.toPredicateString()))"
            
        case .not(let expr):
            return "NOT (\(expr.toPredicateString()))"
            
        case .subquery(let collection, let variable, let predicate):
            return "SUBQUERY(\(collection), $\(variable), \(predicate.toPredicateString())).@count > 0"
        }
    }
    
    /// Converts to SQL WHERE clause
    public func toSQL() -> String {
        switch self {
        case .literal(let bool):
            return bool ? "1=1" : "1=0"
            
        case .comparison(let keyPath, let op, let value):
            return "\"\(keyPath)\" \(op.sqlSymbol) \(value.sqlString)"
            
        case .range(let keyPath, let lower, let upper):
            return "\"\(keyPath)\" BETWEEN \(lower.sqlString) AND \(upper.sqlString)"
            
        case .in(let keyPath, let values):
            let valueStrings = values.map { $0.sqlString }.joined(separator: ", ")
            return "\"\(keyPath)\" IN (\(valueStrings))"
            
        case .isNull(let keyPath):
            return "\"\(keyPath)\" IS NULL"
            
        case .isNotNull(let keyPath):
            return "\"\(keyPath)\" IS NOT NULL"
            
        case .contains(let keyPath, let substring, let caseInsensitive):
            if caseInsensitive {
                return "LOWER(\"\(keyPath)\") LIKE '%\(substring.lowercased())%'"
            }
            return "\"\(keyPath)\" LIKE '%\(substring)%'"
            
        case .beginsWith(let keyPath, let prefix, let caseInsensitive):
            if caseInsensitive {
                return "LOWER(\"\(keyPath)\") LIKE '\(prefix.lowercased())%'"
            }
            return "\"\(keyPath)\" LIKE '\(prefix)%'"
            
        case .endsWith(let keyPath, let suffix, let caseInsensitive):
            if caseInsensitive {
                return "LOWER(\"\(keyPath)\") LIKE '%\(suffix.lowercased())'"
            }
            return "\"\(keyPath)\" LIKE '%\(suffix)'"
            
        case .matches(let keyPath, let pattern):
            return "\"\(keyPath)\" REGEXP '\(pattern)'"
            
        case .like(let keyPath, let pattern, let caseInsensitive):
            if caseInsensitive {
                return "LOWER(\"\(keyPath)\") LIKE '\(pattern.lowercased())'"
            }
            return "\"\(keyPath)\" LIKE '\(pattern)'"
            
        case .and(let left, let right):
            return "(\(left.toSQL())) AND (\(right.toSQL()))"
            
        case .or(let left, let right):
            return "(\(left.toSQL())) OR (\(right.toSQL()))"
            
        case .not(let expr):
            return "NOT (\(expr.toSQL()))"
            
        case .subquery(let collection, _, let predicate):
            return "EXISTS (SELECT 1 FROM \"\(collection)\" WHERE \(predicate.toSQL()))"
        }
    }
    
    private func getValue(from object: Any, keyPath: String) -> Any? {
        let parts = keyPath.split(separator: ".")
        var current: Any? = object
        
        for part in parts {
            guard let obj = current else { return nil }
            let mirror = Mirror(reflecting: obj)
            current = mirror.children.first { $0.label == String(part) }?.value
        }
        
        return current
    }
}

// MARK: - Comparison Operator

/// Comparison operators for predicates
public enum ComparisonOperator: String, Sendable, CaseIterable {
    case equal = "=="
    case notEqual = "!="
    case lessThan = "<"
    case lessThanOrEqual = "<="
    case greaterThan = ">"
    case greaterThanOrEqual = ">="
    
    /// The predicate format symbol
    public var predicateSymbol: String {
        rawValue
    }
    
    /// The SQL symbol
    public var sqlSymbol: String {
        switch self {
        case .equal: return "="
        case .notEqual: return "<>"
        default: return rawValue
        }
    }
    
    /// Compares two values
    public func compare(_ lhs: Any, to rhs: PredicateValue) -> Bool {
        switch self {
        case .equal:
            return isEqual(lhs, rhs)
        case .notEqual:
            return !isEqual(lhs, rhs)
        case .lessThan:
            return isLessThan(lhs, rhs)
        case .lessThanOrEqual:
            return isLessThan(lhs, rhs) || isEqual(lhs, rhs)
        case .greaterThan:
            return !isLessThan(lhs, rhs) && !isEqual(lhs, rhs)
        case .greaterThanOrEqual:
            return !isLessThan(lhs, rhs)
        }
    }
    
    private func isEqual(_ lhs: Any, _ rhs: PredicateValue) -> Bool {
        switch rhs {
        case .null:
            return lhs as AnyObject === NSNull()
        case .bool(let value):
            return (lhs as? Bool) == value
        case .int(let value):
            if let lhsInt = lhs as? Int { return lhsInt == value }
            if let lhsInt64 = lhs as? Int64 { return lhsInt64 == Int64(value) }
            return false
        case .double(let value):
            if let lhsDouble = lhs as? Double { return lhsDouble == value }
            if let lhsFloat = lhs as? Float { return Double(lhsFloat) == value }
            return false
        case .string(let value):
            return (lhs as? String) == value
        case .date(let value):
            return (lhs as? Date) == value
        case .data(let value):
            return (lhs as? Data) == value
        case .uuid(let value):
            return (lhs as? UUID) == value
        }
    }
    
    private func isLessThan(_ lhs: Any, _ rhs: PredicateValue) -> Bool {
        switch rhs {
        case .int(let value):
            if let lhsInt = lhs as? Int { return lhsInt < value }
            if let lhsInt64 = lhs as? Int64 { return lhsInt64 < Int64(value) }
            return false
        case .double(let value):
            if let lhsDouble = lhs as? Double { return lhsDouble < value }
            if let lhsFloat = lhs as? Float { return Double(lhsFloat) < value }
            return false
        case .string(let value):
            return (lhs as? String) ?? "" < value
        case .date(let value):
            return (lhs as? Date) ?? Date.distantPast < value
        default:
            return false
        }
    }
}

// MARK: - Predicate Value

/// A value in a predicate
public enum PredicateValue: Sendable, Hashable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case date(Date)
    case data(Data)
    case uuid(UUID)
    
    /// The NSPredicate format string
    public var predicateString: String {
        switch self {
        case .null: return "nil"
        case .bool(let value): return value ? "YES" : "NO"
        case .int(let value): return "\(value)"
        case .double(let value): return "\(value)"
        case .string(let value): return "'\(value.replacingOccurrences(of: "'", with: "\\'"))'"
        case .date(let value): return "CAST(\(value.timeIntervalSince1970), 'NSDate')"
        case .data(let value): return "'\(value.base64EncodedString())'"
        case .uuid(let value): return "'\(value.uuidString)'"
        }
    }
    
    /// The SQL string representation
    public var sqlString: String {
        switch self {
        case .null: return "NULL"
        case .bool(let value): return value ? "1" : "0"
        case .int(let value): return "\(value)"
        case .double(let value): return "\(value)"
        case .string(let value): return "'\(value.replacingOccurrences(of: "'", with: "''"))'"
        case .date(let value): return "\(value.timeIntervalSince1970)"
        case .data(let value): return "X'\(value.map { String(format: "%02X", $0) }.joined())'"
        case .uuid(let value): return "'\(value.uuidString)'"
        }
    }
}

// MARK: - Predicate Builder

/// Builds predicates using a fluent API
public struct PredicateBuilder<T>: Sendable {
    
    /// The current expression
    private var expression: PredicateExpression?
    
    /// Creates a new predicate builder
    public init() {}
    
    /// Builds the predicate
    public func build() -> Predicate<T> {
        Predicate(expression ?? .literal(true))
    }
    
    /// Adds an equality condition
    public func `where`(_ keyPath: String, equals value: PredicateValue) -> PredicateBuilder<T> {
        addCondition(.comparison(keyPath: keyPath, op: .equal, value: value))
    }
    
    /// Adds a not-equal condition
    public func `where`(_ keyPath: String, notEquals value: PredicateValue) -> PredicateBuilder<T> {
        addCondition(.comparison(keyPath: keyPath, op: .notEqual, value: value))
    }
    
    /// Adds a less-than condition
    public func `where`(_ keyPath: String, lessThan value: PredicateValue) -> PredicateBuilder<T> {
        addCondition(.comparison(keyPath: keyPath, op: .lessThan, value: value))
    }
    
    /// Adds a less-than-or-equal condition
    public func `where`(_ keyPath: String, lessThanOrEqual value: PredicateValue) -> PredicateBuilder<T> {
        addCondition(.comparison(keyPath: keyPath, op: .lessThanOrEqual, value: value))
    }
    
    /// Adds a greater-than condition
    public func `where`(_ keyPath: String, greaterThan value: PredicateValue) -> PredicateBuilder<T> {
        addCondition(.comparison(keyPath: keyPath, op: .greaterThan, value: value))
    }
    
    /// Adds a greater-than-or-equal condition
    public func `where`(_ keyPath: String, greaterThanOrEqual value: PredicateValue) -> PredicateBuilder<T> {
        addCondition(.comparison(keyPath: keyPath, op: .greaterThanOrEqual, value: value))
    }
    
    /// Adds a between condition
    public func `where`(_ keyPath: String, between lower: PredicateValue, and upper: PredicateValue) -> PredicateBuilder<T> {
        addCondition(.range(keyPath: keyPath, lower: lower, upper: upper))
    }
    
    /// Adds an IN condition
    public func `where`(_ keyPath: String, in values: [PredicateValue]) -> PredicateBuilder<T> {
        addCondition(.in(keyPath: keyPath, values: values))
    }
    
    /// Adds an is-null condition
    public func whereNull(_ keyPath: String) -> PredicateBuilder<T> {
        addCondition(.isNull(keyPath: keyPath))
    }
    
    /// Adds an is-not-null condition
    public func whereNotNull(_ keyPath: String) -> PredicateBuilder<T> {
        addCondition(.isNotNull(keyPath: keyPath))
    }
    
    /// Adds a contains condition
    public func `where`(_ keyPath: String, contains substring: String, caseInsensitive: Bool = false) -> PredicateBuilder<T> {
        addCondition(.contains(keyPath: keyPath, substring: substring, caseInsensitive: caseInsensitive))
    }
    
    /// Adds a begins-with condition
    public func `where`(_ keyPath: String, beginsWith prefix: String, caseInsensitive: Bool = false) -> PredicateBuilder<T> {
        addCondition(.beginsWith(keyPath: keyPath, prefix: prefix, caseInsensitive: caseInsensitive))
    }
    
    /// Adds an ends-with condition
    public func `where`(_ keyPath: String, endsWith suffix: String, caseInsensitive: Bool = false) -> PredicateBuilder<T> {
        addCondition(.endsWith(keyPath: keyPath, suffix: suffix, caseInsensitive: caseInsensitive))
    }
    
    /// Adds a matches condition
    public func `where`(_ keyPath: String, matches pattern: String) -> PredicateBuilder<T> {
        addCondition(.matches(keyPath: keyPath, pattern: pattern))
    }
    
    /// Adds a LIKE condition
    public func `where`(_ keyPath: String, like pattern: String, caseInsensitive: Bool = false) -> PredicateBuilder<T> {
        addCondition(.like(keyPath: keyPath, pattern: pattern, caseInsensitive: caseInsensitive))
    }
    
    /// Starts an OR group
    public func or(_ builder: (PredicateBuilder<T>) -> PredicateBuilder<T>) -> PredicateBuilder<T> {
        let inner = builder(PredicateBuilder<T>())
        guard let innerExpr = inner.expression else { return self }
        
        var result = self
        if let existing = result.expression {
            result.expression = .or(existing, innerExpr)
        } else {
            result.expression = innerExpr
        }
        return result
    }
    
    /// Negates the current expression
    public func not() -> PredicateBuilder<T> {
        var result = self
        if let existing = result.expression {
            result.expression = .not(existing)
        }
        return result
    }
    
    private func addCondition(_ newExpr: PredicateExpression) -> PredicateBuilder<T> {
        var result = self
        if let existing = result.expression {
            result.expression = .and(existing, newExpr)
        } else {
            result.expression = newExpr
        }
        return result
    }
}

// MARK: - KeyPath Extensions

/// A key path reference for predicates
public struct KeyPathRef<Root, Value>: Sendable {
    public let path: String
    
    public init(_ path: String) {
        self.path = path
    }
}

// MARK: - Predicate DSL

/// DSL for building predicates
@resultBuilder
public struct PredicateDSL<T> {
    
    public static func buildBlock(_ components: PredicateExpression...) -> PredicateExpression {
        components.dropFirst().reduce(components.first ?? .literal(true)) { .and($0, $1) }
    }
    
    public static func buildOptional(_ component: PredicateExpression?) -> PredicateExpression {
        component ?? .literal(true)
    }
    
    public static func buildEither(first component: PredicateExpression) -> PredicateExpression {
        component
    }
    
    public static func buildEither(second component: PredicateExpression) -> PredicateExpression {
        component
    }
    
    public static func buildArray(_ components: [PredicateExpression]) -> PredicateExpression {
        components.dropFirst().reduce(components.first ?? .literal(true)) { .and($0, $1) }
    }
}

// MARK: - Convenience Functions

/// Creates an equality expression
public func equals(_ keyPath: String, _ value: PredicateValue) -> PredicateExpression {
    .comparison(keyPath: keyPath, op: .equal, value: value)
}

/// Creates a not-equal expression
public func notEquals(_ keyPath: String, _ value: PredicateValue) -> PredicateExpression {
    .comparison(keyPath: keyPath, op: .notEqual, value: value)
}

/// Creates a less-than expression
public func lessThan(_ keyPath: String, _ value: PredicateValue) -> PredicateExpression {
    .comparison(keyPath: keyPath, op: .lessThan, value: value)
}

/// Creates a greater-than expression
public func greaterThan(_ keyPath: String, _ value: PredicateValue) -> PredicateExpression {
    .comparison(keyPath: keyPath, op: .greaterThan, value: value)
}

/// Creates a contains expression
public func contains(_ keyPath: String, _ substring: String, caseInsensitive: Bool = false) -> PredicateExpression {
    .contains(keyPath: keyPath, substring: substring, caseInsensitive: caseInsensitive)
}

/// Creates an is-null expression
public func isNull(_ keyPath: String) -> PredicateExpression {
    .isNull(keyPath: keyPath)
}

/// Creates an is-not-null expression
public func isNotNull(_ keyPath: String) -> PredicateExpression {
    .isNotNull(keyPath: keyPath)
}

/// Creates a between expression
public func between(_ keyPath: String, _ lower: PredicateValue, _ upper: PredicateValue) -> PredicateExpression {
    .range(keyPath: keyPath, lower: lower, upper: upper)
}

/// Creates an IN expression
public func `in`(_ keyPath: String, _ values: [PredicateValue]) -> PredicateExpression {
    .in(keyPath: keyPath, values: values)
}
