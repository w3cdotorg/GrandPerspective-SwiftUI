import Testing
import SwiftUI
import UniformTypeIdentifiers
@testable import GrandPerspective

@MainActor
@Suite("AppState")
struct AppStateTests {

    // MARK: - Helpers

    static func makeScanResult() -> ScanResult {
        let tree = FileNode(name: "root", kind: .directory, size: 10000, children: [
            FileNode(name: "photos", kind: .directory, size: 6000, children: [
                FileNode(name: "vacation.jpg", kind: .file, size: 4000, type: .jpeg),
                FileNode(name: "cat.png", kind: .file, size: 2000, type: .png),
            ]),
            FileNode(name: "docs", kind: .directory, size: 3000, children: [
                FileNode(name: "readme.md", kind: .file, size: 1000, type: .plainText),
                FileNode(name: "notes.txt", kind: .file, size: 2000, type: .plainText),
            ]),
            FileNode(name: "config.json", kind: .file, size: 1000),
        ])
        return ScanResult(
            scanTree: tree,
            volumePath: "/",
            volumeSize: 100_000,
            freeSpace: 50_000
        )
    }

    // MARK: - Initial state

    @Test func initialState() {
        let state = AppState()
        #expect(state.scanPhase == .idle)
        #expect(state.scanResult == nil)
        #expect(state.hoveredNode == nil)
        #expect(state.zoomRoot == nil)
        #expect(state.appliedFilter == nil)
        #expect(state.displayTree == nil)
        #expect(state.errorMessage == nil)
    }

    // MARK: - Navigation

    @Test func zoomInToDirectory() {
        let state = AppState()
        let result = Self.makeScanResult()
        state.scanResult = result
        state.scanPhase = .completed

        let photos = result.scanTree.children.first { $0.name == "photos" }!
        state.zoomIn(to: photos)
        #expect(state.zoomRoot === photos)
    }

    @Test func zoomInIgnoresFiles() {
        let state = AppState()
        let result = Self.makeScanResult()
        state.scanResult = result
        state.scanPhase = .completed

        let file = result.scanTree.children.first { $0.name == "config.json" }!
        state.zoomIn(to: file)
        #expect(state.zoomRoot == nil)
    }

    @Test func zoomOutNavigatesToParent() {
        let state = AppState()
        let result = Self.makeScanResult()
        state.scanResult = result
        state.scanPhase = .completed

        let photos = result.scanTree.children.first { $0.name == "photos" }!
        state.zoomRoot = photos
        state.zoomOut()
        // photos.parent == scanTree, which is displayTree → clears to nil
        #expect(state.zoomRoot == nil)
    }

    @Test func zoomOutDoesNothingWhenNil() {
        let state = AppState()
        state.zoomOut()
        #expect(state.zoomRoot == nil)
    }

    @Test func navigateToNode() {
        let state = AppState()
        let result = Self.makeScanResult()
        state.scanResult = result
        state.scanPhase = .completed

        let docs = result.scanTree.children.first { $0.name == "docs" }!
        state.navigateTo(docs)
        #expect(state.zoomRoot === docs)

        state.navigateTo(nil)
        #expect(state.zoomRoot == nil)
    }

    // MARK: - Filtering

    @Test func applyFilterCreatesFilteredTree() {
        let state = AppState()
        let result = Self.makeScanResult()
        state.scanResult = result
        state.scanPhase = .completed

        // Filter: only JPEG files
        let filter = NamedFilter(name: "JPEG only", filter: .typeMatches([.jpeg], strict: false))
        state.appliedFilter = filter

        #expect(state.filteredTree != nil)
        // The filtered tree should only contain vacation.jpg (through photos dir)
        let filteredRoot = state.filteredTree!
        #expect(filteredRoot.name == "root")

        // docs dir should be gone (no JPEG children)
        let childNames = Set(filteredRoot.children.map(\.name))
        #expect(childNames.contains("photos"))
        #expect(!childNames.contains("docs"))
        #expect(!childNames.contains("config.json"))
    }

    @Test func clearFilterRestoresFullTree() {
        let state = AppState()
        let result = Self.makeScanResult()
        state.scanResult = result
        state.scanPhase = .completed

        state.appliedFilter = NamedFilter(name: "test", filter: .typeMatches([.jpeg], strict: false))
        #expect(state.filteredTree != nil)

        state.appliedFilter = nil
        #expect(state.filteredTree == nil)
        #expect(state.displayTree === result.scanTree)
    }

    @Test func filterResetsInvalidZoomRoot() {
        let state = AppState()
        let result = Self.makeScanResult()
        state.scanResult = result
        state.scanPhase = .completed

        // Zoom into docs
        let docs = result.scanTree.children.first { $0.name == "docs" }!
        state.zoomRoot = docs

        // Apply filter that excludes docs (JPEG only)
        state.appliedFilter = NamedFilter(name: "JPEG only", filter: .typeMatches([.jpeg], strict: false))

        // docs is no longer in the filtered tree → zoom should reset
        #expect(state.zoomRoot == nil)
    }

    @Test func displayTreeReflectsFilter() {
        let state = AppState()
        let result = Self.makeScanResult()
        state.scanResult = result
        state.scanPhase = .completed

        #expect(state.displayTree === result.scanTree)

        state.appliedFilter = NamedFilter(name: "test", filter: .typeMatches([.jpeg], strict: false))
        #expect(state.displayTree === state.filteredTree)
        #expect(state.displayTree !== result.scanTree)
    }

    // MARK: - Filter repository integration

    @Test func filterRepositoryIsAccessible() {
        let state = AppState()
        #expect(state.filterRepository.filters.count == NamedFilter.defaults.count)
    }

    // MARK: - Color mapping

    @Test func colorMappingChanges() {
        let state = AppState()
        #expect(state.colorMapping.name == "Files & Folders")

        state.colorMapping = ModificationDateColorMapping()
        #expect(state.colorMapping.name == "Modification Date")
    }

    // MARK: - Cancel scan

    @Test func cancelScanReturnsToIdle() {
        let state = AppState()
        state.scanPhase = .scanning(path: "/tmp")
        state.cancelScan()
        #expect(state.scanPhase == .idle)
    }

    // MARK: - Filtered tree size consistency

    @Test func filteredTreeSizeIsConsistent() {
        let state = AppState()
        let result = Self.makeScanResult()
        state.scanResult = result
        state.scanPhase = .completed

        // Filter: size > 1500
        state.appliedFilter = NamedFilter(name: "big files", filter: .sizeRange(min: 1500, max: nil))

        guard let filtered = state.filteredTree else {
            Issue.record("Expected filtered tree")
            return
        }

        // Root size should equal sum of children
        let childrenSize = filtered.children.reduce(UInt64(0)) { $0 + $1.size }
        #expect(filtered.size == childrenSize)
    }
}

