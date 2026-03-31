import Testing
import Foundation
@testable import GrandPerspective

@Suite("FileSystemScanner")
struct FileSystemScannerTests {

    // MARK: - Helpers

    /// Creates a temporary directory with known structure for scanning.
    static func makeTempTree() throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GPTest_\(UUID().uuidString)")
        let fm = FileManager.default

        // root/
        //   file_a.txt  (13 bytes)
        //   subdir/
        //     file_b.txt (5 bytes)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        try fm.createDirectory(at: tmp.appendingPathComponent("subdir"), withIntermediateDirectories: true)
        try "Hello, World!".write(to: tmp.appendingPathComponent("file_a.txt"), atomically: true, encoding: .utf8)
        try "12345".write(to: tmp.appendingPathComponent("subdir/file_b.txt"), atomically: true, encoding: .utf8)

        return tmp
    }

    static func cleanUp(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Tests

    @Test func scanProducesTree() async throws {
        let tmp = try Self.makeTempTree()
        defer { Self.cleanUp(tmp) }

        let scanner = FileSystemScanner(sizeMeasure: .logical)
        let root = try await scanner.scan(url: tmp)

        #expect(root.isDirectory)
        #expect(root.children.count == 2)

        let fileA = root.children.first { $0.name == "file_a.txt" }
        #expect(fileA != nil)
        #expect(!fileA!.isDirectory)
        #expect(fileA!.size == 13)

        let subdir = root.children.first { $0.name == "subdir" }
        #expect(subdir != nil)
        #expect(subdir!.isDirectory)
        #expect(subdir!.children.count == 1)

        let fileB = subdir!.children.first { $0.name == "file_b.txt" }
        #expect(fileB != nil)
        #expect(fileB!.size == 5)
    }

    @Test func scanSetsSizes() async throws {
        let tmp = try Self.makeTempTree()
        defer { Self.cleanUp(tmp) }

        let scanner = FileSystemScanner(sizeMeasure: .logical)
        let root = try await scanner.scan(url: tmp)

        // Root size should be sum of all files
        #expect(root.size == 18) // 13 + 5

        let subdir = root.children.first { $0.name == "subdir" }!
        #expect(subdir.size == 5)
    }

    @Test func scanSetsParentReferences() async throws {
        let tmp = try Self.makeTempTree()
        defer { Self.cleanUp(tmp) }

        let scanner = FileSystemScanner(sizeMeasure: .logical)
        let root = try await scanner.scan(url: tmp)

        for child in root.children {
            #expect(child.parent === root)
        }

        let subdir = root.children.first { $0.name == "subdir" }!
        for child in subdir.children {
            #expect(child.parent === subdir)
        }
    }

    @Test func scanSetsDates() async throws {
        let tmp = try Self.makeTempTree()
        defer { Self.cleanUp(tmp) }

        let scanner = FileSystemScanner(sizeMeasure: .logical)
        let root = try await scanner.scan(url: tmp)

        let fileA = root.children.first { $0.name == "file_a.txt" }!
        #expect(fileA.creationDate != nil)
        #expect(fileA.modificationDate != nil)
    }

    @Test func scanEmptyDirectory() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GPTest_empty_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { Self.cleanUp(tmp) }

        let scanner = FileSystemScanner(sizeMeasure: .logical)
        let root = try await scanner.scan(url: tmp)

        #expect(root.isDirectory)
        #expect(root.children.isEmpty)
        #expect(root.size == 0)
    }

    @Test func cancellation() async throws {
        // Create a bigger tree so there's time to cancel mid-scan
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GPTest_cancel_\(UUID().uuidString)")
        let fm = FileManager.default
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        for i in 0..<50 {
            let subdir = tmp.appendingPathComponent("dir_\(i)")
            try fm.createDirectory(at: subdir, withIntermediateDirectories: true)
            for j in 0..<10 {
                try "data".write(to: subdir.appendingPathComponent("f\(j).txt"), atomically: true, encoding: .utf8)
            }
        }
        defer { Self.cleanUp(tmp) }

        let scanner = FileSystemScanner(sizeMeasure: .logical)

        // Cancel almost immediately from a concurrent task
        async let result: FileNode = scanner.scan(url: tmp)
        try? await Task.sleep(for: .milliseconds(1))
        await scanner.cancel()

        do {
            _ = try await result
            // If scan completed before cancel, that's also acceptable
        } catch is CancellationError {
            // Expected: scan was cancelled
        }
    }
}
