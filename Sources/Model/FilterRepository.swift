import Foundation

/// Observable store of named filters. Replaces FilterRepository / FilterTestRepository from Obj-C.
@Observable
final class FilterRepository: @unchecked Sendable {

    /// All saved filters, ordered by name.
    var filters: [NamedFilter]

    init(filters: [NamedFilter] = NamedFilter.defaults) {
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
}
