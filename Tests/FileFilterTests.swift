import Testing
import Foundation
import UniformTypeIdentifiers
@testable import GrandPerspective

@Suite("FileFilter")
struct FileFilterTests {

    // MARK: - Helpers

    static let smallFile = FileNode(name: "tiny.txt", kind: .file, size: 100, type: .plainText)
    static let bigFile = FileNode(name: "video.mp4", kind: .file, size: 5_000_000, type: .mpeg4Movie)
    static let dir = FileNode(name: "docs", kind: .directory, size: 300)
    static let hardLinked = FileNode(name: "link.dat", kind: .file, size: 50, flags: .hardLinked)
    static let pkg = FileNode(name: "App.app", kind: .directory, size: 1000, flags: .package)

    // MARK: - Size range

    @Test func sizeRangeMinOnly() {
        let filter = FileFilter.sizeRange(min: 200, max: nil)
        #expect(filter.test(Self.smallFile) == .failed)
        #expect(filter.test(Self.bigFile) == .passed)
    }

    @Test func sizeRangeMaxOnly() {
        let filter = FileFilter.sizeRange(min: nil, max: 1000)
        #expect(filter.test(Self.smallFile) == .passed)
        #expect(filter.test(Self.bigFile) == .failed)
    }

    @Test func sizeRangeBoth() {
        let filter = FileFilter.sizeRange(min: 50, max: 200)
        #expect(filter.test(Self.smallFile) == .passed)
        #expect(filter.test(Self.bigFile) == .failed)
    }

    @Test func sizeRangeUnbounded() {
        let filter = FileFilter.sizeRange(min: nil, max: nil)
        #expect(filter.test(Self.smallFile) == .passed)
        #expect(filter.test(Self.bigFile) == .passed)
    }

    // MARK: - Name matches

    @Test func nameMatchesExact() {
        let filter = FileFilter.nameMatches(["tiny.txt"], caseSensitive: true)
        #expect(filter.test(Self.smallFile) == .passed)
        #expect(filter.test(Self.bigFile) == .failed)
    }

    @Test func nameMatchesCaseInsensitive() {
        let filter = FileFilter.nameMatches(["TINY.TXT"], caseSensitive: false)
        #expect(filter.test(Self.smallFile) == .passed)
    }

    @Test func nameMatchesCaseSensitiveFails() {
        let filter = FileFilter.nameMatches(["TINY.TXT"], caseSensitive: true)
        #expect(filter.test(Self.smallFile) == .failed)
    }

    // MARK: - Type matches

    @Test func typeMatchesConformance() {
        let filter = FileFilter.typeMatches([.movie], strict: false)
        #expect(filter.test(Self.bigFile) == .passed)
        #expect(filter.test(Self.smallFile) == .failed)
    }

    @Test func typeMatchesStrict() {
        let filter = FileFilter.typeMatches([.mpeg4Movie], strict: true)
        #expect(filter.test(Self.bigFile) == .passed)

        let looseFilter = FileFilter.typeMatches([.movie], strict: true)
        // .mpeg4Movie != .movie (strict), so should fail
        #expect(looseFilter.test(Self.bigFile) == .failed)
    }

    @Test func typeMatchesNoType() {
        let noType = FileNode(name: "unknown", kind: .file, size: 10)
        let filter = FileFilter.typeMatches([.plainText], strict: false)
        #expect(filter.test(noType) == .notApplicable)
    }

    // MARK: - Flags

    @Test func hasFlags() {
        let filter = FileFilter.hasFlags(.hardLinked)
        #expect(filter.test(Self.hardLinked) == .passed)
        #expect(filter.test(Self.smallFile) == .failed)
    }

    @Test func lacksFlags() {
        let filter = FileFilter.lacksFlags(.hardLinked)
        #expect(filter.test(Self.smallFile) == .passed)
        #expect(filter.test(Self.hardLinked) == .failed)
    }

    @Test func packageFlag() {
        #expect(FileFilter.package.test(Self.pkg) == .passed)
        #expect(FileFilter.package.test(Self.dir) == .failed)
    }

    // MARK: - Combinators

    @Test func andAllPass() {
        let filter = FileFilter.and([
            .sizeRange(min: nil, max: 200),
            .nameMatches(["tiny.txt"], caseSensitive: true),
        ])
        #expect(filter.test(Self.smallFile) == .passed)
    }

    @Test func andOneFails() {
        let filter = FileFilter.and([
            .sizeRange(min: 1000, max: nil), // fails for smallFile
            .nameMatches(["tiny.txt"], caseSensitive: true),
        ])
        #expect(filter.test(Self.smallFile) == .failed)
    }

    @Test func orOnePasses() {
        let filter = FileFilter.or([
            .sizeRange(min: 1000, max: nil), // fails
            .nameMatches(["tiny.txt"], caseSensitive: true), // passes
        ])
        #expect(filter.test(Self.smallFile) == .passed)
    }

    @Test func orAllFail() {
        let filter = FileFilter.or([
            .sizeRange(min: 1000, max: nil),
            .nameMatches(["nope"], caseSensitive: true),
        ])
        #expect(filter.test(Self.smallFile) == .failed)
    }

    @Test func not() {
        let filter = FileFilter.not(.hasFlags(.hardLinked))
        #expect(filter.test(Self.smallFile) == .passed)
        #expect(filter.test(Self.hardLinked) == .failed)
    }

    @Test func notPreservesNotApplicable() {
        let noType = FileNode(name: "x", kind: .file, size: 1)
        let filter = FileFilter.not(.typeMatches([.plainText], strict: false))
        #expect(filter.test(noType) == .notApplicable)
    }

    // MARK: - Selective

    @Test func filesOnly() {
        let filter = FileFilter.filesOnly(.sizeRange(min: nil, max: 200))
        #expect(filter.test(Self.smallFile) == .passed)
        #expect(filter.test(Self.dir) == .notApplicable)
    }

    @Test func directoriesOnly() {
        let filter = FileFilter.directoriesOnly(.sizeRange(min: nil, max: 500))
        #expect(filter.test(Self.dir) == .passed)
        #expect(filter.test(Self.smallFile) == .notApplicable)
    }

    // MARK: - passes() convenience

    @Test func passesConvenience() {
        let filter = FileFilter.sizeRange(min: nil, max: 200)
        #expect(filter.passes(Self.smallFile))
        #expect(!filter.passes(Self.bigFile))
    }

    // MARK: - Default filters

    @Test func defaultFiltersExist() {
        #expect(NamedFilter.defaults.count >= 2)
        #expect(NamedFilter.defaults.contains { $0.name == "No hard-links" })
        #expect(NamedFilter.defaults.contains { $0.name == "No version control" })
    }

    @Test func noHardLinksFilter() {
        let filter = NamedFilter.defaults.first { $0.name == "No hard-links" }!.filter
        #expect(filter.passes(Self.smallFile))
        #expect(!filter.passes(Self.hardLinked))
    }
}
