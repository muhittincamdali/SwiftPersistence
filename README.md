<h1 align="center">SwiftPersistence</h1>

<p align="center">
  <strong>💿 Unified data persistence - SwiftData, CoreData, UserDefaults & Keychain in one API</strong>
</p>

<p align="center">
  <a href="https://github.com/muhittincamdali/SwiftPersistence/actions/workflows/ci.yml">
    <img src="https://github.com/muhittincamdali/SwiftPersistence/actions/workflows/ci.yml/badge.svg" alt="CI"/>
  </a>
  <img src="https://img.shields.io/badge/Swift-6.0-orange.svg" alt="Swift 6.0"/>
  <img src="https://img.shields.io/badge/iOS-17.0+-blue.svg" alt="iOS 17.0+"/>
</p>

---

## Why SwiftPersistence?

iOS has many storage options - SwiftData, CoreData, UserDefaults, Keychain, File System. Each has different APIs. **SwiftPersistence** provides a unified interface for all of them.

```swift
// One API for all storage
let store = Store<User>(backend: .swiftData)
try await store.save(user)
let users = try await store.fetch()

// Easy switching
let store = Store<User>(backend: .coreData) // Same API!
let store = Store<User>(backend: .fileSystem)
```

## Features

| Feature | Description |
|---------|-------------|
| 🔄 **Unified API** | Same interface for all backends |
| 💾 **SwiftData** | iOS 17+ native |
| 📦 **CoreData** | Legacy support |
| ⚙️ **UserDefaults** | Simple key-value |
| 🔐 **Keychain** | Secure storage |
| 📁 **FileSystem** | JSON/Plist files |
| 🔍 **Queries** | Type-safe predicates |

## Quick Start

```swift
import SwiftPersistence

// Define model
@Persistable
struct User: Identifiable {
    let id: UUID
    var name: String
    var email: String
}

// Create store
let store = Store<User>()

// CRUD operations
try await store.save(user)
let users = try await store.fetch()
let user = try await store.find(id: userId)
try await store.delete(user)
```

## Backends

### SwiftData (Default)

```swift
let store = Store<User>(backend: .swiftData)
```

### CoreData

```swift
let store = Store<User>(backend: .coreData(
    modelName: "MyApp",
    inMemory: false
))
```

### UserDefaults

```swift
let store = Store<Settings>(backend: .userDefaults(
    suiteName: "group.myapp"
))
```

### Keychain

```swift
let store = Store<Credentials>(backend: .keychain(
    accessGroup: "com.myapp.shared",
    accessibility: .afterFirstUnlock
))
```

### File System

```swift
let store = Store<Document>(backend: .fileSystem(
    directory: .documents,
    format: .json
))
```

## Querying

```swift
// Fetch with predicate
let adults = try await store.fetch(
    where: \.age >= 18,
    sortedBy: \.name
)

// Complex queries
let results = try await store.fetch {
    $0.where(\.isActive == true)
    $0.where(\.role == .admin)
    $0.sortBy(\.createdAt, .descending)
    $0.limit(10)
}
```

## Relationships

```swift
@Persistable
struct Post {
    let id: UUID
    var title: String
    @Relationship var author: User
    @Relationship var comments: [Comment]
}
```

## Migrations

```swift
Store<User>.migrate { migration in
    migration.add(\.newField, defaultValue: "")
    migration.rename(\.oldName, to: \.newName)
    migration.delete(\.deprecatedField)
}
```

## Testing

```swift
// In-memory store for tests
let testStore = Store<User>(backend: .inMemory)
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT License

---

## 📈 Star History

<a href="https://star-history.com/#muhittincamdali/SwiftPersistence&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=muhittincamdali/SwiftPersistence&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=muhittincamdali/SwiftPersistence&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=muhittincamdali/SwiftPersistence&type=Date" />
 </picture>
</a>
