import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    // Sheet state (local to this view)
    @State private var showingFilterPicker = false
    @State private var showingFilterList = false
    @State private var showingImageExport = false
    @State private var showingTypeRanking = false
    @State private var showingTwinFilterPicker = false
    @State private var showingFilteredScanPicker = false
    @State private var showingScanComments = false
    @State private var isDropTargeted = false

    var body: some View {
        @Bindable var state = appState

        Group {
            switch appState.scanPhase {
            case .completed:
                if let scanResult = appState.scanResult {
                    VStack(spacing: 0) {
                        BreadcrumbBar(
                            scanRoot: appState.displayTree ?? scanResult.scanTree,
                            zoomRoot: appState.zoomRoot,
                            onNavigate: { appState.navigateTo($0) }
                        )

                        TreemapCanvasView(
                            scanResult: scanResult,
                            colorMapping: appState.colorMapping,
                            hoveredNode: $state.hoveredNode,
                            zoomRoot: $state.zoomRoot
                        )

                        NodeInfoBar(node: appState.hoveredNode, scanResult: scanResult)
                    }
                }

            case .scanning(let path):
                ScanProgressView(
                    path: path,
                    progress: appState.scanProgress,
                    onCancel: { appState.cancelScan() }
                )

            case .idle:
                WelcomeView(
                    onSelectDirectory: { appState.selectAndScan() },
                    onOpenScan: { appState.openScan() },
                    isDropTargeted: isDropTargeted
                )
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            appState.handleDrop(urls: urls)
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .inspector(isPresented: Binding(
            get: { appState.showInspector },
            set: { appState.showInspector = $0 }
        )) {
            if let scanResult = appState.scanResult {
                InfoPanelView(
                    scanResult: scanResult,
                    selectedNode: appState.selectedNode,
                    hoveredNode: appState.hoveredNode
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(String(localized: "Scan Folder"), systemImage: "folder.badge.gearshape") {
                    appState.selectAndScan()
                }
                .disabled(appState.scanPhase != .idle && appState.scanPhase != .completed)
            }
            if appState.scanResult != nil {
                ToolbarItem {
                    Picker(String(localized: "Colors"), selection: Binding(
                        get: { appState.colorMapping.name },
                        set: { name in
                            if let m = ColorMappings.named(name, palette: appState.selectedPalette) {
                                appState.colorMapping = m
                            }
                        }
                    )) {
                        ForEach(ColorMappings.all(palette: appState.selectedPalette), id: \.name) { mapping in
                            Text(mapping.name).tag(mapping.name)
                        }
                    }
                }
                ToolbarItem {
                    Button(String(localized: "Zoom Out"), systemImage: "arrow.up.left.and.arrow.down.right") {
                        appState.zoomOut()
                    }
                    .disabled(appState.zoomRoot == nil)
                }
                ToolbarItem {
                    Menu {
                        Button(String(localized: "Rescan All")) {
                            appState.rescan(scope: .all)
                        }
                        .disabled(appState.scanURL == nil)
                        Button(String(localized: "Rescan Visible")) {
                            appState.rescan(scope: .visible)
                        }
                        Button(String(localized: "Rescan Selected")) {
                            appState.rescan(scope: .selected)
                        }
                        .disabled(appState.selectedNode == nil)
                    } label: {
                        Label(String(localized: "Rescan"), systemImage: "arrow.clockwise")
                    }
                    .disabled(appState.scanURL == nil)
                }
                ToolbarItem {
                    Menu {
                        Button(String(localized: "Apply Filter...")) { showingFilterPicker = true }
                        Button(String(localized: "Manage Filters...")) { showingFilterList = true }
                        if appState.appliedFilter != nil {
                            Divider()
                            Button(String(localized: "Clear Filter")) { appState.appliedFilter = nil }
                        }
                    } label: {
                        Label(
                            appState.appliedFilter.map { String(localized: "Filter: \($0.name)") }
                                ?? String(localized: "Filters"),
                            systemImage: appState.appliedFilter != nil
                                ? "line.3.horizontal.decrease.circle.fill"
                                : "line.3.horizontal.decrease.circle"
                        )
                    }
                }
                ToolbarItem {
                    Menu {
                        Button(String(localized: "Export Image...")) { showingImageExport = true }
                        Button(String(localized: "File Types...")) { showingTypeRanking = true }
                        Divider()
                        Button(String(localized: "Save Scan...")) { appState.saveScan() }
                    } label: {
                        Label(String(localized: "More"), systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingFilterPicker) {
            FilterPickerView(repository: appState.filterRepository) { filter in
                appState.appliedFilter = filter
            }
        }
        .sheet(isPresented: $showingFilterList) {
            FilterListView(repository: appState.filterRepository)
                .frame(minWidth: 450, minHeight: 350)
        }
        .sheet(isPresented: $showingImageExport) {
            if let scanResult = appState.scanResult {
                ImageExportView(
                    scanResult: scanResult,
                    colorMapping: appState.colorMapping,
                    zoomRoot: appState.zoomRoot
                )
            }
        }
        .sheet(isPresented: $showingTypeRanking) {
            if let scanResult = appState.scanResult {
                TypeRankingView(scanResult: scanResult)
            }
        }
        .alert(
            appState.pendingDeletion?.message ?? "",
            isPresented: Binding(
                get: { appState.pendingDeletion != nil },
                set: { if !$0 { appState.cancelPendingDeletion() } }
            )
        ) {
            Button(String(localized: "Cancel"), role: .cancel) {
                appState.cancelPendingDeletion()
            }
            Button(String(localized: "Move to Trash"), role: .destructive) {
                appState.confirmPendingDeletion()
            }
        } message: {
            if let warning = appState.pendingDeletion?.warning {
                Text(warning)
            }
        }
        .alert(String(localized: "Scan Error"), isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button(String(localized: "OK")) { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
        .frame(minWidth: 600, minHeight: 400)
        .navigationTitle(appState.windowTitle)
        .modifier(CommandNotificationHandler(
            appState: appState,
            openWindow: openWindow,
            showingTwinFilterPicker: $showingTwinFilterPicker,
            showingFilteredScanPicker: $showingFilteredScanPicker,
            showingScanComments: $showingScanComments
        ))
        .sheet(isPresented: $showingTwinFilterPicker) {
            FilterPickerView(repository: appState.filterRepository) { filter in
                guard let scanResult = appState.scanResult else { return }
                WindowTransfer.shared.stage(
                    scanResult: scanResult,
                    scanURL: appState.scanURL,
                    filter: filter
                )
                openWindow(id: "scan")
            }
        }
        .sheet(isPresented: $showingFilteredScanPicker) {
            FilterPickerView(repository: appState.filterRepository) { filter in
                guard let filter else { return }
                _ = appState.selectFolderForFilteredScan(filter: filter)
            }
        }
        .sheet(isPresented: $showingScanComments) {
            if let scanResult = appState.scanResult {
                ScanCommentsView(scanResult: scanResult)
            }
        }
    }
}

// MARK: - Command Notification Handler

/// Extracted to reduce body complexity and avoid type-checker timeouts.
private struct CommandNotificationHandler: ViewModifier {
    let appState: AppState
    let openWindow: OpenWindowAction
    @Binding var showingTwinFilterPicker: Bool
    @Binding var showingFilteredScanPicker: Bool
    @Binding var showingScanComments: Bool

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .rescanDefault)) { _ in
                let scope = AppState.RescanScope(rawValue: appState.defaultRescanAction) ?? .all
                appState.rescan(scope: scope)
            }
            .onReceive(NotificationCenter.default.publisher(for: .rescanAll)) { _ in
                appState.rescan(scope: .all)
            }
            .onReceive(NotificationCenter.default.publisher(for: .rescanVisible)) { _ in
                appState.rescan(scope: .visible)
            }
            .onReceive(NotificationCenter.default.publisher(for: .rescanSelected)) { _ in
                appState.rescan(scope: .selected)
            }
            .onReceive(NotificationCenter.default.publisher(for: .scanWithFilter)) { _ in
                showingFilteredScanPicker = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleInspector)) { _ in
                appState.showInspector.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleMask)) { _ in
                appState.filterMode = appState.filterMode == .filter ? .mask : .filter
            }
            .onReceive(NotificationCenter.default.publisher(for: .togglePackageContents)) { _ in
                appState.showPackageContents.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleEntireVolume)) { _ in
                appState.showEntireVolume.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .duplicateView)) { _ in
                guard let scanResult = appState.scanResult else { return }
                WindowTransfer.shared.stage(scanResult: scanResult, scanURL: appState.scanURL)
                openWindow(id: "scan")
            }
            .onReceive(NotificationCenter.default.publisher(for: .twinView)) { _ in
                guard appState.scanResult != nil else { return }
                showingTwinFilterPicker = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .editScanComments)) { _ in
                guard appState.scanResult != nil else { return }
                showingScanComments = true
            }
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    var onSelectDirectory: () -> Void
    var onOpenScan: () -> Void = {}
    var isDropTargeted: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 64))
                .foregroundStyle(isDropTargeted ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .scaleEffect(isDropTargeted ? 1.15 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isDropTargeted)

            Text("GrandPerspective")
                .font(.largeTitle)

            if isDropTargeted {
                Text(String(localized: "Drop folder to scan"))
                    .foregroundStyle(.tint)
                    .fontWeight(.medium)
            } else {
                Text(String(localized: "Select a folder to visualize its disk usage."))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button(String(localized: "Choose Folder...")) {
                    onSelectDirectory()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(String(localized: "Open Scan...")) {
                    onOpenScan()
                }
                .controlSize(.large)
            }
        }
        .padding(40)
    }
}

// MARK: - Treemap View (convenience wrapper for tests)

struct TreemapView: View {
    let scanResult: ScanResult
    let colorMapping: any ColorMapping
    @Binding var hoveredNode: FileNode?

    var body: some View {
        TreemapCanvasView(
            scanResult: scanResult,
            colorMapping: colorMapping,
            hoveredNode: $hoveredNode,
            zoomRoot: .constant(nil)
        )
    }
}

// MARK: - Info Bar

struct NodeInfoBar: View {
    let node: FileNode?
    let scanResult: ScanResult

    var body: some View {
        HStack(spacing: 8) {
            if let node {
                Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                    .foregroundStyle(.secondary)
                Text(node.path)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                if node.isDirectory {
                    Text(String(localized: "\(node.fileCount) files"))
                        .foregroundStyle(.secondary)
                }
                Text(node.formattedSize)
                    .monospacedDigit()
                    .fontWeight(.medium)
            } else {
                Spacer()
            }
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(node.map { String(localized: "\($0.name), \($0.formattedSize)") } ?? "")
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
