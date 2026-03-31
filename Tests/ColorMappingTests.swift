import Testing
import SwiftUI
import UniformTypeIdentifiers
@testable import GrandPerspective

@Suite("ColorMapping")
struct ColorMappingTests {

    // MARK: - Helpers

    static let textFile = FileNode(
        name: "readme.txt", kind: .file, size: 100,
        creationDate: Date.now.addingTimeInterval(-86400 * 30), // 30 days ago
        modificationDate: Date.now.addingTimeInterval(-86400), // 1 day ago
        accessDate: Date.now.addingTimeInterval(-3600), // 1 hour ago
        type: .plainText
    )

    static let movieFile = FileNode(
        name: "video.mp4", kind: .file, size: 5000,
        modificationDate: Date.now.addingTimeInterval(-86400 * 365), // 1 year ago
        type: .mpeg4Movie
    )

    static let noDateFile = FileNode(name: "mystery", kind: .file, size: 50)

    // MARK: - FolderColorMapping

    @Test func folderMappingReturnsDifferentColorsForDifferentDepths() {
        let mapping = FolderColorMapping()
        let c0 = mapping.color(for: Self.textFile, depth: 0)
        let c1 = mapping.color(for: Self.textFile, depth: 1)
        // Different depths should give different colors
        #expect(c0 != c1)
    }

    @Test func folderMappingWrapsAround() {
        let mapping = FolderColorMapping()
        let paletteSize = FolderColorMapping.defaultPalette.count
        let c0 = mapping.color(for: Self.textFile, depth: 0)
        let cWrapped = mapping.color(for: Self.textFile, depth: paletteSize)
        #expect(c0 == cWrapped)
    }

    // MARK: - ModificationDateColorMapping

    @Test func modificationDateReturnsColor() {
        let mapping = ModificationDateColorMapping()
        let color = mapping.color(for: Self.textFile, depth: 0)
        // Should not be gray (since we have a date)
        #expect(color != Color.gray)
    }

    @Test func modificationDateGrayForNoDate() {
        let mapping = ModificationDateColorMapping()
        let color = mapping.color(for: Self.noDateFile, depth: 0)
        #expect(color == Color.gray)
    }

    @Test func modificationDateOlderFilesDifferFromNewer() {
        let mapping = ModificationDateColorMapping()
        let recentColor = mapping.color(for: Self.textFile, depth: 0) // 1 day old
        let oldColor = mapping.color(for: Self.movieFile, depth: 0)   // 1 year old
        #expect(recentColor != oldColor)
    }

    // MARK: - CreationDateColorMapping

    @Test func creationDateReturnsColor() {
        let mapping = CreationDateColorMapping()
        let color = mapping.color(for: Self.textFile, depth: 0)
        #expect(color != Color.gray)
    }

    @Test func creationDateGrayForNoDate() {
        let mapping = CreationDateColorMapping()
        let color = mapping.color(for: Self.noDateFile, depth: 0)
        #expect(color == Color.gray)
    }

    // MARK: - AccessDateColorMapping

    @Test func accessDateReturnsColor() {
        let mapping = AccessDateColorMapping()
        let color = mapping.color(for: Self.textFile, depth: 0)
        #expect(color != Color.gray)
    }

    // MARK: - FileTypeColorMapping

    @Test func fileTypeTextMapping() {
        let mapping = FileTypeColorMapping()
        let color = mapping.color(for: Self.textFile, depth: 0)
        // Text files should get the .mint color
        #expect(color == .mint)
    }

    @Test func fileTypeMovieMapping() {
        let mapping = FileTypeColorMapping()
        let color = mapping.color(for: Self.movieFile, depth: 0)
        // Movies should get the .purple color
        #expect(color == .purple)
    }

    @Test func fileTypeNoTypeReturnsFallback() {
        let mapping = FileTypeColorMapping()
        let color = mapping.color(for: Self.noDateFile, depth: 0)
        #expect(color == .secondary)
    }

    // MARK: - Registry

    @Test func registryContainsAllMappings() {
        let all = ColorMappings.all
        #expect(all.count == 5)
        #expect(all.contains { $0.name == "Files & Folders" })
        #expect(all.contains { $0.name == "Modification Date" })
        #expect(all.contains { $0.name == "Creation Date" })
        #expect(all.contains { $0.name == "Access Date" })
        #expect(all.contains { $0.name == "File Type (UTI)" })
    }

    @Test func registryLookupByName() {
        let found = ColorMappings.named("Files & Folders")
        #expect(found != nil)
        #expect(found!.name == "Files & Folders")

        let notFound = ColorMappings.named("Nonexistent")
        #expect(notFound == nil)
    }

    // MARK: - Protocol conformance

    @Test func legendCapability() {
        #expect(!FolderColorMapping().canProvideLegend)
        #expect(ModificationDateColorMapping().canProvideLegend)
        #expect(FileTypeColorMapping().canProvideLegend)
    }
}
