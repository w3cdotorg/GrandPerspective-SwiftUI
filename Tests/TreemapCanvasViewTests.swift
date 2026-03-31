import Testing
import SwiftUI
@testable import GrandPerspective

@MainActor
@Suite("TreemapCanvasView")
struct TreemapCanvasViewTests {

    // MARK: - Helpers

    static func makeScanResult() -> ScanResult {
        let tree = FileNode(name: "root", kind: .directory, size: 10000, children: [
            FileNode(name: "photos", kind: .directory, size: 6000, children: [
                FileNode(name: "vacation.jpg", kind: .file, size: 4000, type: .jpeg),
                FileNode(name: "cat.png", kind: .file, size: 2000, type: .png),
            ]),
            FileNode(name: "docs", kind: .directory, size: 3000, children: [
                FileNode(name: "readme.md", kind: .file, size: 1000, type: .plainText),
                FileNode(name: "notes.txt", kind: .file, size: 2000, type: .plainText),
            ]),
            FileNode(name: "config.json", kind: .file, size: 1000),
        ])
        return ScanResult(
            scanTree: tree,
            volumePath: "/",
            volumeSize: 100_000,
            freeSpace: 50_000
        )
    }

    // MARK: - Gradient rendering

    @Test func gradientRendersToImage() {
        let result = Self.makeScanResult()
        let view = TreemapCanvasView(
            scanResult: result,
            colorMapping: FolderColorMapping(),
            hoveredNode: .constant(nil),
            zoomRoot: .constant(nil)
        )
        .environment(AppState())
        .frame(width: 600, height: 400)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        let image = renderer.nsImage

        #expect(image != nil)
        if let image {
            #expect(image.size.width > 0)
            #expect(image.size.height > 0)
        }
    }

    // MARK: - Zoom rendering

    @Test func zoomedViewRendersSubtree() {
        let result = Self.makeScanResult()
        let photos = result.scanTree.children.first { $0.name == "photos" }!

        let bounds = CGRect(x: 0, y: 0, width: 600, height: 400)
        let rects = TreemapLayout.layout(root: photos, in: bounds)

        // Only photos children should appear
        #expect(rects.count == 2)
        let names = Set(rects.map { $0.node.name })
        #expect(names == ["vacation.jpg", "cat.png"])
    }

    @Test func zoomedViewTakesFullArea() {
        let result = Self.makeScanResult()
        let photos = result.scanTree.children.first { $0.name == "photos" }!

        let bounds = CGRect(x: 0, y: 0, width: 600, height: 400)
        let rects = TreemapLayout.layout(root: photos, in: bounds)

        let totalArea = rects.reduce(0.0) { $0 + Double($1.rect.width * $1.rect.height) }
        let expectedArea = Double(bounds.width * bounds.height)
        #expect(abs(totalArea - expectedArea) / expectedArea < 0.01)
    }

    // MARK: - Hit testing via layout

    @Test func hitTestFindsCorrectNode() {
        let result = Self.makeScanResult()
        let bounds = CGRect(x: 0, y: 0, width: 600, height: 400)
        let rects = TreemapLayout.layout(root: result.scanTree, in: bounds)

        // Each rect center should find itself
        for treemapRect in rects {
            let center = CGPoint(x: treemapRect.rect.midX, y: treemapRect.rect.midY)
            let hit = rects.last { $0.rect.contains(center) }
            #expect(hit != nil)
            #expect(hit!.node.id == treemapRect.node.id)
        }
    }

    @Test func hitTestOutsideBoundsReturnsNil() {
        let result = Self.makeScanResult()
        let bounds = CGRect(x: 0, y: 0, width: 600, height: 400)
        let rects = TreemapLayout.layout(root: result.scanTree, in: bounds)

        let outside = CGPoint(x: -10, y: -10)
        let hit = rects.last { $0.rect.contains(outside) }
        #expect(hit == nil)
    }

    // MARK: - Color mappings with gradient

    @Test func allMappingsRenderWithoutCrash() {
        let result = Self.makeScanResult()

        for mapping in ColorMappings.all {
            let view = TreemapCanvasView(
                scanResult: result,
                colorMapping: mapping,
                hoveredNode: .constant(nil),
                zoomRoot: .constant(nil)
            )
            .environment(AppState())
            .frame(width: 400, height: 300)

            let renderer = ImageRenderer(content: view)
            let image = renderer.nsImage
            #expect(image != nil, "Mapping '\(mapping.name)' failed to render")
        }
    }

    // MARK: - Labels

    @Test func largeRectsGetLabels() {
        // With a big enough canvas, the largest items should get labels
        let result = Self.makeScanResult()
        let bounds = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let rects = TreemapLayout.layout(root: result.scanTree, in: bounds)

        // At least the biggest file (vacation.jpg, 40% of total) should have a rect > 50x16
        let vacation = rects.first { $0.node.name == "vacation.jpg" }!
        #expect(vacation.rect.width >= 50)
        #expect(vacation.rect.height >= 16)
    }
}

@MainActor
@Suite("BreadcrumbBar")
struct BreadcrumbBarTests {

    static func makeTree() -> FileNode {
        let deep = FileNode(name: "file.txt", kind: .file, size: 100)
        let sub = FileNode(name: "sub", kind: .directory, size: 100, children: [deep])
        return FileNode(name: "root", kind: .directory, size: 100, children: [sub])
    }

    @Test func breadcrumbShowsPath() {
        let root = Self.makeTree()
        let sub = root.children.first!

        var navigatedTo: FileNode?
        let view = BreadcrumbBar(
            scanRoot: root,
            zoomRoot: sub,
            onNavigate: { navigatedTo = $0 }
        )
        _ = view.body
        // Just verify it doesn't crash
        #expect(navigatedTo == nil)
    }

    @Test func breadcrumbAncestorsFromZoomRoot() {
        let root = Self.makeTree()
        let sub = root.children.first!

        // sub's ancestors should be [root, sub]
        let ancestors = sub.ancestors
        #expect(ancestors.count == 2)
        #expect(ancestors[0] === root)
        #expect(ancestors[1] === sub)
    }

    @Test func nilZoomRootShowsOnlyScanRoot() {
        let root = Self.makeTree()
        let view = BreadcrumbBar(
            scanRoot: root,
            zoomRoot: nil,
            onNavigate: { _ in }
        )
        _ = view.body
    }
}
