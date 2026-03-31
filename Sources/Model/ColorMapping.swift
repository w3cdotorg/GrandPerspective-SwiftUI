import SwiftUI
import UniformTypeIdentifiers

/// Maps a FileNode to a color for treemap rendering.
/// Replaces FileItemMappingScheme / FileItemMapping / StatelessFileItemMapping.
protocol ColorMapping: Sendable {
    /// Returns a color for the given node at the given depth in the tree.
    func color(for node: FileNode, depth: Int) -> Color

    /// Human-readable name for this mapping.
    var name: String { get }

    /// Whether this mapping can provide a legend.
    var canProvideLegend: Bool { get }
}

extension ColorMapping {
    var canProvideLegend: Bool { false }
}

// MARK: - Implementations

/// Colors by directory depth (the "folder" default from legacy).
struct FolderColorMapping: ColorMapping {
    let name = "Files & Folders"
    let canProvideLegend = false

    private let palette: [Color]

    init(palette: [Color] = Self.defaultPalette) {
        self.palette = palette
    }

    func color(for node: FileNode, depth: Int) -> Color {
        palette[depth % palette.count]
    }

    static let defaultPalette: [Color] = [
        .blue, .green, .orange, .purple, .red, .yellow, .teal, .indigo, .pink, .mint
    ]
}

/// Colors by file modification date.
struct ModificationDateColorMapping: ColorMapping {
    let name = "Modification Date"
    let canProvideLegend = true
    let referenceDate: Date
    let gradient: Gradient

    init(
        referenceDate: Date = Date(timeIntervalSinceReferenceDate: 0),
        gradient: Gradient = Gradient(colors: [.blue, .green, .yellow, .red])
    ) {
        self.referenceDate = referenceDate
        self.gradient = gradient
    }

    func color(for node: FileNode, depth: Int) -> Color {
        guard let date = node.modificationDate else { return .gray }
        let age = Date.now.timeIntervalSince(date)
        let maxAge = Date.now.timeIntervalSince(referenceDate)
        let ratio = min(max(age / maxAge, 0), 1)
        return colorFromGradient(at: ratio)
    }

    fileprivate func colorFromGradient(at position: Double) -> Color {
        let stops = gradient.stops
        guard stops.count >= 2 else { return stops.first?.color ?? .gray }
        let clamped = min(max(position, 0), 1)

        for i in 0..<(stops.count - 1) {
            let current = stops[i]
            let next = stops[i + 1]
            if clamped >= current.location && clamped <= next.location {
                let range = next.location - current.location
                let t = range > 0 ? (clamped - current.location) / range : 0
                return blend(current.color, next.color, t: t)
            }
        }
        return stops.last!.color
    }

    private func blend(_ a: Color, _ b: Color, t: Double) -> Color {
        // Simple linear interpolation via resolved colors
        let ra = NSColor(a).usingColorSpace(.deviceRGB) ?? NSColor.gray
        let rb = NSColor(b).usingColorSpace(.deviceRGB) ?? NSColor.gray
        return Color(
            red: ra.redComponent * (1 - t) + rb.redComponent * t,
            green: ra.greenComponent * (1 - t) + rb.greenComponent * t,
            blue: ra.blueComponent * (1 - t) + rb.blueComponent * t
        )
    }
}

/// Colors by creation date.
struct CreationDateColorMapping: ColorMapping {
    let name = "Creation Date"
    private let inner: ModificationDateColorMapping

    init(referenceDate: Date = Date(timeIntervalSinceReferenceDate: 0)) {
        self.inner = ModificationDateColorMapping(referenceDate: referenceDate)
    }

    func color(for node: FileNode, depth: Int) -> Color {
        guard let date = node.creationDate else { return .gray }
        let age = Date.now.timeIntervalSince(date)
        let maxAge = Date.now.timeIntervalSince(inner.referenceDate)
        let ratio = min(max(age / maxAge, 0), 1)
        return inner.colorFromGradient(at: ratio)
    }
}

/// Colors by access date.
struct AccessDateColorMapping: ColorMapping {
    let name = "Access Date"
    private let inner: ModificationDateColorMapping

    init(referenceDate: Date = Date(timeIntervalSinceReferenceDate: 0)) {
        self.inner = ModificationDateColorMapping(referenceDate: referenceDate)
    }

    func color(for node: FileNode, depth: Int) -> Color {
        guard let date = node.accessDate else { return .gray }
        let age = Date.now.timeIntervalSince(date)
        let maxAge = Date.now.timeIntervalSince(inner.referenceDate)
        let ratio = min(max(age / maxAge, 0), 1)
        return inner.colorFromGradient(at: ratio)
    }
}

/// Colors by UTType category.
struct FileTypeColorMapping: ColorMapping {
    let name = "File Type (UTI)"
    let canProvideLegend = true

    private let typeColors: [(UTType, Color)] = [
        (.movie, .purple),
        (.audio, .orange),
        (.image, .green),
        (.archive, .brown),
        (.application, .blue),
        (.bundle, .indigo),
        (.executable, .cyan),
        (.font, .pink),
        (.log, .gray),
        (.sourceCode, .yellow),
        (.text, .mint),
        (.pdf, .red),
    ]

    func color(for node: FileNode, depth: Int) -> Color {
        guard let nodeType = node.type else { return .secondary }
        for (type, color) in typeColors {
            if nodeType.conforms(to: type) { return color }
        }
        return .secondary
    }
}

// MARK: - Registry

/// All available color mappings.
enum ColorMappings {
    static let all: [any ColorMapping] = [
        FolderColorMapping(),
        ModificationDateColorMapping(),
        CreationDateColorMapping(),
        AccessDateColorMapping(),
        FileTypeColorMapping(),
    ]

    static func named(_ name: String) -> (any ColorMapping)? {
        all.first { $0.name == name }
    }
}
