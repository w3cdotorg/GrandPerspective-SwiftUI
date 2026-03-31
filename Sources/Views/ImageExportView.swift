import SwiftUI
import UniformTypeIdentifiers

/// Sheet for exporting the treemap as an image.
/// Replaces SaveImageDialogControl from the Obj-C codebase.
struct ImageExportView: View {
    @Environment(\.dismiss) private var dismiss

    let scanResult: ScanResult
    let colorMapping: any ColorMapping
    let zoomRoot: FileNode?

    @State private var width: Int = 1920
    @State private var height: Int = 1080
    @State private var format: ImageFormat = .png
    @State private var isExporting = false

    enum ImageFormat: String, CaseIterable {
        case png = "PNG"
        case tiff = "TIFF"
        case jpeg = "JPEG"

        var utType: UTType {
            switch self {
            case .png: .png
            case .tiff: .tiff
            case .jpeg: .jpeg
            }
        }

        var fileExtension: String {
            switch self {
            case .png: "png"
            case .tiff: "tiff"
            case .jpeg: "jpg"
            }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Export Treemap Image")
                .font(.headline)

            Form {
                Section("Dimensions") {
                    HStack {
                        TextField("Width", value: $width, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Text("x")
                        TextField("Height", value: $height, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Text("pixels")
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        presetButton("1080p", w: 1920, h: 1080)
                        presetButton("4K", w: 3840, h: 2160)
                        presetButton("Square", w: 2048, h: 2048)
                    }
                }

                Section("Format") {
                    Picker("Format:", selection: $format) {
                        ForEach(ImageFormat.allCases, id: \.self) { fmt in
                            Text(fmt.rawValue).tag(fmt)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .formStyle(.grouped)

            // Preview at small scale
            TreemapCanvasView(
                scanResult: scanResult,
                colorMapping: colorMapping,
                hoveredNode: .constant(nil),
                zoomRoot: .constant(zoomRoot)
            )
            .frame(width: 300, height: CGFloat(300 * height) / CGFloat(max(width, 1)))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Export...") { exportImage() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(width < 1 || height < 1)
            }
        }
        .padding()
        .frame(minWidth: 450)
    }

    private func presetButton(_ label: String, w: Int, h: Int) -> some View {
        Button(label) {
            width = w
            height = h
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func exportImage() {
        let displayRoot = zoomRoot ?? scanResult.scanTree

        // Render at requested size
        let renderView = TreemapCanvasView(
            scanResult: scanResult,
            colorMapping: colorMapping,
            hoveredNode: .constant(nil),
            zoomRoot: .constant(displayRoot)
        )
        .frame(width: CGFloat(width), height: CGFloat(height))

        let renderer = ImageRenderer(content: renderView)
        renderer.scale = 1.0

        guard let image = renderer.nsImage else { return }

        // Show save panel
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.utType]
        panel.nameFieldStringValue = "\(scanResult.scanTree.name)-treemap.\(format.fileExtension)"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        // Write image data
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return }

        let data: Data?
        switch format {
        case .png:
            data = bitmap.representation(using: .png, properties: [:])
        case .tiff:
            data = bitmap.representation(using: .tiff, properties: [.compressionMethod: NSBitmapImageRep.TIFFCompression.lzw])
        case .jpeg:
            data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        }

        if let data {
            try? data.write(to: url)
        }

        dismiss()
    }
}
