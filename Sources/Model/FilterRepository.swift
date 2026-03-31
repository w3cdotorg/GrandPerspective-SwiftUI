import Foundation

/// Observable store of named filters. Replaces FilterRepository / FilterTestRepository from Obj-C.
@Observable
final class FilterRepository: @unchecked Sendable {

    /// All saved filters, ordered by name.
    var filters: [NamedFilter] {
        didSet { scheduleSave() }
    }

    /// File URL for persistent storage.
    private let storageURL: URL

    /// Debounce timer for saving.
    @ObservationIgnored
    private var saveTask: Task<Void, Never>?

    init(filters: [NamedFilter] = NamedFilter.defaults, storageURL: URL? = nil) {
        self.storageURL = storageURL ?? Self.defaultStorageURL
        self.filters = filters
    }

    // MARK: - CRUD

    func add(_ filter: NamedFilter) {
        filters.append(filter)
        filters.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func remove(id: UUID) {
        filters.removeAll { $0.id == id }
    }

    func replace(id: UUID, with newFilter: NamedFilter) {
        if let idx = filters.firstIndex(where: { $0.id == id }) {
            filters[idx] = newFilter
            filters.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    func filter(named name: String) -> NamedFilter? {
        filters.first { $0.name == name }
    }

    func isNameTaken(_ name: String, excluding id: UUID? = nil) -> Bool {
        filters.contains { $0.name == name && $0.id != id }
    }

    // MARK: - Persistence

    static var defaultStorageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("GrandPerspective", isDirectory: true)
        return dir.appendingPathComponent("filters.json")
    }

    /// Load filters from disk. Falls back to defaults if file doesn't exist or is corrupted.
    func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loaded = try decoder.decode([NamedFilter].self, from: data)
            // Set directly to backing storage to avoid triggering save
            filters = loaded
            // Cancel any save triggered by the didSet
            saveTask?.cancel()
            saveTask = nil
        } catch {
            // Keep defaults on failure
        }
    }

    /// Save filters to disk.
    func saveToDisk() {
        do {
            let dir = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(filters)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            // Silent failure — filters remain in memory
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            saveToDisk()
        }
    }
}
