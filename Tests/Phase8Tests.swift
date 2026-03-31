import Testing
import Foundation
import UniformTypeIdentifiers
@testable import GrandPerspective

// MARK: - Date Filter Tests

@Suite("Date Filters")
struct DateFilterTests {

    static let jan1 = Date(timeIntervalSince1970: 1_704_067_200)   // 2024-01-01
    static let jun1 = Date(timeIntervalSince1970: 1_717_200_000)   // 2024-06-01
    static let dec1 = Date(timeIntervalSince1970: 1_733_011_200)   // 2024-12-01

    static func makeNode(creation: Date? = nil, modification: Date? = nil, access: Date? = nil) -> FileNode {
        FileNode(
            name: "test.txt", kind: .file, size: 100,
            creationDate: creation,
            modificationDate: modification,
            accessDate: access
        )
    }

    @Test func creationDateInRange() {
        let filter = FileFilter.creationDateRange(min: Self.jan1, max: Self.dec1)
        let node = Self.makeNode(creation: Self.jun1)
        #expect(filter.test(node) == .passed)
    }

    @Test func creationDateOutOfRange() {
        let filter = FileFilter.creationDateRange(min: Self.jun1, max: Self.dec1)
        let node = Self.makeNode(creation: Self.jan1)
        #expect(filter.test(node) == .failed)
    }

    @Test func creationDateNoDate() {
        let filter = FileFilter.creationDateRange(min: Self.jan1, max: Self.dec1)
        let node = Self.makeNode()
        #expect(filter.test(node) == .notApplicable)
    }

    @Test func modificationDateMinOnly() {
        let filter = FileFilter.modificationDateRange(min: Self.jun1, max: nil)
        let node = Self.makeNode(modification: Self.dec1)
        #expect(filter.test(node) == .passed)

        let early = Self.makeNode(modification: Self.jan1)
        #expect(filter.test(early) == .failed)
    }

    @Test func accessDateMaxOnly() {
        let filter = FileFilter.accessDateRange(min: nil, max: Self.jun1)
        let node = Self.makeNode(access: Self.jan1)
        #expect(filter.test(node) == .passed)

        let late = Self.makeNode(access: Self.dec1)
        #expect(filter.test(late) == .failed)
    }

    @Test func modificationDateExactBoundary() {
        let filter = FileFilter.modificationDateRange(min: Self.jun1, max: Self.jun1)
        let node = Self.makeNode(modification: Self.jun1)
        #expect(filter.test(node) == .passed)
    }
}

// MARK: - FileFilter Codable Tests

@Suite("FileFilter Codable")
struct FileFilterCodableTests {

    private func roundTrip(_ filter: FileFilter) throws -> FileFilter {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(filter)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(FileFilter.self, from: data)
    }

    @Test func sizeRangeRoundTrip() throws {
        let filter = FileFilter.sizeRange(min: 1024, max: 1_000_000)
        let restored = try roundTrip(filter)
        let node = FileNode(name: "f", kind: .file, size: 5000)
        #expect(restored.test(node) == .passed)
        let small = FileNode(name: "f", kind: .file, size: 100)
        #expect(restored.test(small) == .failed)
    }

    @Test func nameMatchesRoundTrip() throws {
        let filter = FileFilter.nameMatches(["*.log", "debug.txt"], caseSensitive: false)
        let restored = try roundTrip(filter)
        let node = FileNode(name: "debug.txt", kind: .file, size: 0)
        #expect(restored.test(node) == .passed)
    }

    @Test func typeMatchesRoundTrip() throws {
        let filter = FileFilter.typeMatches([.jpeg, .png], strict: true)
        let restored = try roundTrip(filter)
        let node = FileNode(name: "photo.jpg", kind: .file, size: 0, type: .jpeg)
        #expect(restored.test(node) == .passed)
    }

    @Test func hasFlagsRoundTrip() throws {
        let filter = FileFilter.hasFlags(.hardLinked)
        let restored = try roundTrip(filter)
        let node = FileNode(name: "f", kind: .file, size: 0, flags: .hardLinked)
        #expect(restored.test(node) == .passed)
    }

    @Test func dateRangeRoundTrip() throws {
        let min = Date(timeIntervalSince1970: 1_700_000_000)
        let filter = FileFilter.modificationDateRange(min: min, max: nil)
        let restored = try roundTrip(filter)
        let node = FileNode(name: "f", kind: .file, size: 0,
                            modificationDate: Date(timeIntervalSince1970: 1_800_000_000))
        #expect(restored.test(node) == .passed)
    }

    @Test func notRoundTrip() throws {
        let filter = FileFilter.not(.hardLinked)
        let restored = try roundTrip(filter)
        let node = FileNode(name: "f", kind: .file, size: 0)
        #expect(restored.test(node) == .passed)
    }

    @Test func andRoundTrip() throws {
        let filter = FileFilter.and([
            .sizeRange(min: 100, max: nil),
            .nameMatches(["a.txt"], caseSensitive: true)
        ])
        let restored = try roundTrip(filter)
        let node = FileNode(name: "a.txt", kind: .file, size: 200)
        #expect(restored.test(node) == .passed)
    }

    @Test func filesOnlyRoundTrip() throws {
        let filter = FileFilter.filesOnly(.sizeRange(min: 0, max: nil))
        let restored = try roundTrip(filter)
        let dir = FileNode(name: "d", kind: .directory, size: 100)
        #expect(restored.test(dir) == .notApplicable)
    }

    @Test func complexNestedRoundTrip() throws {
        let filter = FileFilter.or([
            .filesOnly(.not(.sizeRange(min: nil, max: 100))),
            .directoriesOnly(.nameMatches(["src"], caseSensitive: false))
        ])
        let data = try JSONEncoder().encode(filter)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("filesOnly"))
        #expect(json.contains("directoriesOnly"))

        let restored = try JSONDecoder().decode(FileFilter.self, from: data)
        let bigFile = FileNode(name: "big", kind: .file, size: 200)
        #expect(restored.test(bigFile) == .passed)
    }
}

// MARK: - NamedFilter Codable Tests

@Suite("NamedFilter Codable")
struct NamedFilterCodableTests {

    @Test func roundTrip() throws {
        let original = NamedFilter(name: "Test Filter", filter: .not(.hardLinked))
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let restored = try decoder.decode(NamedFilter.self, from: data)

        #expect(restored.name == "Test Filter")
        #expect(restored.id == original.id)
    }

    @Test func arrayRoundTrip() throws {
        let filters = NamedFilter.defaults
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(filters)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let restored = try decoder.decode([NamedFilter].self, from: data)

        #expect(restored.count == filters.count)
        #expect(restored[0].name == filters[0].name)
    }
}

// MARK: - FilterRepository Persistence Tests

@MainActor
@Suite("FilterRepository Persistence")
struct FilterRepositoryPersistenceTests {

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("gp-test-\(UUID().uuidString)")
            .appendingPathComponent("filters.json")
    }

    @Test func saveAndLoad() throws {
        let url = tempURL()
        let repo = FilterRepository(filters: NamedFilter.defaults, storageURL: url)
        repo.add(NamedFilter(name: "Custom", filter: .sizeRange(min: 1000, max: nil)))

        repo.saveToDisk()

        let repo2 = FilterRepository(filters: [], storageURL: url)
        repo2.loadFromDisk()

        #expect(repo2.filters.count == 3) // 2 defaults + 1 custom
        #expect(repo2.filters.contains { $0.name == "Custom" })

        // Cleanup
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    @Test func loadNonExistentFileKeepsDefaults() {
        let url = tempURL()
        let repo = FilterRepository(storageURL: url)
        repo.loadFromDisk()
        #expect(repo.filters.count == NamedFilter.defaults.count)
    }

    @Test func loadCorruptedFileKeepsDefaults() throws {
        let url = tempURL()
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "not json".data(using: .utf8)!.write(to: url)

        let repo = FilterRepository(storageURL: url)
        repo.loadFromDisk()
        #expect(repo.filters.count == NamedFilter.defaults.count)

        try? FileManager.default.removeItem(at: dir)
    }

    @Test func saveToDiskCreatesDirectory() throws {
        let url = tempURL()
        let repo = FilterRepository(filters: NamedFilter.defaults, storageURL: url)
        repo.saveToDisk()

        #expect(FileManager.default.fileExists(atPath: url.path))

        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}

// MARK: - Date FilterTestRow round-trip

@Suite("Date FilterTestRow")
struct DateFilterTestRowTests {

    @Test func creationDateRoundTrip() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let filter = FileFilter.creationDateRange(min: date, max: nil)
        let row = FilterTestRow(from: filter)

        #expect(row.testType == .date)
        #expect(row.dateField == .creation)
        #expect(row.minDate == date)
        #expect(row.maxDate == nil)

        let restored = row.toFileFilter()
        #expect(restored != nil)
        let node = FileNode(name: "f", kind: .file, size: 0,
                            creationDate: Date(timeIntervalSince1970: 1_800_000_000))
        #expect(restored!.test(node) == .passed)
    }

    @Test func modificationDateRoundTrip() {
        let min = Date(timeIntervalSince1970: 1_600_000_000)
        let max = Date(timeIntervalSince1970: 1_700_000_000)
        let filter = FileFilter.modificationDateRange(min: min, max: max)
        let row = FilterTestRow(from: filter)

        #expect(row.testType == .date)
        #expect(row.dateField == .modification)
        #expect(row.minDate == min)
        #expect(row.maxDate == max)
    }

    @Test func accessDateRoundTrip() {
        let filter = FileFilter.accessDateRange(min: nil, max: Date())
        let row = FilterTestRow(from: filter)

        #expect(row.testType == .date)
        #expect(row.dateField == .access)
    }

    @Test func dateRowWithNoDatesReturnsNil() {
        var row = FilterTestRow()
        row.testType = .date
        row.minDate = nil
        row.maxDate = nil
        #expect(row.toFileFilter() == nil)
    }
}
