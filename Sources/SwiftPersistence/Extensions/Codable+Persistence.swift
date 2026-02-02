import Foundation

// MARK: - Codable Persistence Helpers

public extension Encodable {

    /// Encodes the value to JSON `Data`.
    ///
    /// - Parameter encoder: The encoder to use. Defaults to a standard `JSONEncoder`.
    /// - Returns: The JSON-encoded data.
    /// - Throws: ``PersistenceError/encodingFailed(underlying:)`` on failure.
    func persistenceData(using encoder: JSONEncoder = JSONEncoder()) throws -> Data {
        do {
            return try encoder.encode(self)
        } catch {
            throw PersistenceError.encodingFailed(underlying: error)
        }
    }

    /// Encodes the value to a JSON string.
    ///
    /// - Parameter encoder: The encoder to use.
    /// - Returns: The JSON string representation.
    /// - Throws: ``PersistenceError/encodingFailed(underlying:)`` on failure.
    func persistenceJSONString(using encoder: JSONEncoder = JSONEncoder()) throws -> String {
        let data = try persistenceData(using: encoder)
        guard let string = String(data: data, encoding: .utf8) else {
            throw PersistenceError.encodingFailed(
                underlying: NSError(
                    domain: "SwiftPersistence",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "UTF-8 encoding failed"]
                )
            )
        }
        return string
    }
}

public extension Decodable {

    /// Decodes an instance from JSON `Data`.
    ///
    /// - Parameters:
    ///   - data: The JSON data.
    ///   - decoder: The decoder to use. Defaults to a standard `JSONDecoder`.
    /// - Returns: The decoded instance.
    /// - Throws: ``PersistenceError/decodingFailed(underlying:)`` on failure.
    static func fromPersistenceData(
        _ data: Data,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> Self {
        do {
            return try decoder.decode(Self.self, from: data)
        } catch {
            throw PersistenceError.decodingFailed(underlying: error)
        }
    }
}
