import Testing
import SwiftUI
@testable import GrandPerspective

@MainActor
@Suite("SwiftUI Views")
struct ViewTests {

    // MARK: - Helpers

    static func makeScanResult() -> ScanResult {
        let tree = FileNode(name: "Documents", kind: .directory, size: 5000, children: [
            FileNode(name: "photos", kind: .directory, size: 3000, children: [
                FileNode(name: "vacation.jpg", kind: .file, size: 2000, type: .jpeg),
                FileNode(name: "cat.png", kind: .file, size: 1000, type: .png),
            ]),
            FileNode(name: "notes.txt", kind: .file, size: 500, type: .plainText),
            FileNode(name: "report.pdf", kind: .file, size: 1500, type: .pdf),
        ])
        return ScanResult(
            scanTree: tree,
            volumePath: "/",
            volumeSize: 100_000,
            freeSpace: 50_000
        )
    }

    // MARK: - TreemapView rendering

    @Test func treemapLayoutFromScanResult() {
        let result = Self.makeScanResult()
        let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        let rects = TreemapLayout.layout(root: result.scanTree, in: bounds)

        // Should have 4 leaf files
        #expect(rects.count == 4)

        let names = Set(rects.map { $0.node.name })
        #expect(names.contains("vacation.jpg"))
        #expect(names.contains("cat.png"))
        #expect(names.contains("notes.txt"))
        #expect(names.contains("report.pdf"))
    }

    @Test func treemapLayoutColorMappingIntegration() {
        let result = Self.makeScanResult()
        let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        let rects = TreemapLayout.layout(root: result.scanTree, in: bounds)

        // Verify each rect gets a color from each mapping type without crashing
        let mappings: [any ColorMapping] = ColorMappings.all
        for mapping in mappings {
            for rect in rects {
                _ = mapping.color(for: rect.node, depth: rect.depth)
            }
        }
    }

    // MARK: - ImageRenderer snapshot

    @MainActor @Test func treemapRendersToImage() {
        let result = Self.makeScanResult()
        let mapping = FolderColorMapping()

        let treemapView = TreemapView(
            scanResult: result,
            colorMapping: mapping,
            hoveredNode: .constant(nil)
        )
        .environment(AppState())
        .frame(width: 400, height: 300)

        let renderer = ImageRenderer(content: treemapView)
        renderer.scale = 2.0
        let image = renderer.nsImage

        #expect(image != nil)
        if let image {
            #expect(image.size.width > 0)
            #expect(image.size.height > 0)
        }
    }

    // MARK: - End-to-end: scan → layout → render

    @Test func endToEndScanAndRender() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GPViewTest_\(UUID().uuidString)")
        let fm = FileManager.default
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        try "Hello".write(to: tmp.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "World!".write(to: tmp.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
        defer { try? fm.removeItem(at: tmp) }

        let scanner = FileSystemScanner(sizeMeasure: .logical)
        let root = try await scanner.scan(url: tmp)

        let bounds = CGRect(x: 0, y: 0, width: 400, height: 300)
        let rects = TreemapLayout.layout(root: root, in: bounds)

        #expect(rects.count == 2)

        let mapping = FolderColorMapping()
        for rect in rects {
            let color = mapping.color(for: rect.node, depth: rect.depth)
            #expect(color != Color.gray)
        }

        let totalArea = rects.reduce(0.0) { $0 + Double($1.rect.width * $1.rect.height) }
        let expectedArea = Double(bounds.width * bounds.height)
        #expect(abs(totalArea - expectedArea) / expectedArea < 0.01)
    }
}
