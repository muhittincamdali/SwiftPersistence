<div align="center">

# 💿 SwiftPersistence

**Unified data persistence - SwiftData, CoreData, UserDefaults & Keychain in one API**

[![Swift](https://img.shields.io/badge/Swift-5.9+-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-15.0+-000000?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![SPM](https://img.shields.io/badge/SPM-Compatible-FA7343?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org/package-manager/)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

[Features](#-features) • [Installation](#-installation) • [Quick Start](#-quick-start)

</div>

---

## ✨ Features

- 🗄️ **Unified API** — One interface for all storage types
- 📊 **SwiftData** — Modern iOS 17+ support
- 💾 **CoreData** — Legacy project support
- 🔐 **Keychain** — Secure credential storage
- ⚙️ **UserDefaults** — Preferences made easy
- 🔄 **Migration** — Seamless data migration tools

---

## 📦 Installation

```swift
dependencies: [
    .package(url: "https://github.com/muhittincamdali/SwiftPersistence.git", from: "1.0.0")
]
```

---

## 🚀 Quick Start

```swift
import SwiftPersistence

// UserDefaults
@Persisted("username") var username: String?

// Keychain
@SecureStore("api_token") var token: String?

// SwiftData
let store = PersistenceStore<User>()
try await store.save(user)
let users = try await store.fetchAll()
```

---

## 📄 License

MIT License - see [LICENSE](LICENSE)

## 👨‍💻 Author

**Muhittin Camdali** • [@muhittincamdali](https://github.com/muhittincamdali)
