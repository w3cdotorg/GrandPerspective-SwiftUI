import Testing
import Foundation
@testable import GrandPerspective

// MARK: - Show Package Contents

@Suite("Package Contents Toggle")
@MainActor
struct PackageContentsTests {

    static func makeTree() -> (AppState, FileNode) {
        let appContents = [
            FileNode(name: "main", kind: .file, size: 5000),
            FileNode(name: "resources", kind: .directory, size: 3000, children: [
                FileNode(name: "icon.png", kind: .file, size: 3000),
            ]),
        ]
        let myApp = FileNode(
            name: "MyApp.app",
            kind: .directory,
            size: 8000,
            children: appContents,
            flags: [.package]
        )
        let root = FileNode(name: "Root", kind: .directory, size: 10_000, children: [
            myApp,
            FileNode(name: "readme.txt", kind: .file, size: 2000),
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
        return (state, myApp)
    }

    @Test func showPackageContentsDefaultTrue() {
        let state = AppState()
        #expect(state.showPackageContents == true)
    }

    @Test func packageVisibleByDefault() {
        let (state, _) = Self.makeTree()
        let tree = state.displayTree!

        // MyApp.app should be a directory with children
        let myApp = tree.children.first { $0.name == "MyApp.app" }!
        #expect(myApp.isDirectory == true)
        #expect(myApp.children.count == 2)
    }

    @Test func packageCollapsedWhenToggleOff() {
        let (state, _) = Self.makeTree()
        state.showPackageContents = false

        let tree = state.displayTree!
        let myApp = tree.children.first { $0.name == "MyApp.app" }!

        // Should be treated as a file (no children visible)
        #expect(myApp.isDirectory == false)
        #expect(myApp.children.isEmpty)
        #expect(myApp.size == 8000)
    }

    @Test func toggleBackRestoresPackageContents() {
        let (state, _) = Self.makeTree()
        state.showPackageContents = false
        state.showPackageContents = true

        let tree = state.displayTree!
        let myApp = tree.children.first { $0.name == "MyApp.app" }!
        #expect(myApp.isDirectory == true)
    }

    @Test func nonPackageDirectoryUnaffected() {
        let (state, _) = Self.makeTree()
        state.showPackageContents = false

        let tree = state.displayTree!
        // Root itself should still be a directory
        #expect(tree.isDirectory == true)
        #expect(tree.children.count == 2)
    }
}

// MARK: - Show Entire Volume

@Suite("Entire Volume Toggle")
@MainActor
struct EntireVolumeTests {

    static func makeState() -> AppState {
        let root = FileNode(name: "Home", kind: .directory, size: 30_000, children: [
            FileNode(name: "docs", kind: .directory, size: 20_000, children: [
                FileNode(name: "a.txt", kind: .file, size: 20_000),
            ]),
            FileNode(name: "b.txt", kind: .file, size: 10_000),
        ])
        let result = ScanResult(
            scanTree: root,
            volumePath: "/",
            volumeSize: 100_000,
            freeSpace: 40_000,
            sizeMeasure: .logical
        )
        let state = AppState()
        state.loadScanResult(result, url: URL(fileURLWithPath: "/Home"))
        return state
    }

    @Test func showEntireVolumeDefaultFalse() {
        let state = AppState()
        #expect(state.showEntireVolume == false)
    }

    @Test func normalDisplayShowsScanTree() {
        let state = Self.makeState()
        let tree = state.displayTree!
        #expect(tree.name == "Home")
    }

    @Test func volumeDisplayWrapsTree() {
        let state = Self.makeState()
        state.showEntireVolume = true

        let tree = state.displayTree!
        #expect(tree.name == "/")
        #expect(tree.children.count == 3) // Home + misc + free
    }

    @Test func volumeDisplayHasFreeSpace() {
        let state = Self.makeState()
        state.showEntireVolume = true

        let tree = state.displayTree!
        let free = tree.children.first { $0.name.contains("Free") }
        #expect(free != nil)
        #expect(free?.size == 40_000)
        if case .synthetic(.freeSpace) = free?.kind {} else {
            Issue.record("Expected synthetic freeSpace node")
        }
    }

    @Test func volumeDisplayHasMiscUsedSpace() {
        let state = Self.makeState()
        state.showEntireVolume = true

        let tree = state.displayTree!
        // usedSpace = 100_000 - 40_000 = 60_000, scanned = 30_000, misc = 30_000
        let misc = tree.children.first { $0.name.contains("Misc") }
        #expect(misc != nil)
        #expect(misc?.size == 30_000)
    }

    @Test func toggleOffRestoresNormalView() {
        let state = Self.makeState()
        state.showEntireVolume = true
        state.showEntireVolume = false

        let tree = state.displayTree!
        #expect(tree.name == "Home")
    }

    @Test func volumeTotalSizeMatchesComponents() {
        let state = Self.makeState()
        state.showEntireVolume = true

        let tree = state.displayTree!
        let childrenTotal = tree.children.reduce(UInt64(0)) { $0 + $1.size }
        #expect(tree.size == childrenTotal)
    }
}

// MARK: - Combined toggles

@Suite("Package + Volume Combined")
@MainActor
struct CombinedToggleTests {

    @Test func packageCollapseWithVolume() {
        let pkg = FileNode(
            name: "App.app",
            kind: .directory,
            size: 5000,
            children: [FileNode(name: "bin", kind: .file, size: 5000)],
            flags: [.package]
        )
        let root = FileNode(name: "Root", kind: .directory, size: 5000, children: [pkg])
        let result = ScanResult(
            scanTree: root,
            volumePath: "/",
            volumeSize: 50_000,
            freeSpace: 20_000,
            sizeMeasure: .logical
        )
        let state = AppState()
        state.loadScanResult(result, url: URL(fileURLWithPath: "/Root"))

        state.showPackageContents = false
        state.showEntireVolume = true

        let tree = state.displayTree!
        // Volume root
        #expect(tree.name == "/")
        // Find the scan tree inside
        let scanRoot = tree.children.first { $0.name == "Root" }!
        let app = scanRoot.children.first { $0.name == "App.app" }!
        // Package should be collapsed
        #expect(app.isDirectory == false)
        #expect(app.children.isEmpty)
    }

    @Test func notificationNamesExist() {
        #expect(Notification.Name.togglePackageContents.rawValue == "togglePackageContents")
        #expect(Notification.Name.toggleEntireVolume.rawValue == "toggleEntireVolume")
    }
}
