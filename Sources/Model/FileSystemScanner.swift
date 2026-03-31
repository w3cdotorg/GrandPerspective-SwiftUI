import Foundation
import UniformTypeIdentifiers

/// Scans a directory tree and builds a FileNode hierarchy.
/// Replaces TreeBuilder + ScanTaskExecutor from the Obj-C codebase.
actor FileSystemScanner {

    enum SizeMeasure: String, CaseIterable, Sendable {
        case logical
        case physical
    }

    struct Progress: Sendable {
        var filesScanned: UInt64 = 0
        var totalSize: UInt64 = 0
    }

    private let sizeMeasure: SizeMeasure
    private let treatPackagesAsFiles: Bool
    private var cancelled = false
    private var progress = Progress()

    /// Stream of progress updates during scanning.
    let progressStream: AsyncStream<Progress>
    private let progressContinuation: AsyncStream<Progress>.Continuation

    init(sizeMeasure: SizeMeasure = .logical, treatPackagesAsFiles: Bool = false) {
        self.sizeMeasure = sizeMeasure
        self.treatPackagesAsFiles = treatPackagesAsFiles

        let (stream, continuation) = AsyncStream<Progress>.makeStream()
        self.progressStream = stream
        self.progressContinuation = continuation
    }

    func cancel() {
        cancelled = true
        progressContinuation.finish()
    }

    /// Scans the directory at `url` and returns the root FileNode.
    func scan(url: URL) throws -> FileNode {
        cancelled = false
        progress = Progress()

        let fm = FileManager.default
        let resourceKeys: Set<URLResourceKey> = [
            .nameKey, .isDirectoryKey, .fileSizeKey, .totalFileAllocatedSizeKey,
            .creationDateKey, .contentModificationDateKey, .contentAccessDateKey,
            .isPackageKey, .linkCountKey, .contentTypeKey
        ]

        let root = try scanDirectory(url: url, fileManager: fm, resourceKeys: resourceKeys)
        progressContinuation.finish()
        return root
    }

    // MARK: - Private

    private func scanDirectory(
        url: URL,
        fileManager fm: FileManager,
        resourceKeys: Set<URLResourceKey>
    ) throws -> FileNode {
        guard !cancelled else {
            throw CancellationError()
        }

        let values = try url.resourceValues(forKeys: resourceKeys)
        let name = values.name ?? url.lastPathComponent

        var childNodes: [FileNode] = []
        var totalSize: UInt64 = 0

        let contents: [URL]
        do {
            contents = try fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles]
            )
        } catch {
            // Permission denied or other access error — return an empty directory
            let flags = makeFlags(values)
            return FileNode(
                name: name,
                kind: .directory,
                size: 0,
                creationDate: values.creationDate,
                modificationDate: values.contentModificationDate,
                accessDate: values.contentAccessDate,
                flags: flags
            )
        }

        for childURL in contents {
            guard !cancelled else { throw CancellationError() }

            let childValues = try? childURL.resourceValues(forKeys: resourceKeys)
            guard let childValues else { continue }

            let isDir = childValues.isDirectory ?? false
            let isPackage = childValues.isPackage ?? false

            if isDir && !(treatPackagesAsFiles && isPackage) {
                guard let dirNode = try? scanDirectory(
                    url: childURL,
                    fileManager: fm,
                    resourceKeys: resourceKeys
                ) else { continue }
                totalSize += dirNode.size
                childNodes.append(dirNode)
            } else {
                let fileNode = makeFileNode(url: childURL, values: childValues)
                totalSize += fileNode.size
                childNodes.append(fileNode)

                progress.filesScanned += 1
                progress.totalSize += fileNode.size
                if progress.filesScanned.isMultiple(of: 500) {
                    progressContinuation.yield(progress)
                }
            }
        }

        let flags = makeFlags(values)
        return FileNode(
            name: name,
            kind: .directory,
            size: totalSize,
            children: childNodes,
            creationDate: values.creationDate,
            modificationDate: values.contentModificationDate,
            accessDate: values.contentAccessDate,
            flags: flags
        )
    }

    private func makeFileNode(url: URL, values: URLResourceValues) -> FileNode {
        let name = values.name ?? url.lastPathComponent
        let size: UInt64 = switch sizeMeasure {
        case .logical:
            UInt64(values.fileSize ?? 0)
        case .physical:
            UInt64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
        }

        let flags = makeFlags(values)
        let utType = values.contentType

        return FileNode(
            name: name,
            kind: .file,
            size: size,
            creationDate: values.creationDate,
            modificationDate: values.contentModificationDate,
            accessDate: values.contentAccessDate,
            flags: flags,
            type: utType
        )
    }

    private func makeFlags(_ values: URLResourceValues) -> FileNode.Flags {
        var flags = FileNode.Flags()
        if (values.linkCount ?? 1) > 1 {
            flags.insert(.hardLinked)
        }
        if values.isPackage ?? false {
            flags.insert(.package)
        }
        return flags
    }
}
