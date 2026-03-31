import Foundation

/// Lightweight transfer mechanism for passing scan data to new windows.
/// Staged data is consumed once by the first window that reads it.
@MainActor
final class WindowTransfer {
    static let shared = WindowTransfer()

    private var pendingScanResult: ScanResult?
    private var pendingScanURL: URL?
    private var pendingFilter: NamedFilter?

    private init() {}

    func stage(scanResult: ScanResult, scanURL: URL?, filter: NamedFilter? = nil) {
        pendingScanResult = scanResult
        pendingScanURL = scanURL
        pendingFilter = filter
    }

    /// Consume the staged data. Returns nil if nothing is staged.
    func consume() -> (scanResult: ScanResult, scanURL: URL?, filter: NamedFilter?)? {
        guard let result = pendingScanResult else { return nil }
        let url = pendingScanURL
        let filter = pendingFilter
        pendingScanResult = nil
        pendingScanURL = nil
        pendingFilter = nil
        return (result, url, filter)
    }
}
