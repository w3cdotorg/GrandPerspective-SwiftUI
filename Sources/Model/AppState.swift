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
        case selected = "Rescan Selected"
    }

    /// The last clicked/selected node (distinct from hover, used for Rescan Selected).
    var selectedNode: FileNode?

    // MARK: - Display state

    var colorMapping: any ColorMapping = FolderColorMapping()
    var hoveredNode: FileNode?
    var zoomRoot: FileNode?
    var showInspector: Bool = false

    /// Gradient intensity for treemap cell rendering (0.0 = flat, 1.0 = maximum gradient).
    var gradientIntensity: Double = 0.5

    /// The selected color palette for palette-based mappings.
    var selectedPalette: ColorPalette = .default {
        didSet { reapplyColorMapping() }
    }

    /// When false, packages (.app, .framework, etc.) are shown as opaque files.
    var showPackageContents: Bool = true {
        didSet { recomputeDisplayTree() }
    }

    /// When true, wraps the scan tree in a volume root with free/misc synthetic nodes.
    var showEntireVolume: Bool = false {
        didSet { recomputeDisplayTree() }
    }

    // MARK: - Filters

    enum FilterMode: String, CaseIterable {
        case filter = "Filter"
        case mask = "Mask"
    }

    /// Filter mode: `.filter` removes non-matching nodes, `.mask` grays them out.
    var filterMode: FilterMode = .filter {
        didSet { recomputeFilteredTree() }
    }

    let filterRepository = FilterRepository()
    var appliedFilter: NamedFilter? {
        didSet { recomputeFilteredTree() }
    }

    /// The tree after applying the current filter. Nil if no filter or no scan.
    private(set) var filteredTree: FileNode?

    /// IDs of nodes that fail the filter (used in mask mode for grayed-out rendering).
    private(set) var maskedNodeIDs: Set<UUID> = []

    /// Cached tree with packages collapsed (when showPackageContents is off).
    private(set) var packageCollapsedTree: FileNode?

    /// Cached volume-wrapped tree (when showEntireVolume is on).
    private(set) var volumeTree: FileNode?

    /// The effective root for display, applying filters, package collapsing, and volume wrapping.
    var displayTree: FileNode? {
        volumeTree ?? packageCollapsedTree ?? filteredTree ?? scanResult?.scanTree
    }

    /// Recomputes the display tree pipeline: filter → package collapse → volume wrap.
    private func recomputeDisplayTree() {
        let base = filteredTree ?? scanResult?.scanTree
        packageCollapsedTree = showPackageContents ? nil : base.map { collapsePackages($0) }
        volumeTree = showEntireVolume ? wrapInVolume() : nil

        // Reset zoom if target is no longer reachable
        if let zoomRoot, let tree = displayTree {
            if !isNode(zoomRoot, reachableFrom: tree) {
                self.zoomRoot = nil
            }
        }
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

    @ObservationIgnored
    @AppStorage("fileSizeMeasure") var fileSizeMeasure = "logical"

    @ObservationIgnored
    @AppStorage("fileSizeUnitSystem") var fileSizeUnitSystem = "decimal"

    @ObservationIgnored
    @AppStorage("selectedPaletteName") var selectedPaletteName = ColorPalette.default.name

    @ObservationIgnored
    @AppStorage("gradientIntensityPref") var gradientIntensityPref = 0.5

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

    /// Reapply the current color mapping name with the current palette.
    func reapplyColorMapping() {
        let name = colorMapping.name
        if let mapping = ColorMappings.named(name, palette: selectedPalette) {
            colorMapping = mapping
        }
    }

    /// Load palette and gradient from persisted preferences.
    func loadColorPreferences() {
        if let palette = ColorPalette.named(selectedPaletteName) {
            selectedPalette = palette
        }
        gradientIntensity = gradientIntensityPref
    }

    /// Load an existing scan result (used for duplicate/twin windows).
    func loadScanResult(_ result: ScanResult, url: URL?, filter: NamedFilter? = nil) {
        scanResult = result
        scanURL = url
        scanPhase = .completed
        filteredTree = nil
        zoomRoot = nil
        hoveredNode = nil
        selectedNode = nil
        appliedFilter = filter

        if let mapping = ColorMappings.named(defaultColorMappingName, palette: selectedPalette) {
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
        selectedNode = nil
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

                // Apply pending filter if this was a filtered scan
                if let pendingFilter = pendingFilterAfterScan {
                    appliedFilter = pendingFilter
                    pendingFilterAfterScan = nil
                }

                // Apply default color mapping from preferences
                if let mapping = ColorMappings.named(defaultColorMappingName, palette: selectedPalette) {
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
        case .selected:
            guard let node = selectedNode, let url = fileURL(for: node) else { return }
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
        maskedNodeIDs = []

        guard let scanResult, let appliedFilter else {
            filteredTree = nil
            recomputeDisplayTree()
            return
        }

        if filterMode == .mask {
            // Mask mode: keep all nodes but track which ones fail
            filteredTree = nil
            var masked = Set<UUID>()
            collectMaskedIDs(scanResult.scanTree, filter: appliedFilter.filter, into: &masked)
            maskedNodeIDs = masked
        } else {
            // Filter mode: remove non-matching nodes
            filteredTree = filterTree(scanResult.scanTree, with: appliedFilter.filter)
        }
        recomputeDisplayTree()
    }

    /// Collects IDs of leaf nodes that fail the filter (for mask mode).
    private func collectMaskedIDs(_ node: FileNode, filter: FileFilter, into ids: inout Set<UUID>) {
        if node.isDirectory {
            for child in node.children {
                collectMaskedIDs(child, filter: filter, into: &ids)
            }
        } else {
            if !filter.passes(node) {
                ids.insert(node.id)
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

    // MARK: - Package collapsing

    /// Returns a copy of the tree where packages are treated as opaque files (no children).
    private func collapsePackages(_ node: FileNode) -> FileNode {
        if node.isPackage {
            // Treat as a leaf file — keep size but drop children
            return FileNode(
                name: node.name,
                kind: .file,
                size: node.size,
                creationDate: node.creationDate,
                modificationDate: node.modificationDate,
                accessDate: node.accessDate,
                flags: node.flags,
                type: node.type
            )
        }
        guard node.isDirectory else { return node }
        let collapsed = node.children.map { collapsePackages($0) }
        return FileNode(
            name: node.name,
            kind: node.kind,
            size: node.size,
            children: collapsed,
            creationDate: node.creationDate,
            modificationDate: node.modificationDate,
            accessDate: node.accessDate,
            flags: node.flags,
            type: node.type
        )
    }

    // MARK: - Volume wrapping

    /// Wraps the current display tree in a volume root with free/misc synthetic nodes.
    private func wrapInVolume() -> FileNode? {
        guard let scanResult else { return nil }
        let base = packageCollapsedTree ?? filteredTree ?? scanResult.scanTree

        var children: [FileNode] = [base]

        let misc = scanResult.miscUsedSpace
        if misc > 0 {
            children.append(FileNode(
                name: String(localized: "Misc. used space"),
                kind: .synthetic(.miscUsedSpace),
                size: misc
            ))
        }

        let free = scanResult.freeSpace
        if free > 0 {
            children.append(FileNode(
                name: String(localized: "Free space"),
                kind: .synthetic(.freeSpace),
                size: free
            ))
        }

        let totalSize = children.reduce(UInt64(0)) { $0 + $1.size }
        return FileNode(
            name: scanResult.volumePath,
            kind: .directory,
            size: totalSize,
            children: children
        )
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
        startScan(url: url, sizeMeasure: preferredSizeMeasure)
    }

    /// The size measure derived from the user preference.
    var preferredSizeMeasure: FileSystemScanner.SizeMeasure {
        FileSystemScanner.SizeMeasure(rawValue: fileSizeMeasure) ?? .logical
    }

    /// Pending filter to apply after scan completes (for "Scan with Filter" flow).
    @ObservationIgnored
    var pendingFilterAfterScan: NamedFilter?

    /// Start a scan that will automatically apply a filter once completed.
    func startFilteredScan(url: URL, filter: NamedFilter, sizeMeasure: FileSystemScanner.SizeMeasure = .logical) {
        pendingFilterAfterScan = filter
        startScan(url: url, sizeMeasure: sizeMeasure)
    }

    /// Show folder picker then apply filter after scan. Returns false if user cancelled folder selection.
    func selectFolderForFilteredScan(filter: NamedFilter) -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder to scan with filter"

        guard panel.runModal() == .OK, let url = panel.url else { return false }
        startFilteredScan(url: url, filter: filter)
        return true
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

            if let mapping = ColorMappings.named(defaultColorMappingName, palette: selectedPalette) {
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
