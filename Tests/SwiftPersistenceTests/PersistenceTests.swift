import XCTest
@testable import SwiftPersistence

final class PersistenceTests: XCTestCase {

    // MARK: - DefaultsStore Tests

    func testDefaultsStoreSetAndGet() throws {
        let suite = UserDefaults(suiteName: "TestSuite")!
        let store = DefaultsStore(suite: suite)
        let key = DefaultsKey<String>("test_name")

        try store.set("Alice", forKey: key)
        let value = try store.get(forKey: key)

        XCTAssertEqual(value, "Alice")
        suite.removePersistentDomain(forName: "TestSuite")
    }

    func testDefaultsStoreContains() throws {
        let suite = UserDefaults(suiteName: "TestContains")!
        let store = DefaultsStore(suite: suite)
        let key = DefaultsKey<Int>("counter")

        XCTAssertFalse(store.contains(key: "counter"))

        try store.set(42, forKey: key)
        XCTAssertTrue(store.contains(key: "counter"))

        suite.removePersistentDomain(forName: "TestContains")
    }

    func testDefaultsStoreRemove() throws {
        let suite = UserDefaults(suiteName: "TestRemove")!
        let store = DefaultsStore(suite: suite)
        let key = DefaultsKey<String>("removable")

        try store.set("value", forKey: key)
        XCTAssertTrue(store.contains(key: "removable"))

        store.remove(forKey: key)
        XCTAssertFalse(store.contains(key: "removable"))

        suite.removePersistentDomain(forName: "TestRemove")
    }

    // MARK: - FileStore Tests

    func testFileStoreWriteAndRead() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let store = FileStore(baseURL: tempDir)

        let data = "Hello, World!".data(using: .utf8)!
        try store.write(data, toFile: "greeting.txt")

        let loaded = try store.read(fromFile: "greeting.txt")
        XCTAssertEqual(loaded, data)

        try store.deleteAll()
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testFileStoreFileExists() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let store = FileStore(baseURL: tempDir)

        XCTAssertFalse(store.fileExists(name: "missing.txt"))

        try store.write(Data(), toFile: "exists.txt")
        XCTAssertTrue(store.fileExists(name: "exists.txt"))

        try store.deleteAll()
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testFileStoreDeleteFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let store = FileStore(baseURL: tempDir)

        try store.write(Data([0x01]), toFile: "temp.bin")
        XCTAssertTrue(store.fileExists(name: "temp.bin"))

        try store.delete(file: "temp.bin")
        XCTAssertFalse(store.fileExists(name: "temp.bin"))

        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Codable Extension Tests

    func testCodableRoundTrip() throws {
        struct Payload: Codable, Equatable {
            let name: String
            let score: Int
        }

        let original = Payload(name: "Test", score: 100)
        let data = try original.persistenceData()
        let decoded = try Payload.fromPersistenceData(data)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - PersistenceError Tests

    func testErrorDescriptions() {
        let error = PersistenceError.notFound(key: "missing")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("missing"))

        let keychainError = PersistenceError.keychainError(status: -25300)
        XCTAssertNotNil(keychainError.errorDescription)
    }

    // MARK: - DefaultsKey Tests

    func testDefaultsKeyStringLiteral() {
        let key: DefaultsKey<String> = "my_key"
        XCTAssertEqual(key.rawValue, "my_key")
    }

    func testDefaultsKeyDescription() {
        let key = DefaultsKey<Int>("count")
        XCTAssertTrue(key.description.contains("count"))
    }
}
