//
//  PersistenceView.swift
//  SwiftPersistence
//
//  Created by Muhittin Camdali on 2025.
//  MIT License
//

#if canImport(SwiftUI)
import SwiftUI
import Combine

// MARK: - Persistence View

/// A SwiftUI view that displays and manages persisted data
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct PersistenceView<T: Storable & Identifiable, Content: View>: View {
    
    /// The view model
    @StateObject private var viewModel: PersistenceViewModel<T>
    
    /// The content builder
    private let content: (PersistenceViewState<T>) -> Content
    
    /// Creates a new persistence view
    public init(
        store: PersistenceStore,
        @ViewBuilder content: @escaping (PersistenceViewState<T>) -> Content
    ) {
        self._viewModel = StateObject(wrappedValue: PersistenceViewModel<T>(store: store))
        self.content = content
    }
    
    public var body: some View {
        content(viewModel.state)
            .task {
                await viewModel.loadData()
            }
    }
}

// MARK: - Persistence View State

/// State for a persistence view
public struct PersistenceViewState<T: Storable & Identifiable>: Sendable {
    
    /// The loaded items
    public let items: [T]
    
    /// Whether data is loading
    public let isLoading: Bool
    
    /// Any error that occurred
    public let error: Error?
    
    /// Whether there's an error
    public var hasError: Bool {
        error != nil
    }
    
    /// Whether items are empty
    public var isEmpty: Bool {
        items.isEmpty && !isLoading
    }
    
    /// Initial state
    public static var initial: PersistenceViewState<T> {
        PersistenceViewState(items: [], isLoading: true, error: nil)
    }
    
    /// Creates a new state
    public init(items: [T], isLoading: Bool, error: Error?) {
        self.items = items
        self.isLoading = isLoading
        self.error = error
    }
}

// MARK: - Persistence View Model

/// View model for persistence views
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@MainActor
public final class PersistenceViewModel<T: Storable & Identifiable>: ObservableObject {
    
    /// The current state
    @Published public private(set) var state: PersistenceViewState<T> = .initial
    
    /// The persistence store
    private let store: PersistenceStore
    
    /// Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    /// Creates a new view model
    public init(store: PersistenceStore) {
        self.store = store
    }
    
    /// Loads data from the store
    public func loadData() async {
        state = PersistenceViewState(items: state.items, isLoading: true, error: nil)
        
        do {
            let items = try await store.fetchAll(T.self)
            state = PersistenceViewState(items: items, isLoading: false, error: nil)
        } catch {
            state = PersistenceViewState(items: [], isLoading: false, error: error)
        }
    }
    
    /// Refreshes the data
    public func refresh() async {
        await loadData()
    }
    
    /// Saves an item
    public func save(_ item: T) async throws {
        try await store.save(item)
        await loadData()
    }
    
    /// Deletes an item
    public func delete(_ item: T) async throws {
        try await store.delete(T.self, id: item.id)
        await loadData()
    }
    
    /// Deletes items at offsets
    public func delete(at offsets: IndexSet) async throws {
        for index in offsets {
            let item = state.items[index]
            try await store.delete(T.self, id: item.id)
        }
        await loadData()
    }
}

// MARK: - Fetched Results

/// Property wrapper for fetching persisted results
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@propertyWrapper
public struct FetchedResults<T: Storable & Identifiable>: DynamicProperty {
    
    /// The observed object
    @StateObject private var fetcher: ResultsFetcher<T>
    
    /// The wrapped value
    public var wrappedValue: [T] {
        fetcher.results
    }
    
    /// Creates a new fetched results wrapper
    public init(store: PersistenceStore) {
        self._fetcher = StateObject(wrappedValue: ResultsFetcher<T>(store: store))
    }
    
    /// Refreshes the results
    public func refresh() async {
        await fetcher.fetch()
    }
}

/// Fetches results from the store
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@MainActor
private final class ResultsFetcher<T: Storable & Identifiable>: ObservableObject {
    
    @Published var results: [T] = []
    
    private let store: PersistenceStore
    
    init(store: PersistenceStore) {
        self.store = store
        Task {
            await fetch()
        }
    }
    
    func fetch() async {
        do {
            results = try await store.fetchAll(T.self)
        } catch {
            results = []
        }
    }
}

// MARK: - Persisted State

/// Property wrapper for a single persisted value
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@propertyWrapper
public struct PersistedState<T: Storable & Identifiable>: DynamicProperty {
    
    /// The observed object
    @StateObject private var wrapper: PersistedWrapper<T>
    
    /// The wrapped value
    public var wrappedValue: T? {
        get { wrapper.value }
        nonmutating set {
            Task {
                await wrapper.setValue(newValue)
            }
        }
    }
    
    /// The projected value for binding
    public var projectedValue: Binding<T?> {
        Binding(
            get: { wrapper.value },
            set: { newValue in
                Task {
                    await wrapper.setValue(newValue)
                }
            }
        )
    }
    
    /// Creates a new persisted state
    public init(store: PersistenceStore, id: T.ID) {
        self._wrapper = StateObject(wrappedValue: PersistedWrapper<T>(store: store, id: id))
    }
}

/// Wrapper for persisted state
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@MainActor
private final class PersistedWrapper<T: Storable & Identifiable>: ObservableObject {
    
    @Published var value: T?
    
    private let store: PersistenceStore
    private let id: T.ID
    
    init(store: PersistenceStore, id: T.ID) {
        self.store = store
        self.id = id
        Task {
            await load()
        }
    }
    
    func load() async {
        do {
            value = try await store.fetch(T.self, id: id)
        } catch {
            value = nil
        }
    }
    
    func setValue(_ newValue: T?) async {
        value = newValue
        
        if let newValue = newValue {
            try? await store.save(newValue)
        } else {
            try? await store.delete(T.self, id: id)
        }
    }
}

// MARK: - List Views

/// A list view for persisted items
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct PersistenceList<T: Storable & Identifiable, RowContent: View>: View {
    
    @StateObject private var viewModel: PersistenceViewModel<T>
    
    private let rowContent: (T) -> RowContent
    private let emptyContent: AnyView?
    private let loadingContent: AnyView?
    private let errorContent: ((Error) -> AnyView)?
    
    public init(
        store: PersistenceStore,
        @ViewBuilder rowContent: @escaping (T) -> RowContent
    ) {
        self._viewModel = StateObject(wrappedValue: PersistenceViewModel<T>(store: store))
        self.rowContent = rowContent
        self.emptyContent = nil
        self.loadingContent = nil
        self.errorContent = nil
    }
    
    public var body: some View {
        Group {
            if viewModel.state.isLoading {
                if let loadingContent = loadingContent {
                    loadingContent
                } else {
                    ProgressView()
                }
            } else if let error = viewModel.state.error {
                if let errorContent = errorContent {
                    errorContent(error)
                } else {
                    Text("Error: \(error.localizedDescription)")
                        .foregroundColor(.red)
                }
            } else if viewModel.state.isEmpty {
                if let emptyContent = emptyContent {
                    emptyContent
                } else {
                    Text("No items")
                        .foregroundColor(.secondary)
                }
            } else {
                List {
                    ForEach(viewModel.state.items) { item in
                        rowContent(item)
                    }
                    .onDelete { offsets in
                        Task {
                            try? await viewModel.delete(at: offsets)
                        }
                    }
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
    
    /// Sets the empty content
    public func emptyView<V: View>(@ViewBuilder content: () -> V) -> PersistenceList<T, RowContent> {
        var copy = self
        copy.emptyContent = AnyView(content())
        return copy
    }
    
    /// Sets the loading content
    public func loadingView<V: View>(@ViewBuilder content: () -> V) -> PersistenceList<T, RowContent> {
        var copy = self
        copy.loadingContent = AnyView(content())
        return copy
    }
    
    /// Sets the error content
    public func errorView<V: View>(@ViewBuilder content: @escaping (Error) -> V) -> PersistenceList<T, RowContent> {
        var copy = self
        copy.errorContent = { AnyView(content($0)) }
        return copy
    }
    
    private var emptyContent: AnyView?
    private var loadingContent: AnyView?
    private var errorContent: ((Error) -> AnyView)?
}

// MARK: - Detail View

/// A detail view for a single persisted item
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct PersistenceDetail<T: Storable & Identifiable, Content: View>: View {
    
    @StateObject private var wrapper: DetailWrapper<T>
    
    private let content: (Binding<T>) -> Content
    private let loadingContent: AnyView?
    private let notFoundContent: AnyView?
    
    public init(
        store: PersistenceStore,
        id: T.ID,
        @ViewBuilder content: @escaping (Binding<T>) -> Content
    ) {
        self._wrapper = StateObject(wrappedValue: DetailWrapper<T>(store: store, id: id))
        self.content = content
        self.loadingContent = nil
        self.notFoundContent = nil
    }
    
    public var body: some View {
        Group {
            if wrapper.isLoading {
                if let loadingContent = loadingContent {
                    loadingContent
                } else {
                    ProgressView()
                }
            } else if let item = Binding<T>(
                get: { wrapper.item! },
                set: { wrapper.item = $0 }
            ), wrapper.item != nil {
                content(item)
            } else {
                if let notFoundContent = notFoundContent {
                    notFoundContent
                } else {
                    Text("Item not found")
                        .foregroundColor(.secondary)
                }
            }
        }
        .task {
            await wrapper.load()
        }
    }
    
    /// Sets the loading content
    public func loadingView<V: View>(@ViewBuilder content: () -> V) -> PersistenceDetail<T, Content> {
        var copy = self
        copy.loadingContent = AnyView(content())
        return copy
    }
    
    /// Sets the not found content
    public func notFoundView<V: View>(@ViewBuilder content: () -> V) -> PersistenceDetail<T, Content> {
        var copy = self
        copy.notFoundContent = AnyView(content())
        return copy
    }
    
    private var loadingContent: AnyView?
    private var notFoundContent: AnyView?
}

/// Wrapper for detail view
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@MainActor
private final class DetailWrapper<T: Storable & Identifiable>: ObservableObject {
    
    @Published var item: T?
    @Published var isLoading = true
    
    private let store: PersistenceStore
    private let id: T.ID
    
    init(store: PersistenceStore, id: T.ID) {
        self.store = store
        self.id = id
    }
    
    func load() async {
        isLoading = true
        item = try? await store.fetch(T.self, id: id)
        isLoading = false
    }
    
    func save() async throws {
        guard let item = item else { return }
        try await store.save(item)
    }
}

// MARK: - Form View

/// A form view for creating/editing persisted items
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct PersistenceForm<T: Storable & Identifiable, Content: View>: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var wrapper: FormWrapper<T>
    
    private let content: (Binding<T>) -> Content
    private let onSave: ((T) -> Void)?
    private let onCancel: (() -> Void)?
    
    public init(
        store: PersistenceStore,
        initial: T,
        @ViewBuilder content: @escaping (Binding<T>) -> Content,
        onSave: ((T) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self._wrapper = StateObject(wrappedValue: FormWrapper<T>(store: store, initial: initial))
        self.content = content
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    public var body: some View {
        Form {
            content(Binding(
                get: { wrapper.item },
                set: { wrapper.item = $0 }
            ))
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onCancel?()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        do {
                            try await wrapper.save()
                            onSave?(wrapper.item)
                            dismiss()
                        } catch {
                            // Handle error
                        }
                    }
                }
                .disabled(wrapper.isSaving)
            }
        }
        .overlay {
            if wrapper.isSaving {
                ProgressView()
            }
        }
    }
}

/// Wrapper for form view
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@MainActor
private final class FormWrapper<T: Storable & Identifiable>: ObservableObject {
    
    @Published var item: T
    @Published var isSaving = false
    
    private let store: PersistenceStore
    
    init(store: PersistenceStore, initial: T) {
        self.store = store
        self.item = initial
    }
    
    func save() async throws {
        isSaving = true
        defer { isSaving = false }
        try await store.save(item)
    }
}

// MARK: - Environment Key

/// Environment key for persistence store
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct PersistenceStoreKey: EnvironmentKey {
    public static var defaultValue: PersistenceStore?
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public extension EnvironmentValues {
    var persistenceStore: PersistenceStore? {
        get { self[PersistenceStoreKey.self] }
        set { self[PersistenceStoreKey.self] = newValue }
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public extension View {
    func persistenceStore(_ store: PersistenceStore) -> some View {
        environment(\.persistenceStore, store)
    }
}

// MARK: - View Modifiers

/// Modifier for handling persistence errors
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct PersistenceErrorAlert: ViewModifier {
    
    @Binding var error: Error?
    
    public func body(content: Content) -> some View {
        content
            .alert(
                "Error",
                isPresented: Binding(
                    get: { error != nil },
                    set: { if !$0 { error = nil } }
                )
            ) {
                Button("OK") {
                    error = nil
                }
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public extension View {
    func persistenceErrorAlert(_ error: Binding<Error?>) -> some View {
        modifier(PersistenceErrorAlert(error: error))
    }
}

// MARK: - Loading Overlay

/// Modifier for showing a loading overlay
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct LoadingOverlay: ViewModifier {
    
    let isLoading: Bool
    
    public func body(content: Content) -> some View {
        content
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
            }
            .disabled(isLoading)
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public extension View {
    func loadingOverlay(_ isLoading: Bool) -> some View {
        modifier(LoadingOverlay(isLoading: isLoading))
    }
}

#endif
