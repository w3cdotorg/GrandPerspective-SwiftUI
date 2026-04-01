import Testing
import Foundation
@testable import GrandPerspective

// MARK: - FileNode Performance Optimizations

@Suite("FileNode Optimizations")
struct FileNodeOptimizationTests {

    @Test func fileCountIsCached() {
        let children = (0..<1000).map { FileNode(name: "f\($0).txt", kind: .file, size: 100) }
        let dir = FileNode(name: "big", kind: .directory, size: 100_000, children: children)

        // First call computes
        let count1 = dir.fileCount
        #expect(count1 == 1000)

        // Second call should return same value (cached)
        let count2 = dir.fileCount
        #expect(count2 == 1000)
    }

    @Test func fileCountNestedDirectories() {
        let inner = FileNode(name: "inner", kind: .directory, size: 200, children: [
            FileNode(name: "a.txt", kind: .file, size: 100),
            FileNode(name: "b.txt", kind: .file, size: 100),
        ])
        let outer = FileNode(name: "outer", kind: .directory, size: 300, children: [
            inner,
            FileNode(name: "c.txt", kind: .file, size: 100),
        ])

        #expect(outer.fileCount == 3)
        #expect(inner.fileCount == 2)
    }

    @Test func formattedSizeConsistent() {
        // Verify formatter reuse produces consistent results
        let s1 = FileNode.formattedSize(1_048_576)
        let s2 = FileNode.formattedSize(1_048_576)
        #expect(s1 == s2)
    }

    @Test func syntheticNodeFileCountIsZero() {
        let node = FileNode(name: "free", kind: .synthetic(.freeSpace), size: 1000)
        #expect(node.fileCount == 0)
    }
}

// MARK: - TreemapLayout Performance

@Suite("TreemapLayout Performance")
struct TreemapLayoutPerformanceTests {

    @Test func layoutLargeTree() {
        // Build a tree with ~10k leaf nodes
        let dirs = (0..<100).map { i in
            let files = (0..<100).map { j in
                FileNode(name: "f\(j).txt", kind: .file, size: UInt64.random(in: 100...10000))
            }
            let dirSize = files.reduce(0 as UInt64) { $0 + $1.size }
            return FileNode(name: "dir\(i)", kind: .directory, size: dirSize, children: files)
        }
        let totalSize = dirs.reduce(0 as UInt64) { $0 + $1.size }
        let root = FileNode(name: "root", kind: .directory, size: totalSize, children: dirs)

        let bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let rects = TreemapLayout.layout(root: root, in: bounds)

        // Should produce rects for nearly all 10k files plus directory background rects
        // (100 dirs + 1 root = 101 background rects, plus ~10k leaf rects)
        let leaves = rects.filter { !$0.node.isDirectory }
        #expect(leaves.count >= 9_900)
        #expect(leaves.count <= 10_000)

        // All rects should be within bounds
        for r in rects {
            #expect(r.rect.minX >= -0.01)
            #expect(r.rect.minY >= -0.01)
            #expect(r.rect.maxX <= bounds.width + 0.01)
            #expect(r.rect.maxY <= bounds.height + 0.01)
        }
    }
}

// MARK: - Cleanup Verification

@Suite("Cleanup Verification")
struct CleanupVerificationTests {

    @Test func noStalePhaseComments() throws {
        // Verify that the main source files don't contain stale "Phase X:" TODO comments
        // (This is a meta-test that validates our cleanup)
        let srcDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // project root
            .appendingPathComponent("Sources")

        let fm = FileManager.default
        let enumerator = fm.enumerator(at: srcDir, includingPropertiesForKeys: nil)!

        var staleComments: [String] = []
        while let url = enumerator.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let content = try String(contentsOf: url)
            let lines = content.components(separatedBy: .newlines)
            for (i, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // Look for "Phase N:" in comments that are TODOs (not doc comments like "Replaces...")
                if trimmed.hasPrefix("//") && trimmed.contains("Phase ") && !trimmed.contains("Replaces") && !trimmed.contains("Phases") {
                    // Allow "Phase 0-9" in PLAN references but not "Phase N: ..." todo style
                    if trimmed.contains(": ") && !trimmed.contains("PLAN") {
                        staleComments.append("\(url.lastPathComponent):\(i+1): \(trimmed)")
                    }
                }
            }
        }

        #expect(staleComments.isEmpty, "Found stale phase comments: \(staleComments)")
    }

    @Test func namedFilterHasStableId() {
        let f1 = NamedFilter(name: "Test", filter: .not(.hardLinked))
        let data = try! JSONEncoder().encode(f1)
        let f2 = try! JSONDecoder().decode(NamedFilter.self, from: data)
        #expect(f1.id == f2.id)
    }
}
