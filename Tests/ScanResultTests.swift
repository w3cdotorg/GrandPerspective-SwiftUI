import Testing
import Foundation
@testable import GrandPerspective

@Suite("ScanResult")
struct ScanResultTests {

    static func makeScanResult() -> ScanResult {
        let tree = FileNode(name: "src", kind: .directory, size: 1000, children: [
            FileNode(name: "a.swift", kind: .file, size: 600),
            FileNode(name: "b.swift", kind: .file, size: 400),
        ])
        return ScanResult(
            scanTree: tree,
            volumePath: "/",
            volumeSize: 500_000_000_000,
            freeSpace: 200_000_000_000,
            sizeMeasure: .logical
        )
    }

    @Test func usedSpace() {
        let result = Self.makeScanResult()
        #expect(result.usedSpace == 300_000_000_000)
    }

    @Test func miscUsedSpace() {
        let result = Self.makeScanResult()
        // misc = usedSpace - scanTree.size = 300B - 1000
        #expect(result.miscUsedSpace == 300_000_000_000 - 1000)
    }

    @Test func deletionTracking() {
        let result = Self.makeScanResult()
        let node = result.scanTree.children[0]

        #expect(result.freedSpace == 0)
        #expect(result.freedFiles == 0)

        result.recordDeletion(of: node)

        #expect(result.freedSpace == 600)
        #expect(result.freedFiles == 1)
    }

    @Test func deletionTrackingDirectory() {
        let tree = FileNode(name: "root", kind: .directory, size: 300, children: [
            FileNode(name: "sub", kind: .directory, size: 300, children: [
                FileNode(name: "x.txt", kind: .file, size: 100),
                FileNode(name: "y.txt", kind: .file, size: 200),
            ]),
        ])
        let result = ScanResult(
            scanTree: tree,
            volumePath: "/",
            volumeSize: 1000,
            freeSpace: 500
        )

        let sub = tree.children[0]
        result.recordDeletion(of: sub)

        #expect(result.freedSpace == 300)
        #expect(result.freedFiles == 2)
    }

    @Test func deletionIgnoresSynthetic() {
        let tree = FileNode(name: "root", kind: .directory, size: 100, children: [
            FileNode(name: "free", kind: .synthetic(.freeSpace), size: 999),
            FileNode(name: "real.txt", kind: .file, size: 100),
        ])
        let result = ScanResult(
            scanTree: tree,
            volumePath: "/",
            volumeSize: 1099,
            freeSpace: 999
        )

        let freeNode = tree.children[0]
        result.recordDeletion(of: freeNode)

        #expect(result.freedSpace == 0)
        #expect(result.freedFiles == 0)
    }

    @Test func formattedScanTime() {
        let result = Self.makeScanResult()
        #expect(!result.formattedScanTime.isEmpty)
    }

    @Test func appliedFiltersStoredCorrectly() {
        let tree = FileNode(name: "r", kind: .directory, size: 0)
        let filter = FileFilter.not(.hardLinked)
        let result = ScanResult(
            scanTree: tree,
            volumePath: "/",
            volumeSize: 0,
            freeSpace: 0,
            appliedFilters: [filter]
        )
        #expect(result.appliedFilters.count == 1)
    }
}
