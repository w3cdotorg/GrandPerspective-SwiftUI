import SwiftUI
import UniformTypeIdentifiers

/// Edits a single NamedFilter (name + composed filter tests).
/// Replaces FilterWindowControl from the Obj-C codebase.
struct FilterEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let existing: NamedFilter?
    let repository: FilterRepository
    let onSave: (NamedFilter) -> Void

    @State private var filterName: String
    @State private var tests: [FilterTestRow]
    @State private var combineMode: CombineMode = .all

    enum CombineMode: String, CaseIterable {
        case all = "All must match"
        case any = "Any must match"
    }

    init(existing: NamedFilter?, repository: FilterRepository, onSave: @escaping (NamedFilter) -> Void) {
        self.existing = existing
        self.repository = repository
        self.onSave = onSave
        _filterName = State(initialValue: existing?.name ?? "")
        _tests = State(initialValue: existing.map { Self.decompose($0.filter) } ?? [FilterTestRow()])
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Filter Name") {
                    TextField("Name", text: $filterName)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Match Mode") {
                    Picker("Combine tests:", selection: $combineMode) {
                        ForEach(CombineMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Tests") {
                    ForEach($tests) { $test in
                        FilterTestRowView(test: $test)
                    }
                    .onDelete { tests.remove(atOffsets: $0) }

                    Button("Add Test") {
                        tests.append(FilterTestRow())
                    }
                }
            }
            .formStyle(.grouped)

            // Action bar
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private var isValid: Bool {
        !filterName.trimmingCharacters(in: .whitespaces).isEmpty
            && !tests.isEmpty
            && !repository.isNameTaken(filterName, excluding: existing?.id)
    }

    private func save() {
        let subFilters = tests.compactMap { $0.toFileFilter() }
        guard !subFilters.isEmpty else { return }

        let combined: FileFilter = switch combineMode {
        case .all: subFilters.count == 1 ? subFilters[0] : .and(subFilters)
        case .any: subFilters.count == 1 ? subFilters[0] : .or(subFilters)
        }

        let named = NamedFilter(name: filterName.trimmingCharacters(in: .whitespaces), filter: combined)
        onSave(named)
        dismiss()
    }

    // MARK: - Decompose existing filter into editable rows

    static func decompose(_ filter: FileFilter) -> [FilterTestRow] {
        switch filter {
        case .and(let sub):
            return sub.map { FilterTestRow(from: $0) }
        case .or(let sub):
            return sub.map { FilterTestRow(from: $0) }
        default:
            return [FilterTestRow(from: filter)]
        }
    }
}

// MARK: - Filter Test Row Model

struct FilterTestRow: Identifiable {
    let id = UUID()
    var testType: TestType = .name
    var namePattern: String = ""
    var caseSensitive: Bool = false
    var inverted: Bool = false
    var minSize: String = ""
    var maxSize: String = ""
    var sizeUnit: SizeUnit = .mb
    var typeIdentifier: String = ""
    var strictType: Bool = false
    var targetKind: TargetKind = .files

    enum TestType: String, CaseIterable, Identifiable {
        case name = "Name"
        case path = "Path"
        case size = "Size"
        case type = "File Type"
        case flags = "Flags"
        var id: String { rawValue }
    }

    enum SizeUnit: String, CaseIterable {
        case bytes = "B"
        case kb = "KB"
        case mb = "MB"
        case gb = "GB"

        var multiplier: UInt64 {
            switch self {
            case .bytes: 1
            case .kb: 1024
            case .mb: 1024 * 1024
            case .gb: 1024 * 1024 * 1024
            }
        }
    }

    enum TargetKind: String, CaseIterable {
        case all = "All"
        case files = "Files only"
        case directories = "Directories only"
    }

    init() {}

    init(from filter: FileFilter) {
        // Unwrap wrappers first
        var inner = filter
        var invertFlag = false
        var kind = TargetKind.all

        unwrap: while true {
            switch inner {
            case .not(let wrapped):
                invertFlag.toggle()
                inner = wrapped
            case .filesOnly(let wrapped):
                kind = .files
                inner = wrapped
            case .directoriesOnly(let wrapped):
                kind = .directories
                inner = wrapped
            default:
                break unwrap
            }
        }

        inverted = invertFlag
        targetKind = kind

        switch inner {
        case .nameMatches(let patterns, let cs):
            testType = .name
            namePattern = patterns.joined(separator: ", ")
            caseSensitive = cs
        case .pathMatches(let patterns, let cs):
            testType = .path
            namePattern = patterns.joined(separator: ", ")
            caseSensitive = cs
        case .sizeRange(let min, let max):
            testType = .size
            if let min { minSize = "\(min)" }
            if let max { maxSize = "\(max)" }
            sizeUnit = .bytes
        case .typeMatches(let types, let strict):
            testType = .type
            typeIdentifier = types.map(\.identifier).joined(separator: ", ")
            strictType = strict
        case .hasFlags(let flags):
            testType = .flags
            namePattern = flags.contains(.hardLinked) ? "hard-linked" : "package"
        default:
            break
        }
    }

    func toFileFilter() -> FileFilter? {
        var base: FileFilter?

        switch testType {
        case .name:
            let patterns = namePattern.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard !patterns.isEmpty else { return nil }
            base = .nameMatches(patterns, caseSensitive: caseSensitive)
        case .path:
            let patterns = namePattern.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard !patterns.isEmpty else { return nil }
            base = .pathMatches(patterns, caseSensitive: caseSensitive)
        case .size:
            let min = UInt64(minSize).map { $0 * sizeUnit.multiplier }
            let max = UInt64(maxSize).map { $0 * sizeUnit.multiplier }
            guard min != nil || max != nil else { return nil }
            base = .sizeRange(min: min, max: max)
        case .type:
            let ids = typeIdentifier.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let types = ids.compactMap { UTType($0) }
            guard !types.isEmpty else { return nil }
            base = .typeMatches(types, strict: strictType)
        case .flags:
            let flags: FileNode.Flags = namePattern.contains("hard") ? .hardLinked : .package
            base = .hasFlags(flags)
        }

        guard var result = base else { return nil }

        if inverted { result = .not(result) }

        switch targetKind {
        case .all: break
        case .files: result = .filesOnly(result)
        case .directories: result = .directoriesOnly(result)
        }

        return result
    }
}

// MARK: - Individual test row view

struct FilterTestRowView: View {
    @Binding var test: FilterTestRow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Picker("Test:", selection: $test.testType) {
                    ForEach(FilterTestRow.TestType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .frame(width: 180)

                Picker("Scope:", selection: $test.targetKind) {
                    ForEach(FilterTestRow.TargetKind.allCases, id: \.self) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .frame(width: 160)

                Toggle("Invert", isOn: $test.inverted)
            }

            switch test.testType {
            case .name, .path:
                HStack {
                    TextField("Patterns (comma-separated)", text: $test.namePattern)
                        .textFieldStyle(.roundedBorder)
                    Toggle("Case sensitive", isOn: $test.caseSensitive)
                }
            case .size:
                HStack {
                    TextField("Min", text: $test.minSize)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    Text("–")
                    TextField("Max", text: $test.maxSize)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    Picker("", selection: $test.sizeUnit) {
                        ForEach(FilterTestRow.SizeUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .frame(width: 80)
                }
            case .type:
                HStack {
                    TextField("UTType identifiers (comma-separated)", text: $test.typeIdentifier)
                        .textFieldStyle(.roundedBorder)
                    Toggle("Strict match", isOn: $test.strictType)
                }
            case .flags:
                Picker("Flag:", selection: $test.namePattern) {
                    Text("Hard-linked").tag("hard-linked")
                    Text("Package").tag("package")
                }
            }
        }
        .padding(.vertical, 4)
    }
}
