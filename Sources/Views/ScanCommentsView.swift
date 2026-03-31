import SwiftUI

/// Sheet for editing scan comments.
/// Replaces the legacy `editComments:` action from DirectoryViewControl.
struct ScanCommentsView: View {
    @Environment(\.dismiss) private var dismiss

    let scanResult: ScanResult
    @State private var text: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Scan Comments")
                .font(.headline)

            Text(String(localized: "Comments for scan of \"\(scanResult.scanTree.name)\""))
                .foregroundStyle(.secondary)
                .font(.callout)

            TextEditor(text: $text)
                .font(.body)
                .frame(minHeight: 150)
                .border(Color.secondary.opacity(0.3))

            HStack {
                Spacer()
                Button(String(localized: "Cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "Save")) {
                    scanResult.comments = text
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 400)
        .onAppear {
            text = scanResult.comments
        }
    }
}
