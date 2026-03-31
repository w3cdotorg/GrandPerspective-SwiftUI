import SwiftUI

/// Displays the path from scan root to the current zoom target as clickable breadcrumbs.
/// Replaces ItemPathDrawer from the Obj-C codebase.
struct BreadcrumbBar: View {
    let scanRoot: FileNode
    let zoomRoot: FileNode?
    let onNavigate: (FileNode?) -> Void

    private var breadcrumbs: [FileNode] {
        guard let zoomRoot else { return [scanRoot] }
        return zoomRoot.ancestors.filter { node in
            // Only show from scanRoot downward
            scanRoot.isAncestor(of: node) || node === scanRoot
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            // Home button (back to scan root)
            Button {
                onNavigate(nil)
            } label: {
                Image(systemName: "house.fill")
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .foregroundStyle(zoomRoot == nil ? .primary : .secondary)
            .accessibilityLabel(String(localized: "Navigate to scan root"))

            ForEach(Array(breadcrumbs.enumerated()), id: \.element.id) { index, node in
                HStack(spacing: 2) {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    let isLast = index == breadcrumbs.count - 1
                    Button {
                        if !isLast {
                            onNavigate(node)
                        }
                    } label: {
                        Text(node.name)
                            .lineLimit(1)
                            .font(.callout)
                            .fontWeight(isLast ? .semibold : .regular)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isLast ? .primary : .secondary)
                    .accessibilityLabel(String(localized: "Navigate to \(node.name)"))
                }
            }

            Spacer()

            // Show size of current view
            if let zoomRoot {
                Text(zoomRoot.formattedSize)
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }
}
