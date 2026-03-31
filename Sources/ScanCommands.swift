import SwiftUI

struct ScanCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button(String(localized: "Scan Folder...", comment: "Menu item to start a new folder scan")) {
                NotificationCenter.default.post(name: .scanDirectory, object: nil)
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Button(String(localized: "Open Scan...", comment: "Menu item to open a saved .gpscan file")) {
                NotificationCenter.default.post(name: .openScan, object: nil)
            }
            .keyboardShortcut("o", modifiers: [.command])

            Button(String(localized: "Scan with Filter...", comment: "Menu item to scan a folder with a pre-selected filter")) {
                NotificationCenter.default.post(name: .scanWithFilter, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button(String(localized: "Save Scan...", comment: "Menu item to save scan results")) {
                NotificationCenter.default.post(name: .saveScan, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command])

            Divider()
        }

        CommandMenu(String(localized: "View", comment: "Menu title for view commands")) {
            Button(String(localized: "Rescan", comment: "Menu item to rescan using default scope")) {
                NotificationCenter.default.post(name: .rescanDefault, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command])

            Button(String(localized: "Rescan All", comment: "Menu item to rescan the entire folder")) {
                NotificationCenter.default.post(name: .rescanAll, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button(String(localized: "Rescan Visible", comment: "Menu item to rescan visible subtree")) {
                NotificationCenter.default.post(name: .rescanVisible, object: nil)
            }

            Button(String(localized: "Rescan Selected", comment: "Menu item to rescan only the selected item")) {
                NotificationCenter.default.post(name: .rescanSelected, object: nil)
            }

            Divider()

            Button(String(localized: "Show Inspector", comment: "Menu item to toggle the inspector panel")) {
                NotificationCenter.default.post(name: .toggleInspector, object: nil)
            }
            .keyboardShortcut("i", modifiers: [.command, .option])

            Divider()

            Button(String(localized: "Toggle Mask", comment: "Menu item to toggle filter mask mode")) {
                NotificationCenter.default.post(name: .toggleMask, object: nil)
            }
            .keyboardShortcut("m", modifiers: [.command, .option])

            Button(String(localized: "Show Package Contents", comment: "Menu item to toggle package contents visibility")) {
                NotificationCenter.default.post(name: .togglePackageContents, object: nil)
            }

            Button(String(localized: "Show Entire Volume", comment: "Menu item to toggle entire volume display")) {
                NotificationCenter.default.post(name: .toggleEntireVolume, object: nil)
            }

            Divider()

            Button(String(localized: "Duplicate View", comment: "Menu item to duplicate current window")) {
                NotificationCenter.default.post(name: .duplicateView, object: nil)
            }
            .keyboardShortcut("d", modifiers: [.command])

            Button(String(localized: "Twin View (Filtered)", comment: "Menu item to open twin filtered window")) {
                NotificationCenter.default.post(name: .twinView, object: nil)
            }
        }

        CommandGroup(after: .pasteboard) {
            Divider()
            Button(String(localized: "Edit Scan Comments...", comment: "Menu item to edit scan comments")) {
                NotificationCenter.default.post(name: .editScanComments, object: nil)
            }
        }

        CommandMenu(String(localized: "Analysis", comment: "Menu title for analysis tools")) {
            Button(String(localized: "Apply Filter...", comment: "Menu item to apply a filter")) {
                NotificationCenter.default.post(name: .showFilterPicker, object: nil)
            }
            .keyboardShortcut("f", modifiers: [.command, .option])

            Button(String(localized: "Manage Filters...", comment: "Menu item to manage saved filters")) {
                NotificationCenter.default.post(name: .showFilterList, object: nil)
            }

            Divider()

            Button(String(localized: "File Types...", comment: "Menu item to show file type ranking")) {
                NotificationCenter.default.post(name: .showTypeRanking, object: nil)
            }
            .keyboardShortcut("t", modifiers: [.command, .option])

            Divider()

            Button(String(localized: "Export Image...", comment: "Menu item to export treemap as image")) {
                NotificationCenter.default.post(name: .showImageExport, object: nil)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
        }
    }
}

extension Notification.Name {
    static let scanDirectory = Notification.Name("scanDirectory")
    static let openScan = Notification.Name("openScan")
    static let saveScan = Notification.Name("saveScan")
    static let showFilterPicker = Notification.Name("showFilterPicker")
    static let showFilterList = Notification.Name("showFilterList")
    static let showImageExport = Notification.Name("showImageExport")
    static let showTypeRanking = Notification.Name("showTypeRanking")
    static let scanWithFilter = Notification.Name("scanWithFilter")
    static let rescanDefault = Notification.Name("rescanDefault")
    static let rescanAll = Notification.Name("rescanAll")
    static let rescanVisible = Notification.Name("rescanVisible")
    static let rescanSelected = Notification.Name("rescanSelected")
    static let toggleInspector = Notification.Name("toggleInspector")
    static let editScanComments = Notification.Name("editScanComments")
    static let toggleMask = Notification.Name("toggleMask")
    static let togglePackageContents = Notification.Name("togglePackageContents")
    static let toggleEntireVolume = Notification.Name("toggleEntireVolume")
    static let duplicateView = Notification.Name("duplicateView")
    static let twinView = Notification.Name("twinView")
}
