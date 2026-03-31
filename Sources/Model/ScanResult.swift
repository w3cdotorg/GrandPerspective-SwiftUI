import Foundation

/// Result of a filesystem scan. Replaces TreeContext / AnnotatedTreeContext.
@Observable
final class ScanResult: Identifiable {
    let id = UUID()

    /// Root node of the scanned tree.
    let scanTree: FileNode

    /// Volume metadata.
    let volumePath: String
    let volumeSize: UInt64
    let freeSpace: UInt64
    let scanTime: Date
    let sizeMeasure: FileSystemScanner.SizeMeasure

    /// Filters applied during scan.
    let appliedFilters: [FileFilter]

    /// Optional user comments.
    var comments: String

    /// Tracks cumulative space freed by deletions.
    private(set) var freedSpace: UInt64 = 0
    private(set) var freedFiles: UInt64 = 0

    init(
        scanTree: FileNode,
        volumePath: String,
        volumeSize: UInt64,
        freeSpace: UInt64,
        scanTime: Date = .now,
        sizeMeasure: FileSystemScanner.SizeMeasure = .logical,
        appliedFilters: [FileFilter] = [],
        comments: String = ""
    ) {
        self.scanTree = scanTree
        self.volumePath = volumePath
        self.volumeSize = volumeSize
        self.freeSpace = freeSpace
        self.scanTime = scanTime
        self.sizeMeasure = sizeMeasure
        self.appliedFilters = appliedFilters
        self.comments = comments
    }

    // MARK: - Computed

    var usedSpace: UInt64 {
        volumeSize - freeSpace
    }

    var miscUsedSpace: UInt64 {
        let scanned = scanTree.size
        let used = usedSpace
        return used > scanned ? used - scanned : 0
    }

    var formattedScanTime: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(scanTime) {
            formatter.dateStyle = .none
            formatter.timeStyle = .medium
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
        }
        return formatter.string(from: scanTime)
    }

    // MARK: - Deletion tracking

    func recordDeletion(of node: FileNode) {
        let (size, count) = accumulatePhysicalFiles(in: node)
        freedSpace += size
        freedFiles += count
    }

    private func accumulatePhysicalFiles(in node: FileNode) -> (size: UInt64, count: UInt64) {
        guard node.isPhysical else { return (0, 0) }

        switch node.kind {
        case .file:
            return (node.size, 1)
        case .directory:
            return node.children.reduce((0, 0)) { acc, child in
                let (s, c) = accumulatePhysicalFiles(in: child)
                return (acc.0 + s, acc.1 + c)
            }
        case .synthetic:
            return (0, 0)
        }
    }
}

// MARK: - Factory for volume scan

extension ScanResult {
    /// Creates a ScanResult by scanning a volume path.
    static func scan(
        url: URL,
        sizeMeasure: FileSystemScanner.SizeMeasure = .logical,
        filters: [FileFilter] = []
    ) async throws -> ScanResult {
        let scanner = FileSystemScanner(sizeMeasure: sizeMeasure)
        let tree = try await scanner.scan(url: url)

        let fm = FileManager.default
        let values = try url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey
        ])

        let volumeSize = UInt64(values.volumeTotalCapacity ?? 0)
        let freeSpace = UInt64(values.volumeAvailableCapacity ?? 0)

        // Determine volume path (mount point)
        let volumePath: String
        if let mountPoint = (try? url.resourceValues(forKeys: [.volumeURLKey]))?.volume?.path {
            volumePath = mountPoint
        } else {
            volumePath = url.path
        }

        var result = ScanResult(
            scanTree: tree,
            volumePath: volumePath,
            volumeSize: volumeSize,
            freeSpace: freeSpace,
            sizeMeasure: sizeMeasure,
            appliedFilters: filters
        )

        // Apply filters if any
        if !filters.isEmpty {
            // Phase 1: filters are defined but applied in Phase 3
        }

        return result
    }
}
