import Foundation

/// SwiftPersistence: Framework-Agnostic Repository
public protocol AgnosticRepository: Sendable {
    associatedtype Model
    func save(_ item: Model) async throws
}
