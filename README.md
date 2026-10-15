<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOS-Offline-First-Framework/master/.github/brand/banner-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOS-Offline-First-Framework/master/.github/brand/banner-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOS-Offline-First-Framework/master/.github/brand/banner-light.svg" alt="Offline-First Framework: A local store for Swift apps that keeps working offline and syncs with your server."></picture></p>

<p align="center"><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a></p>

# SwiftPersistence has moved

This project now lives in [iOS-Offline-First-Framework](https://github.com/muhittincamdali/iOS-Offline-First-Framework). This repository is archived and no longer receives changes.

The file store, the Keychain store, record migrations, and the retry policy and circuit breaker were rewritten there for Swift 6, with tests, and sit inside an offline store that queues local changes and syncs them with your server. Not everything from this repository was carried over: the repository abstraction over SwiftData and Core Data, the event bus, the metrics collector and the error handler have no counterpart in the new package. The [changelog](https://github.com/muhittincamdali/iOS-Offline-First-Framework/blob/master/CHANGELOG.md) lists what was merged.

- Storage: [Sources/OfflineFirstFramework/Storage](https://github.com/muhittincamdali/iOS-Offline-First-Framework/tree/master/Sources/OfflineFirstFramework/Storage)
- Sync, retry and circuit breaker: [Sources/OfflineFirstFramework/Sync](https://github.com/muhittincamdali/iOS-Offline-First-Framework/tree/master/Sources/OfflineFirstFramework/Sync)
- Documentation: [OfflineFirstFramework](https://muhittincamdali.github.io/iOS-Offline-First-Framework/documentation/offlinefirstframework/)

## Install the new package

The new package needs iOS 17+, macOS 14+, tvOS 17+, watchOS 10+ or visionOS 1+.

```swift
dependencies: [
    .package(url: "https://github.com/muhittincamdali/iOS-Offline-First-Framework.git", from: "2.0.0")
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "OfflineFirstFramework", package: "iOS-Offline-First-Framework")
    ])
]
```

The public types changed between the two packages, so moving over means renaming imports and call sites. The old code stays here, unchanged, for reference.
