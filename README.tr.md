<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOS-Offline-First-Framework/master/.github/brand/banner-tr-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOS-Offline-First-Framework/master/.github/brand/banner-tr-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOS-Offline-First-Framework/master/.github/brand/banner-tr-light.svg" alt="Offline-First Framework: Swift uygulamaları için çevrimdışı çalışmayı sürdüren ve sunucunuzla eşitlenen yerel bir veri deposu."></picture></p>

<p align="center"><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a></p>

# SwiftPersistence taşındı

Bu proje artık [iOS-Offline-First-Framework](https://github.com/muhittincamdali/iOS-Offline-First-Framework) içinde yaşıyor. Bu depo arşivlendi ve artık değişiklik almıyor.

Dosya deposu, Keychain deposu, kayıt migration'ları ile retry politikası ve circuit breaker orada Swift 6 için, testlerle yeniden yazıldı; yerel değişiklikleri kuyruğa alıp sunucunuzla eşitleyen bir çevrimdışı deponun içinde yer alıyor. Bu depodaki her şey taşınmadı: SwiftData ve Core Data üzerindeki repository soyutlaması, event bus, metrics collector ve error handler yeni pakette karşılığı olmayan parçalar. [Changelog](https://github.com/muhittincamdali/iOS-Offline-First-Framework/blob/master/CHANGELOG.md) nelerin birleştirildiğini listeliyor.

- Depolama: [Sources/OfflineFirstFramework/Storage](https://github.com/muhittincamdali/iOS-Offline-First-Framework/tree/master/Sources/OfflineFirstFramework/Storage)
- Eşitleme, retry ve circuit breaker: [Sources/OfflineFirstFramework/Sync](https://github.com/muhittincamdali/iOS-Offline-First-Framework/tree/master/Sources/OfflineFirstFramework/Sync)
- Dokümantasyon: [OfflineFirstFramework](https://muhittincamdali.github.io/iOS-Offline-First-Framework/documentation/offlinefirstframework/)

## Yeni paketi kurun

Yeni paket iOS 17+, macOS 14+, tvOS 17+, watchOS 10+ veya visionOS 1+ gerektirir.

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

İki paket arasında public tipler değişti; geçiş import'ları ve çağrı yerlerini yeniden adlandırmayı gerektirir. Eski kod referans için burada olduğu gibi duruyor.
