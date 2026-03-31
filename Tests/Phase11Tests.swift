import Testing
import Foundation
@testable import GrandPerspective

// MARK: - InfoPanelView Display Tab

@Suite("InfoPanel Display")
struct InfoPanelDisplayTests {

    static func makeScanResult() -> ScanResult {
        let tree = FileNode(name: "Projects", kind: .directory, size: 50_000, children: [
            FileNode(name: "app.swift", kind: .file, size: 20_000),
            FileNode(name: "lib.swift", kind: .file, size: 30_000),
        ])
        return ScanResult(
            scanTree: tree,
            volumePath: "/",
            volumeSize: 1_000_000,
            freeSpace: 400_000,
            sizeMeasure: .logical
        )
    }

    @Test func scanResultHasVolumeInfo() {
        let result = Self.makeScanResult()
        #expect(result.volumePath == "/")
        #expect(result.volumeSize == 1_000_000)
        #expect(result.freeSpace == 400_000)
        #expect(result.usedSpace == 600_000)
        #expect(result.miscUsedSpace == 550_000)
    }

    @Test func scanResultHasScanInfo() {
        let result = Self.makeScanResult()
        #expect(result.scanTree.name == "Projects")
        #expect(result.scanTree.fileCount == 2)
        #expect(result.sizeMeasure == .logical)
    }

    @Test func deletionTrackingShowsInPanel() {
        let result = Self.makeScanResult()
        let file = result.scanTree.children.first!
        result.recordDeletion(of: file)
        #expect(result.freedFiles == 1)
        #expect(result.freedSpace == 20_000)
    }
}

// MARK: - InfoPanel Info Tab

@Suite("InfoPanel Info")
struct InfoPanelInfoTests {

    @Test func fileNodeHasAllInfoFields() {
        let node = FileNode(
            name: "report.pdf",
            kind: .file,
            size: 1_048_576,
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            modificationDate: Date(timeIntervalSince1970: 1_700_100_000),
            accessDate: Date(timeIntervalSince1970: 1_700_200_000),
            flags: [.hardLinked],
            type: .pdf
        )
        #expect(node.name == "report.pdf")
        #expect(node.formattedSize.isEmpty == false)
        #expect(node.isHardLinked == true)
        #expect(node.isPackage == false)
        #expect(node.creationDate != nil)
        #expect(node.modificationDate != nil)
        #expect(node.accessDate != nil)
        #expect(node.type?.identifier == "com.adobe.pdf")
    }

    @Test func directoryNodeShowsChildInfo() {
        let dir = FileNode(name: "src", kind: .directory, size: 5000, children: [
            FileNode(name: "a.swift", kind: .file, size: 2000),
            FileNode(name: "b.swift", kind: .file, size: 3000),
        ])
        #expect(dir.fileCount == 2)
        #expect(dir.children.count == 2)
        #expect(dir.isDirectory == true)
    }

    @Test func packageNodeType() {
        let pkg = FileNode(
            name: "MyApp.app",
            kind: .directory,
            size: 10_000,
            flags: [.package]
        )
        #expect(pkg.isPackage == true)
        #expect(pkg.isDirectory == true)
    }
}

// MARK: - InfoPanel Focus Tab

@Suite("InfoPanel Focus")
struct InfoPanelFocusTests {

    @Test func percentOfParent() {
        let child = FileNode(name: "big.dat", kind: .file, size: 750)
        let parent = FileNode(name: "dir", kind: .directory, size: 1000, children: [
            child,
            FileNode(name: "small.dat", kind: .file, size: 250),
        ])

        let pct = Double(child.size) / Double(parent.size) * 100
        #expect(pct == 75.0)
    }

    @Test func percentOfTotal() {
        let tree = FileNode(name: "root", kind: .directory, size: 10_000, children: [
            FileNode(name: "sub", kind: .directory, size: 4000, children: [
                FileNode(name: "f.txt", kind: .file, size: 4000),
            ]),
            FileNode(name: "g.txt", kind: .file, size: 6000),
        ])
        let f = tree.children[0].children[0]
        let totalPct = Double(f.size) / Double(tree.size) * 100
        #expect(totalPct == 40.0)
    }

    @Test func depthCalculation() {
        let leaf = FileNode(name: "deep.txt", kind: .file, size: 100)
        let mid = FileNode(name: "mid", kind: .directory, size: 100, children: [leaf])
        let root = FileNode(name: "root", kind: .directory, size: 100, children: [mid])

        let depth = leaf.ancestors.count - 1
        #expect(depth == 2)

        let rootDepth = root.ancestors.count - 1
        #expect(rootDepth == 0)
    }
}

// MARK: - Inspector Toggle

@Suite("Inspector Toggle")
@MainActor
struct InspectorToggleTests {

    @Test func showInspectorInitiallyFalse() {
        let state = AppState()
        #expect(state.showInspector == false)
    }

    @Test func toggleInspector() {
        let state = AppState()
        state.showInspector.toggle()
        #expect(state.showInspector == true)
        state.showInspector.toggle()
        #expect(state.showInspector == false)
    }

    @Test func toggleInspectorNotificationExists() {
        #expect(Notification.Name.toggleInspector.rawValue == "toggleInspector")
    }
}

// MARK: - InfoPanelView Tab Enum

@Suite("InfoPanel Tabs")
struct InfoPanelTabTests {

    @Test func allTabsCovered() {
        let tabs = InfoPanelView.Tab.allCases
        #expect(tabs.count == 3)
        #expect(tabs.contains(.display))
        #expect(tabs.contains(.info))
        #expect(tabs.contains(.focus))
    }

    @Test func tabRawValues() {
        #expect(InfoPanelView.Tab.display.rawValue == "Display")
        #expect(InfoPanelView.Tab.info.rawValue == "Info")
        #expect(InfoPanelView.Tab.focus.rawValue == "Focus")
    }
}
