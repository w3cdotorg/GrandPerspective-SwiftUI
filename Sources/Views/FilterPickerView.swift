import SwiftUI

/// Sheet for selecting a filter to apply to the current scan.
/// Replaces FilterSelectionPanelControl from the Obj-C codebase.
struct FilterPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let repository: FilterRepository
    let onApply: (NamedFilter?) -> Void

    @State private var selectedId: UUID?
    @State private var showingFilterList = false
    @State private var isCreating = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Apply Filter")
                .font(.headline)

            if repository.filters.isEmpty {
                Text("No filters available. Create one first.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Filter:", selection: $selectedId) {
                    Text("None").tag(nil as UUID?)
                    ForEach(repository.filters) { filter in
                        Text(filter.name).tag(filter.id as UUID?)
                    }
                }
                .labelsHidden()

                if let id = selectedId,
                   let filter = repository.filters.first(where: { $0.id == id }) {
                    GroupBox {
                        Text(describeFilter(filter.filter))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            HStack {
                Button("Edit Filters...") {
                    showingFilterList = true
                }
                Button("New Filter...") {
                    isCreating = true
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Apply") {
                    let selected = selectedId.flatMap { id in repository.filters.first { $0.id == id } }
                    onApply(selected)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 400)
        .sheet(isPresented: $showingFilterList) {
            FilterListView(repository: repository)
                .frame(minWidth: 450, minHeight: 350)
        }
        .sheet(isPresented: $isCreating) {
            FilterEditorView(existing: nil, repository: repository) { newFilter in
                repository.add(newFilter)
                selectedId = newFilter.id
            }
        }
    }
}
