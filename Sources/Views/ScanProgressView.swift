import SwiftUI

/// Real-time scan progress display fed by an AsyncStream.
/// Replaces ProgressPanelControl / ScanProgressPanelControl from the Obj-C codebase.
struct ScanProgressView: View {
    let path: String
    let progress: FileSystemScanner.Progress?
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, isActive: true)

            Text("Scanning...")
                .font(.title3)
                .fontWeight(.medium)

            Text(path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if let p = progress {
                VStack(spacing: 8) {
                    HStack {
                        Label("\(p.filesScanned.formatted()) files", systemImage: "doc")
                        Spacer()
                        Text(FileNode.formattedSize(p.totalSize))
                            .monospacedDigit()
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)

                    ProgressView()
                        .progressViewStyle(.linear)
                }
                .transition(.opacity)
            } else {
                ProgressView()
                    .controlSize(.large)
            }

            Button("Cancel", role: .cancel, action: onCancel)
                .keyboardShortcut(.cancelAction)
        }
        .padding(40)
        .frame(minWidth: 350)
        .animation(.easeOut(duration: 0.2), value: progress?.filesScanned)
    }
}
