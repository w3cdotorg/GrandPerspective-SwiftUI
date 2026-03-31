import Foundation
import UniformTypeIdentifiers

/// Represents a node in the file system tree.
/// Replaces the Obj-C hierarchy: Item / FileItem / DirectoryItem / PlainFileItem / CompoundItem.
@Observable
final class FileNode: Identifiable, @unchecked Sendable {
    let id = UUID()
    let name: String
    let kind: Kind
    let size: UInt64
    let creationDate: Date?
    let modificationDate: Date?
    let accessDate: Date?
    let flags: Flags
    let type: UTType?

    /// Children for directories; empty for files.
    private(set) var children: [FileNode]

    /// Weak ref to parent — set after tree construction.
    weak var parent: FileNode?

    enum Kind: Sendable {
        case file
        case directory
        case synthetic(SyntheticRole)
    }

    enum SyntheticRole: String, Sendable {
        case freeSpace = "free"
        case usedSpace = "used"
        case miscUsedSpace = "misc used"
        case freedSpace = "freed"
    }

    struct Flags: OptionSet, Sendable {
        let rawValue: UInt8
        static let hardLinked = Flags(rawValue: 1 << 1)
        static let package    = Flags(rawValue: 1 << 2)
    }

    init(
        name: String,
        kind: Kind,
        size: UInt64,
        children: [FileNode] = [],
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        accessDate: Date? = nil,
        flags: Flags = [],
        type: UTType? = nil
    ) {
        self.name = name
        self.kind = kind
        self.size = size
        self.children = children
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.accessDate = accessDate
        self.flags = flags
        self.type = type

        // Wire parent references
        for child in children {
            child.parent = self
        }
    }

    // MARK: - Computed Properties

    var isDirectory: Bool {
        if case .directory = kind { return true }
        return false
    }

    var isPhysical: Bool {
        if case .synthetic = kind { return false }
        return true
    }

    var isHardLinked: Bool { flags.contains(.hardLinked) }
    var isPackage: Bool { flags.contains(.package) }

    /// Cached file count (computed once, lazily).
    @ObservationIgnored
    private var _fileCount: UInt64?

    /// Number of physical files in this subtree.
    var fileCount: UInt64 {
        if let cached = _fileCount { return cached }
        let count: UInt64 = switch kind {
        case .file: isPhysical ? 1 : 0
        case .synthetic: 0
        case .directory: children.reduce(0) { $0 + $1.fileCount }
        }
        _fileCount = count
        return count
    }

    /// Full path from root to this node.
    var path: String {
        if let parent {
            let parentPath = parent.path
            return parentPath.hasSuffix("/") ? parentPath + name : parentPath + "/" + name
        }
        return name
    }

    /// Ancestors from root to self (inclusive).
    var ancestors: [FileNode] {
        var result: [FileNode] = []
        var current: FileNode? = self
        while let node = current {
            result.append(node)
            current = node.parent
        }
        return result.reversed()
    }

    func isAncestor(of other: FileNode) -> Bool {
        var current: FileNode? = other.parent
        while let node = current {
            if node === self { return true }
            current = node.parent
        }
        return false
    }

    // MARK: - Mutation

    func replaceChild(_ old: FileNode, with new: FileNode) {
        guard let index = children.firstIndex(where: { $0 === old }) else { return }
        old.parent = nil
        new.parent = self
        children[index] = new
    }

    func removeChild(_ child: FileNode) {
        children.removeAll { $0 === child }
        child.parent = nil
    }
}

// MARK: - Size Formatting

extension FileNode {
    private nonisolated(unsafe) static let decimalFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()

    private nonisolated(unsafe) static let binaryFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .binary
        return f
    }()

    /// Current unit system preference. Updated from PreferencesView.
    nonisolated(unsafe) static var useBinaryUnits: Bool = false

    static func formattedSize(_ bytes: UInt64) -> String {
        let formatter = useBinaryUnits ? binaryFormatter : decimalFormatter
        return formatter.string(fromByteCount: Int64(clamping: bytes))
    }

    var formattedSize: String {
        Self.formattedSize(size)
    }
}
