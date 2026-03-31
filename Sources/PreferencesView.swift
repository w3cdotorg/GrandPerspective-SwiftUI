import SwiftUI

struct PreferencesView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralPreferencesView()
            }
            Tab("Appearance", systemImage: "paintbrush") {
                AppearancePreferencesView()
            }
            Tab("File Operations", systemImage: "trash") {
                FileOperationsPreferencesView()
            }
        }
        .frame(width: 450, height: 300)
    }
}

// MARK: - General

struct GeneralPreferencesView: View {
    @AppStorage("defaultColorMapping") private var defaultColorMapping = "Files & Folders"
    @AppStorage("defaultRescanAction") private var defaultRescanAction = AppState.RescanScope.all.rawValue

    var body: some View {
        Form {
            Picker(String(localized: "Default color mapping:"), selection: $defaultColorMapping) {
                Text("Files & Folders").tag("Files & Folders")
                Text("Modification Date").tag("Modification Date")
                Text("Creation Date").tag("Creation Date")
                Text("Access Date").tag("Access Date")
                Text("File Type (UTI)").tag("File Type (UTI)")
            }

            Picker(String(localized: "Default rescan action:"), selection: $defaultRescanAction) {
                ForEach(AppState.RescanScope.allCases, id: \.rawValue) { scope in
                    Text(scope.rawValue).tag(scope.rawValue)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Appearance

struct AppearancePreferencesView: View {
    @AppStorage("showFilePath") private var showFilePath = true
    @AppStorage("showStatusBar") private var showStatusBar = true

    var body: some View {
        Form {
            Toggle("Show file path overlay", isOn: $showFilePath)
            Toggle("Show status bar", isOn: $showStatusBar)
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - File Operations

struct FileOperationsPreferencesView: View {
    @AppStorage("fileDeletionTargets") private var fileDeletionTargets = AppState.FileDeletionTargets.onlyFiles.rawValue
    @AppStorage("confirmFileDeletion") private var confirmFileDeletion = true
    @AppStorage("confirmFolderDeletion") private var confirmFolderDeletion = true

    var body: some View {
        Form {
            Picker(String(localized: "Deletion targets:"), selection: $fileDeletionTargets) {
                ForEach(AppState.FileDeletionTargets.allCases, id: \.rawValue) { target in
                    Text(target.rawValue).tag(target.rawValue)
                }
            }

            Section(String(localized: "Confirmations")) {
                Toggle(String(localized: "Confirm before deleting files"), isOn: $confirmFileDeletion)
                Toggle(String(localized: "Confirm before deleting folders"), isOn: $confirmFolderDeletion)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    PreferencesView()
}
