import Foundation

/// A file-system-backed store for persisting `Data` blobs.
///
/// `FileStore` writes data to the app's documents directory (or a custom
/// base URL) and provides simple read, write, delete, and list operations.
///
/// ```swift
/// let store = FileStore()
/// try store.write(imageData, toFile: "avatar.png")
/// let data = try store.read(fromFile: "avatar.png")
/// ```
public final class FileStore: @unchecked Sendable {

    // MARK: - Properties

    private let baseURL: URL
    private let fileManager: FileManager

    // MARK: - Initialisation

    /// Creates a file store rooted at the given directory.
    ///
    /// - Parameters:
    ///   - baseURL: The root directory. Defaults to the documents directory.
    ///   - fileManager: The file manager to use.
    public init(
        baseURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        if let baseURL {
            self.baseURL = baseURL
        } else {
            self.baseURL = fileManager.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        }
        ensureDirectoryExists()
    }

    // MARK: - Write

    /// Writes data to a file.
    ///
    /// - Parameters:
    ///   - data: The data to write.
    ///   - name: The file name (may include subdirectory components).
    /// - Throws: ``PersistenceError/fileSystemError(path:underlying:)`` on failure.
    public func write(_ data: Data, toFile name: String) throws {
        let url = fileURL(for: name)
        let directory = url.deletingLastPathComponent()

        do {
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            try data.write(to: url, options: .atomic)
        } catch {
            throw PersistenceError.fileSystemError(path: url.path, underlying: error)
        }
    }

    // MARK: - Read

    /// Reads data from a file.
    ///
    /// - Parameter name: The file name.
    /// - Returns: The file contents.
    /// - Throws: ``PersistenceError/notFound(key:)`` if the file is missing,
    ///           ``PersistenceError/fileSystemError(path:underlying:)`` on read failure.
    public func read(fromFile name: String) throws -> Data {
        let url = fileURL(for: name)

        guard fileManager.fileExists(atPath: url.path) else {
            throw PersistenceError.notFound(key: name)
        }

        do {
            return try Data(contentsOf: url)
        } catch {
            throw PersistenceError.fileSystemError(path: url.path, underlying: error)
        }
    }

    // MARK: - Delete

    /// Deletes a file.
    ///
    /// - Parameter name: The file name.
    /// - Throws: ``PersistenceError/fileSystemError(path:underlying:)`` on failure.
    public func delete(file name: String) throws {
        let url = fileURL(for: name)

        guard fileManager.fileExists(atPath: url.path) else { return }

        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw PersistenceError.fileSystemError(path: url.path, underlying: error)
        }
    }

    /// Deletes all files in the store directory.
    ///
    /// - Throws: ``PersistenceError/fileSystemError(path:underlying:)`` on failure.
    public func deleteAll() throws {
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: baseURL,
                includingPropertiesForKeys: nil
            )
            for url in contents {
                try fileManager.removeItem(at: url)
            }
        } catch {
            throw PersistenceError.fileSystemError(path: baseURL.path, underlying: error)
        }
    }

    // MARK: - Query

    /// Returns `true` if the file exists.
    ///
    /// - Parameter name: The file name.
    public func fileExists(name: String) -> Bool {
        fileManager.fileExists(atPath: fileURL(for: name).path)
    }

    /// Lists all file names in the store directory.
    ///
    /// - Returns: An array of file names.
    public func listFiles() throws -> [String] {
        do {
            return try fileManager.contentsOfDirectory(atPath: baseURL.path)
        } catch {
            throw PersistenceError.fileSystemError(path: baseURL.path, underlying: error)
        }
    }

    // MARK: - Private

    private func fileURL(for name: String) -> URL {
        baseURL.appendingPathComponent(name)
    }

    private func ensureDirectoryExists() {
        if !fileManager.fileExists(atPath: baseURL.path) {
            try? fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        }
    }
}
