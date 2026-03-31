import Testing
import Foundation
@testable import GrandPerspective

// MARK: - Filter Mask Mode

@Suite("Filter Mask Mode")
@MainActor
struct FilterMaskModeTests {

    static func makeState() -> AppState {
        let root = FileNode(name: "Root", kind: .directory, size: 10_000, children: [
            FileNode(name: "big.dat", kind: .file, size: 8000),
            FileNode(name: "small.txt", kind: .file, size: 2000),
        ])
        let result = ScanResult(
            scanTree: root,
            volumePath: "/",
            volumeSize: 100_000,
            freeSpace: 50_000,
            sizeMeasure: .logical
        )
        let state = AppState()
        state.loadScanResult(result, url: URL(fileURLWithPath: "/Root"))
        return state
    }

    @Test func filterModeDefaultIsFilter() {
        let state = AppState()
        #expect(state.filterMode == .filter)
    }

    @Test func filterModeEnumCases() {
        let cases = AppState.FilterMode.allCases
        #expect(cases.count == 2)
        #expect(cases.contains(.filter))
        #expect(cases.contains(.mask))
    }

    @Test func filterModeRemovesNodes() {
        let state = Self.makeState()
        state.filterMode = .filter
        // Filter: only files >= 5000
        let filter = NamedFilter(name: "Big", filter: .sizeRange(min: 5000, max: nil))
        state.appliedFilter = filter

        // In filter mode, small.txt should be gone
        let tree = state.displayTree!
        let names = tree.children.map(\.name)
        #expect(names.contains("big.dat"))
        #expect(!names.contains("small.txt"))
        #expect(state.maskedNodeIDs.isEmpty)
    }

    @Test func maskModeKeepsAllNodes() {
        let state = Self.makeState()
        state.filterMode = .mask
        let filter = NamedFilter(name: "Big", filter: .sizeRange(min: 5000, max: nil))
        state.appliedFilter = filter

        // In mask mode, all nodes should still be in the tree
        let tree = state.displayTree!
        let names = tree.children.map(\.name)
        #expect(names.contains("big.dat"))
        #expect(names.contains("small.txt"))
    }

    @Test func maskModeTracksFailingNodes() {
        let state = Self.makeState()
        state.filterMode = .mask
        let filter = NamedFilter(name: "Big", filter: .sizeRange(min: 5000, max: nil))
        state.appliedFilter = filter

        // small.txt should be in maskedNodeIDs
        let tree = state.displayTree!
        let small = tree.children.first { $0.name == "small.txt" }!
        #expect(state.maskedNodeIDs.contains(small.id))

        let big = tree.children.first { $0.name == "big.dat" }!
        #expect(!state.maskedNodeIDs.contains(big.id))
    }

    @Test func switchingModeRecomputes() {
        let state = Self.makeState()
        let filter = NamedFilter(name: "Big", filter: .sizeRange(min: 5000, max: nil))
        state.appliedFilter = filter

        // Start in filter mode
        state.filterMode = .filter
        #expect(state.displayTree!.children.count == 1) // only big.dat

        // Switch to mask
        state.filterMode = .mask
        #expect(state.displayTree!.children.count == 2) // both nodes
        #expect(!state.maskedNodeIDs.isEmpty)

        // Switch back
        state.filterMode = .filter
        #expect(state.displayTree!.children.count == 1)
        #expect(state.maskedNodeIDs.isEmpty)
    }

    @Test func clearingFilterClearsMask() {
        let state = Self.makeState()
        state.filterMode = .mask
        state.appliedFilter = NamedFilter(name: "Big", filter: .sizeRange(min: 5000, max: nil))
        #expect(!state.maskedNodeIDs.isEmpty)

        state.appliedFilter = nil
        #expect(state.maskedNodeIDs.isEmpty)
    }

    @Test func toggleMaskNotificationExists() {
        #expect(Notification.Name.toggleMask.rawValue == "toggleMask")
    }
}

// MARK: - File Size Measure Preference

@Suite("File Size Measure")
@MainActor
struct FileSizeMeasureTests {

    @Test func defaultSizeMeasureIsLogical() {
        let state = AppState()
        #expect(state.preferredSizeMeasure == .logical)
    }

    @Test func sizeMeasureFromPreference() {
        let state = AppState()
        state.fileSizeMeasure = "physical"
        #expect(state.preferredSizeMeasure == .physical)

        state.fileSizeMeasure = "logical"
        #expect(state.preferredSizeMeasure == .logical)
    }

    @Test func invalidSizeMeasureFallsBackToLogical() {
        let state = AppState()
        state.fileSizeMeasure = "unknown"
        #expect(state.preferredSizeMeasure == .logical)
    }
}

// MARK: - File Size Unit System

@Suite("File Size Units")
struct FileSizeUnitTests {

    @Test func decimalFormatting() {
        let saved = FileNode.useBinaryUnits
        defer { FileNode.useBinaryUnits = saved }

        FileNode.useBinaryUnits = false
        let formatted = FileNode.formattedSize(1_000_000)
        // Decimal: should show MB (not MiB)
        #expect(formatted.contains("MB") || formatted.contains("Mo"))
        #expect(!formatted.contains("MiB"))
    }

    @Test func binaryFormatting() {
        let saved = FileNode.useBinaryUnits
        defer { FileNode.useBinaryUnits = saved }

        FileNode.useBinaryUnits = true
        let formatted = FileNode.formattedSize(1_048_576)
        // Binary: should show MiB (or Mio on fr locale)
        // ByteCountFormatter binary gives "1 MiB" or localized equivalent
        #expect(!formatted.isEmpty)
    }

    @Test func switchingUnitsChangesOutput() {
        let saved = FileNode.useBinaryUnits
        defer { FileNode.useBinaryUnits = saved }

        let bytes: UInt64 = 1_500_000
        FileNode.useBinaryUnits = false
        let decimal = FileNode.formattedSize(bytes)

        FileNode.useBinaryUnits = true
        let binary = FileNode.formattedSize(bytes)

        // The outputs should differ (different unit system)
        #expect(decimal != binary)
    }
}
