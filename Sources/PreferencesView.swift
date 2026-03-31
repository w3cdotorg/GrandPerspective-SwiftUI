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
        .frame(width: 450, height: 350)
    }
}

// MARK: - General

struct GeneralPreferencesView: View {
    @AppStorage("defaultColorMapping") private var defaultColorMapping = "Files & Folders"
    @AppStorage("defaultRescanAction") private var defaultRescanAction = AppState.RescanScope.all.rawValue
    @AppStorage("fileSizeMeasure") private var fileSizeMeasure = "logical"
    @AppStorage("fileSizeUnitSystem") private var fileSizeUnitSystem = "decimal"

    var body: some View {
        Form {
            Picker(String(localized: "Default color mapping:"), selection: $defaultColorMapping) {
                ForEach(ColorMappings.all, id: \.name) { mapping in
                    Text(mapping.name).tag(mapping.name)
                }
            }

            Picker(String(localized: "Default rescan action:"), selection: $defaultRescanAction) {
                ForEach(AppState.RescanScope.allCases, id: \.rawValue) { scope in
                    Text(scope.rawValue).tag(scope.rawValue)
                }
            }

            Picker(String(localized: "File size measure:"), selection: $fileSizeMeasure) {
                Text(String(localized: "Logical")).tag("logical")
                Text(String(localized: "Physical")).tag("physical")
            }

            Picker(String(localized: "File size units:"), selection: $fileSizeUnitSystem) {
                Text(String(localized: "Decimal (KB, MB, GB)")).tag("decimal")
                Text(String(localized: "Binary (KiB, MiB, GiB)")).tag("binary")
            }
            .onChange(of: fileSizeUnitSystem) {
                FileNode.useBinaryUnits = (fileSizeUnitSystem == "binary")
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
    @AppStorage("selectedPaletteName") private var selectedPaletteName = ColorPalette.default.name
    @AppStorage("gradientIntensityPref") private var gradientIntensityPref = 0.5

    var body: some View {
        Form {
            Toggle("Show file path overlay", isOn: $showFilePath)
            Toggle("Show status bar", isOn: $showStatusBar)

            Picker(String(localized: "Color palette:"), selection: $selectedPaletteName) {
                ForEach(ColorPalette.all) { palette in
                    HStack(spacing: 4) {
                        // Show a small swatch of the palette colors
                        ForEach(0..<min(palette.colors.count, 7), id: \.self) { i in
                            Circle()
                                .fill(palette.colors[i])
                                .frame(width: 10, height: 10)
                        }
                        Text(palette.name)
                    }
                    .tag(palette.name)
                }
            }

            VStack(alignment: .leading) {
                Text(String(localized: "Gradient intensity: \(Int(gradientIntensityPref * 100))%"))
                Slider(value: $gradientIntensityPref, in: 0...1, step: 0.05)
            }
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
