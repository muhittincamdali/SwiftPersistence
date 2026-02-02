# SwiftPersistence

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2015%20|%20macOS%2012%20|%20tvOS%2015%20|%20watchOS%208-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![SPM](https://img.shields.io/badge/SPM-Compatible-brightgreen.svg)](https://swift.org/package-manager)

A unified persistence layer for Swift apps. One API for UserDefaults, Keychain, CoreData, SwiftData, file system, and iCloud sync.

---

## Why SwiftPersistence?

Apple offers multiple persistence frameworks, each with different APIs and trade-offs. Switching between them means rewriting boilerplate, handling encoding/decoding in multiple places, and scattering storage logic across your codebase.

**SwiftPersistence** solves this with:

- **One unified `PersistenceManager`** that routes to the right backend
- **Type-safe property wrappers** (`@Persisted`, `@SecurePersisted`)
- **Consistent error handling** via `PersistenceError`
- **Zero third-party dependencies** — only Apple frameworks

---

## Features

| Feature | Description |
|---------|-------------|
| 🗂 **UserDefaults** | Type-safe access with `DefaultsKey<T>` |
| 🔐 **Keychain** | Secure storage with configurable accessibility |
| 📁 **File System** | Read/write/delete files with atomic operations |
| 🏗 **CoreData** | Simplified wrapper with fetch, insert, delete |
| 📊 **SwiftData** | Generic CRUD for `PersistentModel` types |
| ☁️ **iCloud Sync** | Key-value sync via `NSUbiquitousKeyValueStore` |
| 🏷 **Property Wrappers** | `@Persisted` and `@SecurePersisted` |
| 🔄 **Migration** | Step-based schema migration for SwiftData |
| 📡 **Events** | Combine publisher for persistence operations |

---

## Requirements

| Platform | Minimum Version |
|----------|----------------|
| iOS | 15.0 |
| macOS | 12.0 |
| tvOS | 15.0 |
| watchOS | 8.0 |
| Swift | 5.9 |

> **Note:** SwiftData features require iOS 17+ / macOS 14+.

---

## Installation

### Swift Package Manager

Add SwiftPersistence to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/muhittincamdali/SwiftPersistence.git", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies** and paste the repository URL.

---

## Quick Start

### Unified Manager

```swift
import SwiftPersistence

let manager = PersistenceManager.shared

// Save to UserDefaults
try manager.save("dark", forKey: "theme", in: .userDefaults)

// Save to Keychain
try manager.save("secret_token", forKey: "auth", in: .keychain)

// Save to file system
try manager.save(userProfile, forKey: "profile.json", in: .fileSystem)

// Load from any backend
let theme: String = try manager.load(forKey: "theme", from: .userDefaults)
let token: String = try manager.load(forKey: "auth", from: .keychain)

// Check existence
if manager.exists(forKey: "theme", in: .userDefaults) {
    print("Theme is set")
}

// Remove
try manager.remove(forKey: "auth", from: .keychain)
```

### Property Wrappers

```swift
struct Settings {
    @Persisted(key: "username", defaultValue: "Guest")
    var username: String

    @Persisted(key: "launch_count", defaultValue: 0)
    var launchCount: Int

    @SecurePersisted(key: "api_key")
    var apiKey: String?
}

var settings = Settings()
settings.username = "Alice"
settings.apiKey = "sk-abc123"
print(settings.username)  // "Alice"
```

### UserDefaults Store

```swift
let store = DefaultsStore()

// Type-safe keys
let themeKey = DefaultsKey<String>("theme")
let countKey = DefaultsKey<Int>("launch_count")

try store.set("dark", forKey: themeKey)
try store.set(42, forKey: countKey)

let theme = try store.get(forKey: themeKey)  // "dark"
let count = try store.get(forKey: countKey)  // 42

store.remove(forKey: themeKey)
```

### Keychain Store

```swift
let keychain = KeychainStore()

// Store sensitive data
let tokenData = "secret".data(using: .utf8)!
try keychain.save(tokenData, forKey: "auth_token")

// Retrieve
let data = try keychain.load(forKey: "auth_token")

// Check existence
if keychain.exists(forKey: "auth_token") {
    print("Token available")
}

// Custom configuration
let config = KeychainConfiguration(
    service: "com.myapp.auth",
    accessibility: .whenUnlocked
)
let secureKeychain = KeychainStore(configuration: config)
```

### File Store

```swift
let fileStore = FileStore()

// Write data
let imageData = try Data(contentsOf: imageURL)
try fileStore.write(imageData, toFile: "avatar.png")

// Read data
let loaded = try fileStore.read(fromFile: "avatar.png")

// List files
let files = try fileStore.listFiles()

// Clean up
try fileStore.delete(file: "avatar.png")
```

### CoreData Store

```swift
let coreData = CoreDataStore(modelName: "MyApp")
try coreData.loadPersistentStores()

// Insert
let user = coreData.insert(entityName: "User")
user.setValue("Alice", forKey: "name")
try coreData.save()

// Fetch
let users = try coreData.fetch(entityName: "User")

// Delete
coreData.delete(user)
try coreData.save()
```

### SwiftData Store (iOS 17+)

```swift
import SwiftData

@Model
class Task {
    var title: String
    var isComplete: Bool

    init(title: String, isComplete: Bool = false) {
        self.title = title
        self.isComplete = isComplete
    }
}

let store = try SwiftDataStore(for: Task.self)

// Insert
await store.insert(Task(title: "Ship v1.0"))
try await store.save()

// Fetch
let tasks: [Task] = try await store.fetchAll()

// Filtered fetch
let pending: [Task] = try await store.fetchAll(
    predicate: #Predicate { !$0.isComplete }
)
```

### iCloud Sync

```swift
let sync = CloudSyncEngine()
sync.startObserving()

// Write to iCloud
sync.set("dark", forKey: "theme")
sync.set(true, forKey: "premium")

// Read from iCloud
let theme = sync.string(forKey: "theme")

// Observe remote changes
let cancellable = sync.changes.sink { change in
    print("Changed keys: \(change.changedKeys)")
    print("Reason: \(change.reason)")
}
```

### Observe Events

```swift
let manager = PersistenceManager.shared

let cancellable = manager.events.sink { event in
    switch event {
    case .saved(let key, let backend):
        print("Saved \(key) to \(backend)")
    case .loaded(let key, let backend):
        print("Loaded \(key) from \(backend)")
    case .removed(let key, let backend):
        print("Removed \(key) from \(backend)")
    case .error(let error):
        print("Error: \(error.localizedDescription)")
    }
}
```

---

## Architecture

```
┌─────────────────────────────────────┐
│         PersistenceManager          │
│         (Unified Facade)            │
├──────┬──────┬──────┬──────┬─────────┤
│ User │ Key  │ File │ Core │ Swift   │
│ Defs │chain │ Sys  │ Data │ Data    │
├──────┴──────┴──────┴──────┴─────────┤
│         CloudSyncEngine             │
│         (iCloud KVS)                │
└─────────────────────────────────────┘
```

Each store is independent and can be used standalone or through the manager.

---

## Error Handling

All operations throw `PersistenceError`, a unified error type:

```swift
do {
    let value: String = try manager.load(forKey: "missing", from: .keychain)
} catch PersistenceError.notFound(let key) {
    print("No value for \(key)")
} catch PersistenceError.keychainError(let status) {
    print("Keychain status: \(status)")
} catch PersistenceError.decodingFailed(let error) {
    print("Decode error: \(error)")
}
```

---

## Thread Safety

- `KeychainStore`, `PersistenceManager`, `CloudSyncEngine`, and `FileStore` are thread-safe with internal locking.
- `CoreDataStore` uses `viewContext` (main queue). Use `performBackgroundTask` for background work.
- `SwiftDataStore` operations annotated with `@MainActor` where required.

---

## Migration (SwiftData)

```swift
let plan = ModelMigrationPlan(currentVersion: "v1")

plan.addStep(MigrationStep(
    sourceVersion: "v1",
    targetVersion: "v2",
    migrate: {
        // transform data between schema versions
    }
))

try plan.execute(from: "v1", to: "v2")
```

---

## License

SwiftPersistence is released under the [MIT License](LICENSE).

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/awesome`)
3. Commit your changes (`git commit -m 'feat: add awesome feature'`)
4. Push to the branch (`git push origin feature/awesome`)
5. Open a Pull Request

---

## Author

**Muhittin Camdali** — [@muhittincamdali](https://github.com/muhittincamdali)
