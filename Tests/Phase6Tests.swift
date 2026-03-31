import Testing
import Foundation
@testable import GrandPerspective

// MARK: - FileNode removeChild

@Suite("FileNode Mutation")
struct FileNodeMutationTests {

    @Test func removeChildRemovesNode() {
        let child1 = FileNode(name: "a.txt", kind: .file, size: 100)
        let child2 = FileNode(name: "b.txt", kind: .file, size: 200)
        let parent = FileNode(name: "dir", kind: .directory, size: 300, children: [child1, child2])

        parent.removeChild(child1)

        #expect(parent.children.count == 1)
        #expect(parent.children[0].name == "b.txt")
        #expect(child1.parent == nil)
    }

    @Test func removeChildNotPresent() {
        let child = FileNode(name: "a.txt", kind: .file, size: 100)
        let other = FileNode(name: "b.txt", kind: .file, size: 200)
        let parent = FileNode(name: "dir", kind: .directory, size: 100, children: [child])

        parent.removeChild(other)

        #expect(parent.children.count == 1)
    }
}

// MARK: - AppState File Operations

@MainActor
@Suite("AppState File Operations")
struct AppStateFileOperationTests {

    static func makeState() -> AppState {
        let tree = FileNode(name: "root", kind: .directory, size: 5000, children: [
            FileNode(name: "big.dat", kind: .file, size: 3000),
            FileNode(name: "small.txt", kind: .file, size: 500),
            FileNode(name: "sub", kind: .directory, size: 1500, children: [
                FileNode(name: "nested.txt", kind: .file, size: 1500),
            ]),
        ])
        let state = AppState()
        state.scanResult = ScanResult(
            scanTree: tree,
            volumePath: "/tmp",
            volumeSize: 100_000,
            freeSpace: 50_000
        )
        state.scanPhase = .completed
        return state
    }

    @Test func fileURLForRootNode() {
        let state = Self.makeState()
        let url = state.fileURL(for: state.scanResult!.scanTree)
        #expect(url?.path.hasSuffix("/root") == true)
    }

    @Test func fileURLForChildNode() {
        let state = Self.makeState()
        let child = state.scanResult!.scanTree.children[0]
        let url = state.fileURL(for: child)
        #expect(url?.path.hasSuffix("/root/big.dat") == true)
    }

    @Test func fileURLForNestedNode() {
        let state = Self.makeState()
        let nested = state.scanResult!.scanTree.children[2].children[0]
        let url = state.fileURL(for: nested)
        #expect(url?.path.hasSuffix("/root/sub/nested.txt") == true)
    }

    @Test func canDeleteFilesRespectsPreference() {
        let state = AppState()
        state.fileDeletionTargets = AppState.FileDeletionTargets.nothing.rawValue
        #expect(!state.canDeleteFiles)
        #expect(!state.canDeleteFolders)

        state.fileDeletionTargets = AppState.FileDeletionTargets.onlyFiles.rawValue
        #expect(state.canDeleteFiles)
        #expect(!state.canDeleteFolders)

        state.fileDeletionTargets = AppState.FileDeletionTargets.filesAndFolders.rawValue
        #expect(state.canDeleteFiles)
        #expect(state.canDeleteFolders)
    }

    @Test func requestDeleteBlockedByPermissions() {
        let state = Self.makeState()
        state.fileDeletionTargets = AppState.FileDeletionTargets.nothing.rawValue

        let file = state.scanResult!.scanTree.children[0]
        state.requestDelete(file)

        // Should not show confirmation since deletion is disabled
        #expect(state.pendingDeletion == nil)
    }

    @Test func requestDeleteFolderBlockedWhenOnlyFiles() {
        let state = Self.makeState()
        state.fileDeletionTargets = AppState.FileDeletionTargets.onlyFiles.rawValue

        let folder = state.scanResult!.scanTree.children[2]
        state.requestDelete(folder)

        #expect(state.pendingDeletion == nil)
    }

    @Test func requestDeleteShowsConfirmation() {
        let state = Self.makeState()
        state.fileDeletionTargets = AppState.FileDeletionTargets.onlyFiles.rawValue
        state.confirmFileDeletion = true

        let file = state.scanResult!.scanTree.children[0]
        state.requestDelete(file)

        #expect(state.pendingDeletion != nil)
        #expect(state.pendingDeletion?.node === file)
        #expect(state.pendingDeletion?.message.contains("big.dat") == true)
    }

    @Test func requestDeleteFolderShowsWarning() {
        let state = Self.makeState()
        state.fileDeletionTargets = AppState.FileDeletionTargets.filesAndFolders.rawValue
        state.confirmFolderDeletion = true

        let folder = state.scanResult!.scanTree.children[2]
        state.requestDelete(folder)

        #expect(state.pendingDeletion != nil)
        #expect(state.pendingDeletion?.warning != nil)
    }

    @Test func cancelPendingDeletionClears() {
        let state = Self.makeState()
        state.fileDeletionTargets = AppState.FileDeletionTargets.onlyFiles.rawValue

        let file = state.scanResult!.scanTree.children[0]
        state.requestDelete(file)
        #expect(state.pendingDeletion != nil)

        state.cancelPendingDeletion()
        #expect(state.pendingDeletion == nil)
    }

    @Test func hardLinkedFileShowsWarning() {
        let hlFile = FileNode(name: "linked.txt", kind: .file, size: 100, flags: .hardLinked)
        let tree = FileNode(name: "root", kind: .directory, size: 100, children: [hlFile])
        let state = AppState()
        state.scanResult = ScanResult(scanTree: tree, volumePath: "/tmp", volumeSize: 100_000, freeSpace: 50_000)
        state.scanPhase = .completed
        state.fileDeletionTargets = AppState.FileDeletionTargets.onlyFiles.rawValue
        state.confirmFileDeletion = true

        state.requestDelete(hlFile)

        #expect(state.pendingDeletion?.warning?.contains("hard-linked") == true)
    }

    @Test func fileDeletionTargetsAllCases() {
        #expect(AppState.FileDeletionTargets.allCases.count == 3)
    }
}

// MARK: - Preferences

@MainActor
@Suite("File Operations Preferences")
struct FileOperationsPreferencesTests {

    @Test func defaultDeletionTarget() {
        let state = AppState()
        #expect(state.fileDeletionTargets == AppState.FileDeletionTargets.onlyFiles.rawValue)
    }

    @Test func defaultConfirmation() {
        let state = AppState()
        #expect(state.confirmFileDeletion == true)
        #expect(state.confirmFolderDeletion == true)
    }
}
