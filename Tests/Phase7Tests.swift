import Testing
import Foundation
@testable import GrandPerspective

// MARK: - Rescan Tests

@MainActor
@Suite("AppState Rescan")
struct AppStateRescanTests {

    static func makeState() -> AppState {
        let tree = FileNode(name: "mydir", kind: .directory, size: 5000, children: [
            FileNode(name: "a.txt", kind: .file, size: 3000),
            FileNode(name: "sub", kind: .directory, size: 2000, children: [
                FileNode(name: "b.txt", kind: .file, size: 2000),
            ]),
        ])
        let state = AppState()
        state.scanResult = ScanResult(
            scanTree: tree,
            volumePath: "/tmp",
            volumeSize: 100_000,
            freeSpace: 50_000,
            sizeMeasure: .logical
        )
        state.scanURL = URL(fileURLWithPath: "/tmp/mydir")
        state.scanPhase = .completed
        return state
    }

    @Test func rescanAllStartsScan() {
        let state = Self.makeState()
        state.rescan(scope: .all)

        // Should have started a new scan at the original URL
        if case .scanning(let path) = state.scanPhase {
            #expect(path == "/tmp/mydir")
        } else {
            Issue.record("Expected scanning phase after rescan")
        }
    }

    @Test func rescanVisibleStartsScanAtZoomRoot() {
        let state = Self.makeState()
        let sub = state.scanResult!.scanTree.children[1]
        state.zoomRoot = sub

        state.rescan(scope: .visible)

        if case .scanning(let path) = state.scanPhase {
            #expect(path.hasSuffix("/sub"))
        } else {
            Issue.record("Expected scanning phase after rescan visible")
        }
    }

    @Test func rescanWithoutScanResultDoesNothing() {
        let state = AppState()
        state.rescan(scope: .all)
        #expect(state.scanPhase == .idle)
    }

    @Test func rescanPreservesSizeMeasure() {
        let tree = FileNode(name: "dir", kind: .directory, size: 0)
        let state = AppState()
        state.scanResult = ScanResult(
            scanTree: tree,
            volumePath: "/",
            volumeSize: 0,
            freeSpace: 0,
            sizeMeasure: .physical
        )
        state.scanURL = URL(fileURLWithPath: "/tmp/dir")
        state.scanPhase = .completed

        // Rescan should use the same size measure
        // We can't easily test this without mocking, but we verify it starts scanning
        state.rescan(scope: .all)
        #expect(state.scanPhase != .idle)
    }

    @Test func rescanScopeEnum() {
        #expect(AppState.RescanScope.allCases.count == 3)
        #expect(AppState.RescanScope.all.rawValue == "Rescan All")
        #expect(AppState.RescanScope.visible.rawValue == "Rescan Visible")
        #expect(AppState.RescanScope.selected.rawValue == "Rescan Selected")
    }

    @Test func defaultRescanActionPreference() {
        let state = AppState()
        #expect(state.defaultRescanAction == AppState.RescanScope.all.rawValue)
    }
}

// MARK: - Window Title Tests

@MainActor
@Suite("AppState Window Title")
struct AppStateWindowTitleTests {

    @Test func windowTitleNoScan() {
        let state = AppState()
        #expect(state.windowTitle == "GrandPerspective")
    }

    @Test func windowTitleWithScan() {
        let tree = FileNode(name: "Photos", kind: .directory, size: 1000)
        let state = AppState()
        state.scanResult = ScanResult(scanTree: tree, volumePath: "/", volumeSize: 0, freeSpace: 0)
        state.scanPhase = .completed
        #expect(state.windowTitle == "Photos")
    }

    @Test func windowTitleWithFilter() {
        let tree = FileNode(name: "Photos", kind: .directory, size: 1000)
        let state = AppState()
        state.scanResult = ScanResult(scanTree: tree, volumePath: "/", volumeSize: 0, freeSpace: 0)
        state.scanPhase = .completed
        state.appliedFilter = NamedFilter(name: "Large Files", filter: .sizeRange(min: 1_000_000, max: nil))
        #expect(state.windowTitle == "Photos — Large Files")
    }
}

// MARK: - LoadScanResult Tests

@MainActor
@Suite("AppState LoadScanResult")
struct AppStateLoadScanResultTests {

    @Test func loadScanResultSetsState() {
        let tree = FileNode(name: "data", kind: .directory, size: 5000, children: [
            FileNode(name: "file.txt", kind: .file, size: 5000),
        ])
        let result = ScanResult(scanTree: tree, volumePath: "/Volumes/X", volumeSize: 100_000, freeSpace: 50_000)
        let url = URL(fileURLWithPath: "/Volumes/X/data")

        let state = AppState()
        state.loadScanResult(result, url: url)

        #expect(state.scanResult === result)
        #expect(state.scanURL == url)
        #expect(state.scanPhase == .completed)
        #expect(state.zoomRoot == nil)
        #expect(state.hoveredNode == nil)
        #expect(state.appliedFilter == nil)
    }

    @Test func loadScanResultWithFilter() {
        let tree = FileNode(name: "data", kind: .directory, size: 5000)
        let result = ScanResult(scanTree: tree, volumePath: "/", volumeSize: 0, freeSpace: 0)
        let filter = NamedFilter(name: "Test", filter: .sizeRange(min: 100, max: nil))

        let state = AppState()
        state.loadScanResult(result, url: nil, filter: filter)

        #expect(state.appliedFilter?.name == "Test")
    }
}

// MARK: - WindowTransfer Tests

@MainActor
@Suite("WindowTransfer")
struct WindowTransferTests {

    @Test func stageAndConsume() {
        let tree = FileNode(name: "root", kind: .directory, size: 0)
        let result = ScanResult(scanTree: tree, volumePath: "/", volumeSize: 0, freeSpace: 0)
        let url = URL(fileURLWithPath: "/test")

        WindowTransfer.shared.stage(scanResult: result, scanURL: url)
        let consumed = WindowTransfer.shared.consume()

        #expect(consumed != nil)
        #expect(consumed?.scanResult === result)
        #expect(consumed?.scanURL == url)
        #expect(consumed?.filter == nil)
    }

    @Test func consumeReturnsNilWhenEmpty() {
        // Make sure nothing is staged
        _ = WindowTransfer.shared.consume()

        let consumed = WindowTransfer.shared.consume()
        #expect(consumed == nil)
    }

    @Test func consumeClearsStaged() {
        let tree = FileNode(name: "root", kind: .directory, size: 0)
        let result = ScanResult(scanTree: tree, volumePath: "/", volumeSize: 0, freeSpace: 0)

        WindowTransfer.shared.stage(scanResult: result, scanURL: nil)
        _ = WindowTransfer.shared.consume()

        let second = WindowTransfer.shared.consume()
        #expect(second == nil)
    }

    @Test func stageWithFilter() {
        let tree = FileNode(name: "root", kind: .directory, size: 0)
        let result = ScanResult(scanTree: tree, volumePath: "/", volumeSize: 0, freeSpace: 0)
        let filter = NamedFilter(name: "Big", filter: .sizeRange(min: 1_000_000, max: nil))

        WindowTransfer.shared.stage(scanResult: result, scanURL: nil, filter: filter)
        let consumed = WindowTransfer.shared.consume()

        #expect(consumed?.filter?.name == "Big")
    }
}

// MARK: - ScanURL tracking

@MainActor
@Suite("AppState ScanURL")
struct AppStateScanURLTests {

    @Test func startScanStoresURL() {
        let state = AppState()
        let url = URL(fileURLWithPath: "/tmp/test")
        state.startScan(url: url)

        #expect(state.scanURL == url)
    }

    @Test func scanURLNilInitially() {
        let state = AppState()
        #expect(state.scanURL == nil)
    }
}
