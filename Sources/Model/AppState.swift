import Foundation
import SwiftUI

/// Central application state. Replaces the Obj-C framework of MainMenuControl,
/// DirectoryViewControl, TaskExecutor, and scattered state across XIB controllers.
///
/// Owned by `GrandPerspectiveApp` and injected into the view hierarchy via `@Environment`.
@MainActor
@Observable
final class AppState {

    // MARK: - Scan state

    enum ScanPhase: Equatable {
        case idle
        case scanning(path: String)
        case completed
    }

    /// Use `startScan(url:)` or `cancelScan()` to change these from production code.
    var scanPhase: ScanPhase = .idle
    var scanProgress: FileSystemScanner.Progress?
    var scanResult: ScanResult?
    var errorMessage: String?

    /// The URL that was scanned (needed for rescan).
    var scanURL: URL?

    private var scanTask: Task<Void, Never>?

    // MARK: - Rescan

    enum RescanScope: String, CaseIterable {
        case all = "Rescan All"
        case visible = "Rescan Visible"
    }

    // MARK: - Display state

    var colorMapping: any ColorMapping = FolderColorMapping()
    var hoveredNode: FileNode?
    var zoomRoot: FileNode?

    // MARK: - Filters

    let filterRepository = FilterRepository()
    var appliedFilter: NamedFilter? {
        didSet { recomputeFilteredTree() }
    }

    /// The tree after applying the current filter. Nil if no filter or no scan.
    private(set) var filteredTree: FileNode?

    /// The effective root for display: filtered tree, or scan tree.
    var displayTree: FileNode? {
        filteredTree ?? scanResult?.scanTree
    }

    // MARK: - Preferences (bridged from @AppStorage)

    @ObservationIgnored
    @AppStorage("defaultColorMapping") var defaultColorMappingName = "Files & Folders"

    @ObservationIgnored
    @AppStorage("fileDeletionTargets") var fileDeletionTargets = FileDeletionTargets.onlyFiles.rawValue

    @ObservationIgnored
    @AppStorage("confirmFileDeletion") var confirmFileDeletion = true

    @ObservationIgnored
    @AppStorage("confirmFolderDeletion") var confirmFolderDeletion = true

    @ObservationIgnored
    @AppStorage("defaultRescanAction") var defaultRescanAction = RescanScope.all.rawValue

    /// Pending deletion confirmation state.
    var pendingDeletion: PendingDeletion?

    struct PendingDeletion {
        let node: FileNode
        let url: URL
        let message: String
        let warning: String?
    }

    enum FileDeletionTargets: String, CaseIterable {
        case nothing = "delete nothing"
        case onlyFiles = "only delete files"
        case filesAndFolders = "delete files and folders"
    }

    var canDeleteFiles: Bool {
        FileDeletionTargets(rawValue: fileDeletionTargets) != .nothing
    }

    var canDeleteFolders: Bool {
        FileDeletionTargets(rawValue: fileDeletionTargets) == .filesAndFolders
    }

    /// Window title for multi-window support.
    var windowTitle: String {
        guard let scanResult else { return "GrandPerspective" }
        let name = scanResult.scanTree.name
        if let filter = appliedFilter {
            return "\(name) — \(filter.name)"
        }
        return name
    }

    /// Load an existing scan result (used for duplicate/twin windows).
    func loadScanResult(_ result: ScanResult, url: URL?, filter: NamedFilter? = nil) {
        scanResult = result
        scanURL = url
        scanPhase = .completed
        filteredTree = nil
        zoomRoot = nil
        hoveredNode = nil
        appliedFilter = filter

        if let mapping = ColorMappings.named(defaultColorMappingName) {
            colorMapping = mapping
        }
    }

    // MARK: - Scan actions

    func startScan(url: URL, sizeMeasure: FileSystemScanner.SizeMeasure = .logical) {
        cancelScan()

        scanURL = url
        scanPhase = .scanning(path: url.path)
        scanProgress = nil
        scanResult = nil
        filteredTree = nil
        zoomRoot = nil
        hoveredNode = nil
        appliedFilter = nil

        let scanner = FileSystemScanner(sizeMeasure: sizeMeasure)

        scanTask = Task {
            // Listen for progress updates
            let progressTask = Task {
                for await progress in await scanner.progressStream {
                    self.scanProgress = progress
                }
            }

            do {
                let tree = try await scanner.scan(url: url)

                let fm = FileManager.default
                let values = try url.resourceValues(forKeys: [
                    .volumeTotalCapacityKey,
                    .volumeAvailableCapacityKey,
                    .volumeURLKey
                ])

                let volumeSize = UInt64(values.volumeTotalCapacity ?? 0)
                let freeSpace = UInt64(values.volumeAvailableCapacity ?? 0)
                let volumePath = values.volume?.path ?? url.path

                let result = ScanResult(
                    scanTree: tree,
                    volumePath: volumePath,
                    volumeSize: volumeSize,
                    freeSpace: freeSpace,
                    sizeMeasure: sizeMeasure
                )

                scanResult = result
                scanPhase = .completed

                // Apply default color mapping from preferences
                if let mapping = ColorMappings.named(defaultColorMappingName) {
                    colorMapping = mapping
                }
            } catch is CancellationError {
                scanPhase = .idle
            } catch {
                errorMessage = error.localizedDescription
                scanPhase = .idle
            }

            progressTask.cancel()
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        if case .scanning = scanPhase {
            scanPhase = .idle
        }
    }

    func rescan(scope: RescanScope = .all) {
        guard let scanResult else { return }
        let sizeMeasure = scanResult.sizeMeasure

        switch scope {
        case .all:
            guard let url = scanURL else { return }
            startScan(url: url, sizeMeasure: sizeMeasure)
        case .visible:
            // Rescan the visible subtree (zoomRoot or full tree)
            let visibleRoot = zoomRoot ?? scanResult.scanTree
            guard let url = fileURL(for: visibleRoot) else { return }
            startScan(url: url, sizeMeasure: sizeMeasure)
        }
    }

    // MARK: - Navigation

    func zoomIn(to node: FileNode) {
        guard node.isDirectory else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            zoomRoot = node
        }
    }

    func zoomOut() {
        guard let current = zoomRoot else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            let parent = current.parent
            // If we're back at scan root, clear zoom
            if parent === displayTree {
                zoomRoot = nil
            } else {
                zoomRoot = parent
            }
        }
    }

    func navigateTo(_ node: FileNode?) {
        withAnimation(.easeInOut(duration: 0.25)) {
            zoomRoot = node
        }
    }

    // MARK: - Filtering

    private func recomputeFilteredTree() {
        guard let scanResult, let appliedFilter else {
            filteredTree = nil
            return
        }

        filteredTree = filterTree(scanResult.scanTree, with: appliedFilter.filter)

        // Reset zoom if the zoom target is no longer in the filtered tree
        if let zoomRoot, filteredTree != nil {
            if !isNode(zoomRoot, reachableFrom: filteredTree!) {
                self.zoomRoot = nil
            }
        }
    }

    /// Creates a filtered copy of the tree, removing nodes that fail the filter.
    /// Directories are kept if any descendant passes.
    private func filterTree(_ node: FileNode, with filter: FileFilter) -> FileNode? {
        if node.isDirectory {
            let filteredChildren = node.children.compactMap { filterTree($0, with: filter) }
            if filteredChildren.isEmpty && filter.test(node) != .passed {
                return nil
            }
            let totalSize = filteredChildren.reduce(UInt64(0)) { $0 + $1.size }
            return FileNode(
                name: node.name,
                kind: node.kind,
                size: totalSize,
                children: filteredChildren,
                creationDate: node.creationDate,
                modificationDate: node.modificationDate,
                accessDate: node.accessDate,
                flags: node.flags,
                type: node.type
            )
        } else {
            return filter.passes(node) ? node : nil
        }
    }

    private func isNode(_ target: FileNode, reachableFrom root: FileNode) -> Bool {
        if root.id == target.id { return true }
        return root.children.contains { isNode(target, reachableFrom: $0) }
    }

    // MARK: - File operations

    /// Builds the absolute filesystem URL for a node.
    func fileURL(for node: FileNode) -> URL? {
        guard let scanResult else { return nil }
        // node.path starts with the scan root name; we need the scan URL
        // The scan root name == the scanned folder name
        let rootName = scanResult.scanTree.name
        let nodePath = node.path
        // Strip the root name prefix to get the relative path within the scanned folder
        let relative: String
        if nodePath == rootName {
            relative = ""
        } else if nodePath.hasPrefix(rootName + "/") {
            relative = String(nodePath.dropFirst(rootName.count + 1))
        } else {
            relative = nodePath
        }
        // scanResult stores volumePath, but the actual scanned URL is the root's path
        // We need to reconstruct from the volume path + scan tree path
        // The simplest approach: the scan root path IS the scanned folder
        let scanURL = URL(fileURLWithPath: scanResult.volumePath)
            .appendingPathComponent(scanResult.scanTree.name)
        if relative.isEmpty {
            return scanURL
        }
        return scanURL.appendingPathComponent(relative)
    }

    func revealInFinder(_ node: FileNode) {
        guard let url = fileURL(for: node) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openFile(_ node: FileNode) {
        guard let url = fileURL(for: node) else { return }
        NSWorkspace.shared.open(url)
    }

    func copyPath(_ node: FileNode) {
        guard let url = fileURL(for: node) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }

    /// Request deletion of a node. Shows confirmation if needed, or deletes directly.
    func requestDelete(_ node: FileNode) {
        guard let url = fileURL(for: node) else { return }

        // Check permissions
        if node.isDirectory && !canDeleteFolders { return }
        if !node.isDirectory && !canDeleteFiles { return }

        // Build confirmation message
        let itemType: String
        if node.isPackage {
            itemType = String(localized: "package")
        } else if node.isDirectory {
            itemType = String(localized: "folder")
        } else {
            itemType = String(localized: "file")
        }

        let message = String(localized: "Do you want to delete the \(itemType) \"\(node.name)\"?")

        var warning: String?
        if node.isHardLinked {
            warning = String(localized: "Note: The \(itemType) is hard-linked. It will take up space until all links to it are deleted.")
        } else if node.isDirectory && !node.isPackage {
            warning = String(localized: "The selected folder, with all its contents, will be moved to Trash. Beware, any files in the folder that are not shown in the view will also be deleted.")
        }

        // Check if confirmation is needed
        let needsConfirmation = node.isDirectory ? confirmFolderDeletion : confirmFileDeletion

        if needsConfirmation {
            pendingDeletion = PendingDeletion(node: node, url: url, message: message, warning: warning)
        } else {
            performDelete(node: node, url: url)
        }
    }

    /// Execute the deletion (move to Trash).
    func confirmPendingDeletion() {
        guard let pending = pendingDeletion else { return }
        performDelete(node: pending.node, url: pending.url)
        pendingDeletion = nil
    }

    func cancelPendingDeletion() {
        pendingDeletion = nil
    }

    private func performDelete(node: FileNode, url: URL) {
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)

            // Update model
            scanResult?.recordDeletion(of: node)

            // Remove from tree
            if let parent = node.parent {
                parent.removeChild(node)
            }

            // Clear hover/zoom if they pointed to the deleted node
            if hoveredNode?.id == node.id { hoveredNode = nil }
            if zoomRoot?.id == node.id { zoomOut() }

            // Recompute filter if active
            if appliedFilter != nil { recomputeFilteredTree() }
        } catch {
            let itemType = node.isDirectory ? String(localized: "folder") : String(localized: "file")
            errorMessage = String(localized: "Failed to delete the \(itemType) \"\(node.name)\". Possible reasons are that it does not exist anymore or that you lack the required permissions.")
        }
    }

    // MARK: - Convenience

    func selectAndScan() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder to scan"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        startScan(url: url)
    }

    // MARK: - Document persistence

    func saveScan() {
        guard let scanResult else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.gpscan]
        panel.nameFieldStringValue = "\(scanResult.scanTree.name).gpscan"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let codable = CodableScanResult(from: scanResult)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(codable)
            try data.write(to: url, options: .atomic)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openScan() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.gpscan, .json]
        panel.message = "Open a saved scan"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let codable = try decoder.decode(CodableScanResult.self, from: data)

            scanResult = codable.toScanResult()
            scanPhase = .completed
            filteredTree = nil
            zoomRoot = nil
            hoveredNode = nil
            appliedFilter = nil

            if let mapping = ColorMappings.named(defaultColorMappingName) {
                colorMapping = mapping
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Drag & drop

    func handleDrop(urls: [URL]) -> Bool {
        guard let url = urls.first else { return false }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return false }

        if isDir.boolValue {
            startScan(url: url)
            return true
        } else if url.pathExtension == "gpscan" || url.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let codable = try decoder.decode(CodableScanResult.self, from: data)
                scanResult = codable.toScanResult()
                scanPhase = .completed
                filteredTree = nil
                zoomRoot = nil
                hoveredNode = nil
                appliedFilter = nil
                return true
            } catch {
                errorMessage = error.localizedDescription
                return false
            }
        }

        return false
    }
}
