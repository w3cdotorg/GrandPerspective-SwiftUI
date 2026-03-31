import SwiftUI

/// Displays the filter repository as a list with add/edit/remove.
/// Replaces FiltersWindowControl from the Obj-C codebase.
struct FilterListView: View {
    @Bindable var repository: FilterRepository
    @State private var selection: UUID?
    @State private var editingFilter: NamedFilter?
    @State private var isCreating = false

    var body: some View {
        VStack(spacing: 0) {
            List(repository.filters, selection: $selection) { filter in
                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        Text(filter.name)
                            .fontWeight(.medium)
                        Text(GrandPerspective.describeFilter(filter.filter))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .tag(filter.id)
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            // Bottom toolbar
            HStack {
                Button(action: { isCreating = true }) {
                    Image(systemName: "plus")
                }
                Button(action: editSelected) {
                    Image(systemName: "pencil")
                }
                .disabled(selection == nil)
                Button(action: removeSelected) {
                    Image(systemName: "minus")
                }
                .disabled(selection == nil)
                Spacer()
                Text("\(repository.filters.count) filter(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(.ultraThinMaterial)
        }
        .frame(minWidth: 350, minHeight: 300)
        .sheet(isPresented: $isCreating) {
            FilterEditorView(existing: nil, repository: repository) { newFilter in
                repository.add(newFilter)
            }
        }
        .sheet(item: $editingFilter) { filter in
            FilterEditorView(existing: filter, repository: repository) { updated in
                repository.replace(id: filter.id, with: updated)
            }
        }
    }

    private func editSelected() {
        guard let id = selection,
              let filter = repository.filters.first(where: { $0.id == id }) else { return }
        editingFilter = filter
    }

    private func removeSelected() {
        guard let id = selection else { return }
        repository.remove(id: id)
        selection = nil
    }

}

// MARK: - Filter description (used by FilterListView and FilterPickerView)

func describeFilter(_ filter: FileFilter) -> String {
    switch filter {
    case .nameMatches(let p, _): return "Name: \(p.joined(separator: ", "))"
    case .pathMatches(let p, _): return "Path: \(p.joined(separator: ", "))"
    case .sizeRange(let min, let max):
        let lo = min.map { FileNode.formattedSize($0) } ?? "0"
        let hi = max.map { FileNode.formattedSize($0) } ?? "..."
        return "Size: \(lo) – \(hi)"
    case .typeMatches(let t, _): return "Type: \(t.map(\.identifier).joined(separator: ", "))"
    case .hasFlags(let f): return "Has flags: \(f.contains(.hardLinked) ? "hard-linked" : "package")"
    case .lacksFlags(let f): return "Lacks flags: \(f.contains(.hardLinked) ? "hard-linked" : "package")"
    case .not(let inner): return "NOT (\(describeFilter(inner)))"
    case .and(let sub): return sub.map { describeFilter($0) }.joined(separator: " AND ")
    case .or(let sub): return sub.map { describeFilter($0) }.joined(separator: " OR ")
    case .creationDateRange(let min, let max): return "Created: \(formatDateRange(min, max))"
    case .modificationDateRange(let min, let max): return "Modified: \(formatDateRange(min, max))"
    case .accessDateRange(let min, let max): return "Accessed: \(formatDateRange(min, max))"
    case .filesOnly(let inner): return "Files: \(describeFilter(inner))"
    case .directoriesOnly(let inner): return "Dirs: \(describeFilter(inner))"
    }
}

private func formatDateRange(_ min: Date?, _ max: Date?) -> String {
    let fmt = DateFormatter()
    fmt.dateStyle = .medium
    fmt.timeStyle = .none
    let lo = min.map { fmt.string(from: $0) } ?? "..."
    let hi = max.map { fmt.string(from: $0) } ?? "..."
    return "\(lo) – \(hi)"
}
