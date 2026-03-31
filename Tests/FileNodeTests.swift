import Testing
import Foundation
import UniformTypeIdentifiers
@testable import GrandPerspective

@Suite("FileNode")
struct FileNodeTests {

    // MARK: - Helpers

    static func makeTree() -> FileNode {
        // src/
        //   main.swift  (1000 bytes)
        //   utils.swift (500 bytes)
        //   lib/
        //     helper.swift (200 bytes)
        let helper = FileNode(name: "helper.swift", kind: .file, size: 200, type: .swiftSource)
        let lib = FileNode(name: "lib", kind: .directory, size: 200, children: [helper])
        let main = FileNode(name: "main.swift", kind: .file, size: 1000, type: .swiftSource)
        let utils = FileNode(name: "utils.swift", kind: .file, size: 500, type: .swiftSource)
        return FileNode(name: "src", kind: .directory, size: 1700, children: [main, utils, lib])
    }

    // MARK: - Basic properties

    @Test func fileNodeKind() {
        let file = FileNode(name: "a.txt", kind: .file, size: 100)
        let dir = FileNode(name: "dir", kind: .directory, size: 0)
        let synthetic = FileNode(name: "free", kind: .synthetic(.freeSpace), size: 999)

        #expect(!file.isDirectory)
        #expect(file.isPhysical)

        #expect(dir.isDirectory)
        #expect(dir.isPhysical)

        #expect(!synthetic.isDirectory)
        #expect(!synthetic.isPhysical)
    }

    @Test func flags() {
        let hardLinked = FileNode(name: "a", kind: .file, size: 10, flags: .hardLinked)
        let pkg = FileNode(name: "b.app", kind: .directory, size: 50, flags: .package)
        let plain = FileNode(name: "c", kind: .file, size: 10)

        #expect(hardLinked.isHardLinked)
        #expect(!hardLinked.isPackage)
        #expect(pkg.isPackage)
        #expect(!plain.isHardLinked)
        #expect(!plain.isPackage)
    }

    // MARK: - Tree structure

    @Test func parentChildWiring() {
        let root = Self.makeTree()

        // Root has no parent
        #expect(root.parent == nil)

        // Children have parent set
        for child in root.children {
            #expect(child.parent === root)
        }

        // Nested child
        let lib = root.children.first { $0.name == "lib" }!
        let helper = lib.children.first { $0.name == "helper.swift" }!
        #expect(helper.parent === lib)
        #expect(lib.parent === root)
    }

    @Test func path() {
        let root = Self.makeTree()
        let lib = root.children.first { $0.name == "lib" }!
        let helper = lib.children.first!

        #expect(root.path == "src")
        #expect(lib.path == "src/lib")
        #expect(helper.path == "src/lib/helper.swift")
    }

    @Test func ancestors() {
        let root = Self.makeTree()
        let lib = root.children.first { $0.name == "lib" }!
        let helper = lib.children.first!

        let ancestors = helper.ancestors
        #expect(ancestors.count == 3)
        #expect(ancestors[0] === root)
        #expect(ancestors[1] === lib)
        #expect(ancestors[2] === helper)
    }

    @Test func isAncestor() {
        let root = Self.makeTree()
        let lib = root.children.first { $0.name == "lib" }!
        let helper = lib.children.first!
        let main = root.children.first { $0.name == "main.swift" }!

        #expect(root.isAncestor(of: helper))
        #expect(lib.isAncestor(of: helper))
        #expect(!helper.isAncestor(of: root))
        #expect(!main.isAncestor(of: helper))
    }

    // MARK: - File count

    @Test func fileCount() {
        let root = Self.makeTree()
        // 3 physical files: main.swift, utils.swift, helper.swift
        #expect(root.fileCount == 3)

        let lib = root.children.first { $0.name == "lib" }!
        #expect(lib.fileCount == 1)
    }

    @Test func syntheticNotCountedInFileCount() {
        let freeSpace = FileNode(name: "free", kind: .synthetic(.freeSpace), size: 999)
        let dir = FileNode(name: "root", kind: .directory, size: 1099, children: [
            FileNode(name: "a.txt", kind: .file, size: 100),
            freeSpace,
        ])
        #expect(dir.fileCount == 1)
    }

    // MARK: - Mutation

    @Test func replaceChild() {
        let root = Self.makeTree()
        let oldMain = root.children.first { $0.name == "main.swift" }!
        let newMain = FileNode(name: "main.swift", kind: .file, size: 2000)

        root.replaceChild(oldMain, with: newMain)

        #expect(newMain.parent === root)
        #expect(oldMain.parent == nil)
        #expect(root.children.contains { $0 === newMain })
        #expect(!root.children.contains { $0 === oldMain })
    }

    // MARK: - Formatting

    @Test func formattedSize() {
        let size = FileNode.formattedSize(1024)
        #expect(!size.isEmpty)

        let zero = FileNode.formattedSize(0)
        #expect(!zero.isEmpty)
    }
}
