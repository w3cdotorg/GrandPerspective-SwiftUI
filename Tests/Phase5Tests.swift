import Testing
import Foundation
import SwiftUI
import UniformTypeIdentifiers
@testable import GrandPerspective

// MARK: - CodableNode Tests

@Suite("CodableNode")
struct CodableNodeTests {

    static func makeSampleTree() -> FileNode {
        FileNode(name: "root", kind: .directory, size: 6000, children: [
            FileNode(name: "photo.jpg", kind: .file, size: 4000,
                     creationDate: Date(timeIntervalSince1970: 1_000_000),
                     modificationDate: Date(timeIntervalSince1970: 1_100_000),
                     type: .jpeg),
            FileNode(name: "readme.md", kind: .file, size: 1000,
                     flags: .hardLinked,
                     type: .plainText),
            FileNode(name: "sub", kind: .directory, size: 1000, children: [
                FileNode(name: "nested.txt", kind: .file, size: 1000, type: .plainText),
            ]),
        ])
    }

    @Test func roundTripPreservesTree() {
        let original = Self.makeSampleTree()
        let codable = CodableNode(from: original)
        let restored = codable.toFileNode()

        #expect(restored.name == "root")
        #expect(restored.isDirectory)
        #expect(restored.size == 6000)
        #expect(restored.children.count == 3)
    }

    @Test func roundTripPreservesFileProperties() {
        let original = Self.makeSampleTree()
        let codable = CodableNode(from: original)
        let restored = codable.toFileNode()

        let photo = restored.children.first { $0.name == "photo.jpg" }!
        #expect(photo.size == 4000)
        #expect(photo.type == .jpeg)
        #expect(photo.creationDate != nil)
        #expect(photo.modificationDate != nil)
    }

    @Test func roundTripPreservesFlags() {
        let original = Self.makeSampleTree()
        let codable = CodableNode(from: original)
        let restored = codable.toFileNode()

        let readme = restored.children.first { $0.name == "readme.md" }!
        #expect(readme.flags.contains(.hardLinked))
    }

    @Test func roundTripPreservesNesting() {
        let original = Self.makeSampleTree()
        let codable = CodableNode(from: original)
        let restored = codable.toFileNode()

        let sub = restored.children.first { $0.name == "sub" }!
        #expect(sub.isDirectory)
        #expect(sub.children.count == 1)
        #expect(sub.children[0].name == "nested.txt")
    }

    @Test func parentRefsRebuilt() {
        let original = Self.makeSampleTree()
        let codable = CodableNode(from: original)
        let restored = codable.toFileNode()

        for child in restored.children {
            #expect(child.parent === restored)
        }
        let sub = restored.children.first { $0.name == "sub" }!
        #expect(sub.children[0].parent === sub)
    }

    @Test func syntheticNodeRoundTrip() {
        let node = FileNode(name: "Free Space", kind: .synthetic(.freeSpace), size: 50000)
        let codable = CodableNode(from: node)
        let restored = codable.toFileNode()

        #expect(restored.name == "Free Space")
        if case .synthetic(let role) = restored.kind {
            #expect(role == .freeSpace)
        } else {
            Issue.record("Expected synthetic kind")
        }
    }

    @Test func jsonEncodeDecode() throws {
        let original = Self.makeSampleTree()
        let codable = CodableNode(from: original)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(codable)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CodableNode.self, from: data)

        let restored = decoded.toFileNode()
        #expect(restored.name == "root")
        #expect(restored.children.count == 3)
    }
}

// MARK: - CodableScanResult Tests

@Suite("CodableScanResult")
struct CodableScanResultTests {

    @Test func roundTrip() throws {
        let tree = FileNode(name: "mydir", kind: .directory, size: 5000, children: [
            FileNode(name: "a.txt", kind: .file, size: 3000, type: .plainText),
            FileNode(name: "b.jpg", kind: .file, size: 2000, type: .jpeg),
        ])
        let original = ScanResult(
            scanTree: tree,
            volumePath: "/Volumes/Data",
            volumeSize: 500_000_000,
            freeSpace: 200_000_000,
            sizeMeasure: .logical,
            comments: "Test scan"
        )

        let codable = CodableScanResult(from: original)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(codable)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CodableScanResult.self, from: data)
        let restored = decoded.toScanResult()

        #expect(restored.scanTree.name == "mydir")
        #expect(restored.volumePath == "/Volumes/Data")
        #expect(restored.volumeSize == 500_000_000)
        #expect(restored.freeSpace == 200_000_000)
        #expect(restored.sizeMeasure == .logical)
        #expect(restored.comments == "Test scan")
        #expect(restored.scanTree.children.count == 2)
    }

    @Test func formatVersion() {
        let tree = FileNode(name: "r", kind: .directory, size: 0)
        let result = ScanResult(scanTree: tree, volumePath: "/", volumeSize: 0, freeSpace: 0)
        let codable = CodableScanResult(from: result)
        #expect(codable.formatVersion == 2)
    }

    @Test func physicalSizeMeasure() throws {
        let tree = FileNode(name: "r", kind: .directory, size: 0)
        let result = ScanResult(scanTree: tree, volumePath: "/", volumeSize: 0, freeSpace: 0, sizeMeasure: .physical)
        let codable = CodableScanResult(from: result)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(codable)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CodableScanResult.self, from: data)
        let restored = decoded.toScanResult()
        #expect(restored.sizeMeasure == .physical)
    }
}

// MARK: - ScanDocument Tests

@Suite("ScanDocument")
struct ScanDocumentTests {

    @Test func endToEndJsonRoundTrip() throws {
        let tree = FileNode(name: "test", kind: .directory, size: 1000, children: [
            FileNode(name: "file.txt", kind: .file, size: 1000, type: .plainText),
        ])
        let result = ScanResult(scanTree: tree, volumePath: "/", volumeSize: 100_000, freeSpace: 50_000)

        // Encode
        let codable = CodableScanResult(from: result)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(codable)

        // Verify JSON is valid and contains expected keys
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"volumePath\""))
        #expect(json.contains("\"formatVersion\""))
        #expect(json.contains("\"test\""))

        // Decode
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CodableScanResult.self, from: data)
        let restored = decoded.toScanResult()

        #expect(restored.scanTree.name == "test")
        #expect(restored.scanTree.children.count == 1)
        #expect(restored.volumeSize == 100_000)
    }

    @Test func readableContentTypes() {
        #expect(ScanDocument.readableContentTypes.contains(.gpscan))
        #expect(ScanDocument.readableContentTypes.contains(.json))
    }

    @Test func writableContentTypes() {
        #expect(ScanDocument.writableContentTypes.contains(.gpscan))
    }
}

// MARK: - UTType extension

@Suite("UTType Extension")
struct UTTypeExtensionTests {

    @Test func gpscanTypeExists() {
        #expect(UTType.gpscan.identifier == "net.sourceforge.grandperspectiv.gpscan")
    }
}

// MARK: - Drag & Drop (AppState)

@MainActor
@Suite("AppState DragDrop")
struct AppStateDragDropTests {

    @Test func handleDropWithDirectory() {
        let state = AppState()
        // We can't easily test with a real directory, but we can test the false path
        let result = state.handleDrop(urls: [])
        #expect(!result)
    }

    @Test func handleDropWithNonexistentPath() {
        let state = AppState()
        let fakeURL = URL(fileURLWithPath: "/nonexistent/path/\(UUID())")
        let result = state.handleDrop(urls: [fakeURL])
        #expect(!result)
    }
}
