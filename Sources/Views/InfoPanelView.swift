import SwiftUI
import UniformTypeIdentifiers

/// Inspector panel with Display, Info, and Focus tabs.
/// Replaces the legacy Drawer with Display/Info/Focus panels.
struct InfoPanelView: View {
    let scanResult: ScanResult
    let selectedNode: FileNode?
    let hoveredNode: FileNode?

    enum Tab: String, CaseIterable {
        case display = "Display"
        case info = "Info"
        case focus = "Focus"
    }

    @State private var selectedTab: Tab = .display

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            Divider()

            ScrollView {
                switch selectedTab {
                case .display:
                    DisplayTab(scanResult: scanResult)
                case .info:
                    InfoTab(node: selectedNode, scanResult: scanResult)
                case .focus:
                    FocusTab(node: hoveredNode, scanResult: scanResult)
                }
            }
        }
        .frame(minWidth: 240, idealWidth: 280)
    }
}

// MARK: - Display Tab

private struct DisplayTab: View {
    let scanResult: ScanResult

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Volume")
            InfoRow("Path", scanResult.volumePath)
            InfoRow("Volume size", FileNode.formattedSize(scanResult.volumeSize))
            InfoRow("Free space", FileNode.formattedSize(scanResult.freeSpace))
            InfoRow("Used space", FileNode.formattedSize(scanResult.usedSpace))

            Divider()

            SectionHeader("Scan")
            InfoRow("Scanned folder", scanResult.scanTree.name)
            InfoRow("Scanned size", FileNode.formattedSize(scanResult.scanTree.size))
            InfoRow("Files", "\(scanResult.scanTree.fileCount)")
            InfoRow("Misc. used space", FileNode.formattedSize(scanResult.miscUsedSpace))
            InfoRow("Scan time", Self.dateFormatter.string(from: scanResult.scanTime))
            InfoRow("Size measure", scanResult.sizeMeasure == .logical ? "Logical" : "Physical")

            if scanResult.freedFiles > 0 {
                Divider()
                SectionHeader("Deletions")
                InfoRow("Files deleted", "\(scanResult.freedFiles)")
                InfoRow("Space freed", FileNode.formattedSize(scanResult.freedSpace))
            }
        }
        .padding(12)
    }
}

// MARK: - Info Tab

private struct InfoTab: View {
    let node: FileNode?
    let scanResult: ScanResult

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f
    }()

    var body: some View {
        if let node {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("General")
                InfoRow("Name", node.name)
                InfoRow("Path", node.path)
                InfoRow("Size", node.formattedSize)
                InfoRow("Type", nodeTypeLabel(node))

                if let utType = node.type {
                    InfoRow("UTI", utType.identifier)
                    if let desc = utType.localizedDescription {
                        InfoRow("Kind", desc)
                    }
                }

                Divider()

                SectionHeader("Dates")
                if let date = node.creationDate {
                    InfoRow("Created", Self.dateFormatter.string(from: date))
                }
                if let date = node.modificationDate {
                    InfoRow("Modified", Self.dateFormatter.string(from: date))
                }
                if let date = node.accessDate {
                    InfoRow("Accessed", Self.dateFormatter.string(from: date))
                }

                Divider()

                SectionHeader("Attributes")
                if node.isDirectory {
                    InfoRow("Files", "\(node.fileCount)")
                    InfoRow("Children", "\(node.children.count)")
                }
                InfoRow("Hard-linked", node.isHardLinked ? "Yes" : "No")
                InfoRow("Package", node.isPackage ? "Yes" : "No")
            }
            .padding(12)
        } else {
            ContentUnavailableView(
                "No Selection",
                systemImage: "cursorarrow.click.2",
                description: Text("Click a file or folder in the treemap.")
            )
            .padding()
        }
    }

    private func nodeTypeLabel(_ node: FileNode) -> String {
        switch node.kind {
        case .file: return "File"
        case .directory:
            return node.isPackage ? "Package" : "Folder"
        case .synthetic(let role):
            return role.rawValue.capitalized
        }
    }
}

// MARK: - Focus Tab

private struct FocusTab: View {
    let node: FileNode?
    let scanResult: ScanResult

    var body: some View {
        if let node {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Hovered Item")
                InfoRow("Name", node.name)
                InfoRow("Path", node.path)
                InfoRow("Size", node.formattedSize)

                if let parent = node.parent {
                    let pct = parent.size > 0
                        ? Double(node.size) / Double(parent.size) * 100
                        : 0
                    InfoRow("% of parent", String(format: "%.1f%%", pct))
                }

                let totalPct = scanResult.scanTree.size > 0
                    ? Double(node.size) / Double(scanResult.scanTree.size) * 100
                    : 0
                InfoRow("% of total", String(format: "%.1f%%", totalPct))

                let depth = node.ancestors.count - 1
                InfoRow("Depth", "\(depth)")

                if node.isDirectory {
                    InfoRow("Files", "\(node.fileCount)")
                }
            }
            .padding(12)
        } else {
            ContentUnavailableView(
                "No Focus",
                systemImage: "cursorarrow",
                description: Text("Hover over the treemap to see details.")
            )
            .padding()
        }
    }
}

// MARK: - Helpers

private struct SectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .trailing)
            Text(value)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.callout)
    }
}
