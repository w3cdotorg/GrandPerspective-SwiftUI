import Testing
import Foundation
@testable import GrandPerspective

// MARK: - Scan Comments Model

@Suite("Scan Comments")
struct ScanCommentsTests {

    static func makeScanResult(comments: String = "") -> ScanResult {
        let tree = FileNode(name: "Root", kind: .directory, size: 1000, children: [
            FileNode(name: "a.txt", kind: .file, size: 1000),
        ])
        return ScanResult(
            scanTree: tree,
            volumePath: "/",
            volumeSize: 10_000,
            freeSpace: 5_000,
            comments: comments
        )
    }

    @Test func commentsDefaultEmpty() {
        let result = Self.makeScanResult()
        #expect(result.comments == "")
    }

    @Test func commentsCanBeSet() {
        let result = Self.makeScanResult()
        result.comments = "First scan of project directory"
        #expect(result.comments == "First scan of project directory")
    }

    @Test func commentsInitWithValue() {
        let result = Self.makeScanResult(comments: "Initial comment")
        #expect(result.comments == "Initial comment")
    }

    @Test func commentsCanBeCleared() {
        let result = Self.makeScanResult(comments: "Some note")
        result.comments = ""
        #expect(result.comments == "")
    }
}

// MARK: - Scan Comments JSON Persistence

@Suite("Scan Comments Persistence")
struct ScanCommentsPersistenceTests {

    @Test func commentsRoundTripJSON() throws {
        let tree = FileNode(name: "Test", kind: .directory, size: 500, children: [
            FileNode(name: "b.txt", kind: .file, size: 500),
        ])
        let result = ScanResult(
            scanTree: tree,
            volumePath: "/",
            volumeSize: 10_000,
            freeSpace: 5_000,
            comments: "This is a test comment with émojis 🎉 and newlines\nLine 2"
        )

        // Encode
        let codable = CodableScanResult(from: result)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(codable)

        // Decode
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CodableScanResult.self, from: data)
        let restored = decoded.toScanResult()

        #expect(restored.comments == "This is a test comment with émojis 🎉 and newlines\nLine 2")
    }

    @Test func emptyCommentsRoundTrip() throws {
        let tree = FileNode(name: "Test", kind: .directory, size: 100, children: [])
        let result = ScanResult(
            scanTree: tree,
            volumePath: "/",
            volumeSize: 10_000,
            freeSpace: 5_000,
            comments: ""
        )

        let codable = CodableScanResult(from: result)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(codable)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CodableScanResult.self, from: data)
        let restored = decoded.toScanResult()

        #expect(restored.comments == "")
    }

    @Test func commentsInCodableJSON() throws {
        let tree = FileNode(name: "X", kind: .directory, size: 0, children: [])
        let result = ScanResult(
            scanTree: tree,
            volumePath: "/",
            volumeSize: 0,
            freeSpace: 0,
            comments: "Hello"
        )

        let codable = CodableScanResult(from: result)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(codable)
        let json = String(data: data, encoding: .utf8)!

        // The JSON should contain the comments field
        #expect(json.contains("\"comments\""))
        #expect(json.contains("Hello"))
    }
}

// MARK: - Edit Scan Comments Notification

@Suite("Scan Comments Notification")
struct ScanCommentsNotificationTests {

    @Test func editScanCommentsNotificationExists() {
        #expect(Notification.Name.editScanComments.rawValue == "editScanComments")
    }
}
