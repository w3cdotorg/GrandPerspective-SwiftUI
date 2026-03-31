import SwiftUI
import UniformTypeIdentifiers

/// Displays file types found in a scan, ranked by total size, with visibility controls.
/// Replaces UniformTypeRankingWindowControl from the Obj-C codebase.
struct TypeRankingView: View {
    let scanResult: ScanResult

    @State private var typeStats: [TypeStat] = []
    @State private var hiddenTypes: Set<UTType> = []
    @State private var sortOrder: SortOrder = .size

    enum SortOrder: String, CaseIterable {
        case size = "Size"
        case count = "Count"
        case name = "Name"
    }

    struct TypeStat: Identifiable {
        let id: String
        let type: UTType
        var totalSize: UInt64
        var fileCount: Int

        var displayName: String {
            type.localizedDescription ?? type.identifier
        }
    }

    var sortedStats: [TypeStat] {
        switch sortOrder {
        case .size: typeStats.sorted { $0.totalSize > $1.totalSize }
        case .count: typeStats.sorted { $0.fileCount > $1.fileCount }
        case .name: typeStats.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("File Types")
                    .font(.headline)
                Spacer()
                Picker("Sort by:", selection: $sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .frame(width: 200)
            }
            .padding()

            Table(sortedStats) {
                TableColumn("Visible") { stat in
                    Toggle("", isOn: Binding(
                        get: { !hiddenTypes.contains(stat.type) },
                        set: { visible in
                            if visible {
                                hiddenTypes.remove(stat.type)
                            } else {
                                hiddenTypes.insert(stat.type)
                            }
                        }
                    ))
                    .labelsHidden()
                }
                .width(50)

                TableColumn("Type") { stat in
                    VStack(alignment: .leading) {
                        Text(stat.displayName)
                        Text(stat.type.identifier)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                TableColumn("Files") { stat in
                    Text("\(stat.fileCount)")
                        .monospacedDigit()
                }
                .width(60)

                TableColumn("Total Size") { stat in
                    Text(FileNode.formattedSize(stat.totalSize))
                        .monospacedDigit()
                }
                .width(100)

                TableColumn("") { stat in
                    ProgressView(value: Double(stat.totalSize), total: Double(maxSize))
                        .progressViewStyle(.linear)
                }
                .width(min: 80, ideal: 150)
            }
        }
        .frame(minWidth: 550, minHeight: 400)
        .onAppear { computeStats() }
    }

    private var maxSize: UInt64 {
        typeStats.map(\.totalSize).max() ?? 1
    }

    private func computeStats() {
        var stats: [String: TypeStat] = [:]

        func walk(_ node: FileNode) {
            if !node.isDirectory, let type = node.type {
                let key = type.identifier
                if var existing = stats[key] {
                    existing.totalSize += node.size
                    existing.fileCount += 1
                    stats[key] = existing
                } else {
                    stats[key] = TypeStat(id: key, type: type, totalSize: node.size, fileCount: 1)
                }
            }
            for child in node.children {
                walk(child)
            }
        }

        walk(scanResult.scanTree)
        typeStats = Array(stats.values)
    }
}
