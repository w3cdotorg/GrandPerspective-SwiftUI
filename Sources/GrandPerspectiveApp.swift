import SwiftUI

@main
struct GrandPerspectiveApp: App {
    var body: some Scene {
        // Primary window — each instance gets its own AppState
        WindowGroup {
            ScanWindow()
        }
        .commands {
            ScanCommands()
        }

        // Secondary windows opened via "Duplicate View" / "Twin View"
        WindowGroup(id: "scan") {
            ScanWindow()
        }

        Settings {
            PreferencesView()
        }
    }
}

/// Wrapper that creates a per-window AppState and optionally loads staged data.
struct ScanWindow: View {
    @State private var appState = AppState()

    var body: some View {
        ContentView()
            .environment(appState)
            .onAppear {
                // Sync unit system preference to formatter
                FileNode.useBinaryUnits = (appState.fileSizeUnitSystem == "binary")
                appState.loadColorPreferences()
                appState.filterRepository.loadFromDisk()
                if let transfer = WindowTransfer.shared.consume() {
                    appState.loadScanResult(
                        transfer.scanResult,
                        url: transfer.scanURL,
                        filter: transfer.filter
                    )
                }
            }
    }
}
