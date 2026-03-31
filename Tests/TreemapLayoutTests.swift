import Testing
import Foundation
@testable import GrandPerspective

@Suite("TreemapLayout")
struct TreemapLayoutTests {

    // MARK: - Helpers

    static func makeSimpleTree() -> FileNode {
        FileNode(name: "root", kind: .directory, size: 100, children: [
            FileNode(name: "big.dat", kind: .file, size: 70),
            FileNode(name: "small.dat", kind: .file, size: 30),
        ])
    }

    static func makeDeeperTree() -> FileNode {
        FileNode(name: "root", kind: .directory, size: 300, children: [
            FileNode(name: "a", kind: .directory, size: 200, children: [
                FileNode(name: "a1.txt", kind: .file, size: 150),
                FileNode(name: "a2.txt", kind: .file, size: 50),
            ]),
            FileNode(name: "b.txt", kind: .file, size: 100),
        ])
    }

    // MARK: - Basic layout

    @Test func layoutProducesRectsForLeaves() {
        let root = Self.makeSimpleTree()
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let rects = TreemapLayout.layout(root: root, in: bounds)

        #expect(rects.count == 2)
        // All rects should be within bounds
        for r in rects {
            #expect(r.rect.minX >= bounds.minX - 1)
            #expect(r.rect.minY >= bounds.minY - 1)
            #expect(r.rect.maxX <= bounds.maxX + 1)
            #expect(r.rect.maxY <= bounds.maxY + 1)
        }
    }

    @Test func layoutAreaProportionalToSize() {
        let root = Self.makeSimpleTree()
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let rects = TreemapLayout.layout(root: root, in: bounds)

        let big = rects.first { $0.node.name == "big.dat" }!
        let small = rects.first { $0.node.name == "small.dat" }!

        let bigArea = big.rect.width * big.rect.height
        let smallArea = small.rect.width * small.rect.height

        // big should have ~70% of the area, small ~30%
        let ratio = bigArea / (bigArea + smallArea)
        #expect(ratio > 0.6 && ratio < 0.8)
    }

    @Test func layoutTotalAreaCoversRect() {
        let root = Self.makeSimpleTree()
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 150)
        let rects = TreemapLayout.layout(root: root, in: bounds)

        let totalArea = rects.reduce(0.0) { $0 + Double($1.rect.width * $1.rect.height) }
        let boundsArea = Double(bounds.width * bounds.height)

        // Total area should approximately equal bounds area (within 1% tolerance)
        #expect(abs(totalArea - boundsArea) / boundsArea < 0.01)
    }

    // MARK: - Depth

    @Test func layoutAssignsCorrectDepth() {
        let root = Self.makeDeeperTree()
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 200)
        let rects = TreemapLayout.layout(root: root, in: bounds)

        let a1 = rects.first { $0.node.name == "a1.txt" }!
        let b = rects.first { $0.node.name == "b.txt" }!

        // a1.txt is at depth 2 (root > a > a1.txt)
        #expect(a1.depth == 2)
        // b.txt is at depth 1 (root > b.txt)
        #expect(b.depth == 1)
    }

    @Test func maxDepthLimitsRecursion() {
        let root = Self.makeDeeperTree()
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 200)
        let rects = TreemapLayout.layout(root: root, in: bounds, maxDepth: 1)

        // At maxDepth 1: "a" directory rendered as leaf (depth 1) + "b.txt" (depth 1)
        #expect(rects.count == 2)
        #expect(rects.allSatisfy { $0.depth <= 1 })
    }

    // MARK: - Edge cases

    @Test func emptyDirectory() {
        let root = FileNode(name: "empty", kind: .directory, size: 0)
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let rects = TreemapLayout.layout(root: root, in: bounds)

        #expect(rects.isEmpty)
    }

    @Test func singleFile() {
        let root = FileNode(name: "solo.txt", kind: .file, size: 500)
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let rects = TreemapLayout.layout(root: root, in: bounds)

        #expect(rects.count == 1)
        #expect(rects[0].node.name == "solo.txt")
    }

    @Test func zeroSizedChildrenSkipped() {
        let root = FileNode(name: "root", kind: .directory, size: 100, children: [
            FileNode(name: "real.txt", kind: .file, size: 100),
            FileNode(name: "empty.txt", kind: .file, size: 0),
        ])
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let rects = TreemapLayout.layout(root: root, in: bounds)

        // Only the non-zero file should appear
        #expect(rects.count == 1)
        #expect(rects[0].node.name == "real.txt")
    }

    @Test func zeroBoundsReturnsEmpty() {
        let root = FileNode(name: "a", kind: .file, size: 100)
        #expect(TreemapLayout.layout(root: root, in: .zero).isEmpty)
    }

    @Test func manyChildren() {
        let children = (0..<100).map { i in
            FileNode(name: "file_\(i).dat", kind: .file, size: UInt64(i + 1))
        }
        let totalSize = children.reduce(0 as UInt64) { $0 + $1.size }
        let root = FileNode(name: "big", kind: .directory, size: totalSize, children: children)
        let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        let rects = TreemapLayout.layout(root: root, in: bounds)

        #expect(rects.count == 100)

        // No overlapping rects (check centers are unique)
        let centers = rects.map { CGPoint(x: $0.rect.midX, y: $0.rect.midY) }
        let uniqueCenters = Set(centers.map { "\(Int($0.x)),\(Int($0.y))" })
        #expect(uniqueCenters.count == 100)
    }

    // MARK: - Non-overlapping

    @Test func rectsDoNotOverlap() {
        let children = (0..<10).map { i in
            FileNode(name: "f\(i)", kind: .file, size: UInt64((i + 1) * 100))
        }
        let total = children.reduce(0 as UInt64) { $0 + $1.size }
        let root = FileNode(name: "root", kind: .directory, size: total, children: children)
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 300)
        let rects = TreemapLayout.layout(root: root, in: bounds)

        for i in 0..<rects.count {
            for j in (i+1)..<rects.count {
                let a = rects[i].rect.insetBy(dx: 1, dy: 1)
                let b = rects[j].rect.insetBy(dx: 1, dy: 1)
                let intersection = a.intersection(b)
                #expect(intersection.isNull || intersection.width < 2 || intersection.height < 2,
                       "Rects \(rects[i].node.name) and \(rects[j].node.name) overlap")
            }
        }
    }
}
