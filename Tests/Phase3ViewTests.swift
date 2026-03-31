import Testing
import SwiftUI
import UniformTypeIdentifiers
@testable import GrandPerspective

// MARK: - FilterRepository Tests

@Suite("FilterRepository")
struct FilterRepositoryTests {

    @Test func startsWithDefaults() {
        let repo = FilterRepository()
        #expect(repo.filters.count == NamedFilter.defaults.count)
    }

    @Test func addSortsAlphabetically() {
        let repo = FilterRepository(filters: [])
        repo.add(NamedFilter(name: "Zebra", filter: .hardLinked))
        repo.add(NamedFilter(name: "Alpha", filter: .package))
        #expect(repo.filters[0].name == "Alpha")
        #expect(repo.filters[1].name == "Zebra")
    }

    @Test func removeById() {
        let repo = FilterRepository(filters: [])
        let f = NamedFilter(name: "Test", filter: .hardLinked)
        repo.add(f)
        #expect(repo.filters.count == 1)
        repo.remove(id: f.id)
        #expect(repo.filters.isEmpty)
    }

    @Test func replaceById() {
        let repo = FilterRepository(filters: [])
        let original = NamedFilter(name: "Old", filter: .hardLinked)
        repo.add(original)
        let replacement = NamedFilter(name: "New", filter: .package)
        repo.replace(id: original.id, with: replacement)
        #expect(repo.filters.count == 1)
        #expect(repo.filters[0].name == "New")
    }

    @Test func isNameTaken() {
        let repo = FilterRepository(filters: [])
        let f = NamedFilter(name: "Unique", filter: .hardLinked)
        repo.add(f)
        #expect(repo.isNameTaken("Unique"))
        #expect(!repo.isNameTaken("Other"))
        // Excluding self should not count as taken
        #expect(!repo.isNameTaken("Unique", excluding: f.id))
    }

    @Test func filterByName() {
        let repo = FilterRepository()
        let found = repo.filter(named: "No hard-links")
        #expect(found != nil)
        #expect(repo.filter(named: "Nonexistent") == nil)
    }
}

// MARK: - FilterTestRow Tests

@Suite("FilterTestRow")
struct FilterTestRowTests {

    @Test func nameFilterRoundTrip() {
        let filter = FileFilter.nameMatches(["*.log", "*.tmp"], caseSensitive: false)
        let row = FilterTestRow(from: filter)
        #expect(row.testType == .name)
        #expect(row.namePattern.contains("*.log"))
        #expect(!row.caseSensitive)

        let rebuilt = row.toFileFilter()
        #expect(rebuilt != nil)
    }

    @Test func sizeFilterRoundTrip() {
        let filter = FileFilter.sizeRange(min: 1024, max: 1_000_000)
        let row = FilterTestRow(from: filter)
        #expect(row.testType == .size)
        #expect(row.minSize == "1024")
        #expect(row.maxSize == "1000000")

        let rebuilt = row.toFileFilter()
        #expect(rebuilt != nil)
    }

    @Test func invertedFilter() {
        let filter = FileFilter.not(.hardLinked)
        let row = FilterTestRow(from: filter)
        #expect(row.inverted)
        #expect(row.testType == .flags)
    }

    @Test func filesOnlyWrapper() {
        let filter = FileFilter.filesOnly(.nameMatches(["*.txt"], caseSensitive: true))
        let row = FilterTestRow(from: filter)
        #expect(row.targetKind == .files)
        #expect(row.testType == .name)
        #expect(row.caseSensitive)
    }

    @Test func typeFilterRoundTrip() {
        let filter = FileFilter.typeMatches([.jpeg, .png], strict: false)
        let row = FilterTestRow(from: filter)
        #expect(row.testType == .type)
        #expect(row.typeIdentifier.contains("jpeg"))

        let rebuilt = row.toFileFilter()
        #expect(rebuilt != nil)
    }

    @Test func emptyRowReturnsNil() {
        let row = FilterTestRow()
        // Default empty name pattern should produce nil
        #expect(row.toFileFilter() == nil)
    }
}

// MARK: - TypeRankingView Tests

@MainActor
@Suite("TypeRanking")
struct TypeRankingTests {

    static func makeScanResult() -> ScanResult {
        let tree = FileNode(name: "root", kind: .directory, size: 10000, children: [
            FileNode(name: "photo.jpg", kind: .file, size: 4000, type: .jpeg),
            FileNode(name: "photo2.jpg", kind: .file, size: 3000, type: .jpeg),
            FileNode(name: "doc.pdf", kind: .file, size: 2000, type: .pdf),
            FileNode(name: "code.swift", kind: .file, size: 1000, type: .swiftSource),
        ])
        return ScanResult(scanTree: tree, volumePath: "/", volumeSize: 100_000, freeSpace: 50_000)
    }

    @Test func typeStatsComputation() {
        let result = Self.makeScanResult()
        let view = TypeRankingView(scanResult: result)
        // Verify the view renders without crash
        _ = view.body
    }
}

// MARK: - FilterEditorView Tests

@MainActor
@Suite("FilterEditorView")
struct FilterEditorViewTests {

    @Test func decomposesAndFilter() {
        let filter = FileFilter.and([
            .nameMatches(["*.log"], caseSensitive: false),
            .sizeRange(min: 100, max: nil)
        ])
        let rows = FilterEditorView.decompose(filter)
        #expect(rows.count == 2)
        #expect(rows[0].testType == .name)
        #expect(rows[1].testType == .size)
    }

    @Test func decomposesOrFilter() {
        let filter = FileFilter.or([
            .hasFlags(.hardLinked),
            .hasFlags(.package)
        ])
        let rows = FilterEditorView.decompose(filter)
        #expect(rows.count == 2)
    }

    @Test func decomposeSingleFilter() {
        let filter = FileFilter.nameMatches(["test"], caseSensitive: true)
        let rows = FilterEditorView.decompose(filter)
        #expect(rows.count == 1)
        #expect(rows[0].caseSensitive)
    }
}

// MARK: - ScanProgressView Tests

@MainActor
@Suite("ScanProgressView")
struct ScanProgressViewTests {

    @Test func rendersWithoutProgress() {
        var cancelled = false
        let view = ScanProgressView(
            path: "/Users/test/Documents",
            progress: nil,
            onCancel: { cancelled = true }
        )
        _ = view.body
        #expect(!cancelled)
    }

    @Test func rendersWithProgress() {
        let progress = FileSystemScanner.Progress(filesScanned: 1500, totalSize: 50_000_000)
        let view = ScanProgressView(
            path: "/tmp",
            progress: progress,
            onCancel: { }
        )
        _ = view.body
    }
}

// MARK: - ImageExportView Tests

@MainActor
@Suite("ImageExportView")
struct ImageExportViewTests {

    @Test func imageFormatProperties() {
        #expect(ImageExportView.ImageFormat.png.fileExtension == "png")
        #expect(ImageExportView.ImageFormat.tiff.fileExtension == "tiff")
        #expect(ImageExportView.ImageFormat.jpeg.fileExtension == "jpg")
        #expect(ImageExportView.ImageFormat.png.utType == .png)
        #expect(ImageExportView.ImageFormat.tiff.utType == .tiff)
        #expect(ImageExportView.ImageFormat.jpeg.utType == .jpeg)
    }
}

// MARK: - Filter description helper

@Suite("FilterDescription")
struct FilterDescriptionTests {

    @Test func describesNameFilter() {
        let desc = describeFilter(.nameMatches(["*.log"], caseSensitive: false))
        #expect(desc.contains("*.log"))
    }

    @Test func describesSizeFilter() {
        let desc = describeFilter(.sizeRange(min: 1024, max: 1_000_000))
        #expect(desc.contains("Size"))
    }

    @Test func describesNotFilter() {
        let desc = describeFilter(.not(.hardLinked))
        #expect(desc.contains("NOT"))
    }

    @Test func describesAndFilter() {
        let desc = describeFilter(.and([.hardLinked, .package]))
        #expect(desc.contains("AND"))
    }
}
