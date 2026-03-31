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

// MARK: - Color Palette

/// A named collection of colors for treemap rendering.
/// Ported from the 18 legacy palettes in ColorListCreator.m.
///
/// All hex values are chosen for adequate contrast against white text labels.
struct ColorPalette: Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let colors: [Color]

    /// The hex strings used to build this palette (for testing/introspection).
    let hexValues: [String]

    init(name: String, hexValues: [String]) {
        self.id = name
        self.name = name
        self.hexValues = hexValues
        self.colors = hexValues.map { Color(hex: $0) }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ColorPalette, rhs: ColorPalette) -> Bool { lhs.id == rhs.id }
}

// MARK: - All Palettes

extension ColorPalette {
    /// The 18 legacy palettes from GrandPerspective, ported from ColorListCreator.m.
    /// Colors are tuned for readability: white text on these backgrounds should always be legible.
    static let all: [ColorPalette] = [
        coffeeBeans, pastelPapageno, blueSkyTulips, monaco,
        warmFall, mossAndLichen, matbord, bujumbura,
        autumn, oliveSunset, rainbow, origamiMice,
        greenEggs, fengShui, daytona, flyingGeese,
        lagoonNebula, autumnBlush,
    ]

    static let coffeeBeans = ColorPalette(name: "CoffeeBeans", hexValues: [
        "CC3333", "CC9933", "CCAA44", "CC6633", "CC6666", "993300", "666600",
    ])

    static let pastelPapageno = ColorPalette(name: "Pastel Papageno", hexValues: [
        "44BB77", "AA9922", "DD9944", "CC4488", "4499CC",
    ])

    static let blueSkyTulips = ColorPalette(name: "Blue Sky Tulips", hexValues: [
        "77AA44", "336600", "333399", "CC6666", "CC7799", "DD3333", "CCAA44",
    ])

    static let monaco = ColorPalette(name: "Monaco", hexValues: [
        "6666BB", "2288BB", "33AABB", "33AA33", "CC2233", "CC4422", "CC7722",
    ])

    static let warmFall = ColorPalette(name: "Warm Fall", hexValues: [
        "AAAA00", "999900", "666600", "333300", "CC6600", "996600", "663300",
        "DD5500", "DD8800", "CCAA00",
    ])

    static let mossAndLichen = ColorPalette(name: "Moss and Lichen", hexValues: [
        "666633", "889966", "889966", "999966", "6699AA", "009999", "006666", "003333",
    ])

    static let matbord = ColorPalette(name: "Matbord", hexValues: [
        "999944", "CCAA44", "BB6644", "AA0818", "333344",
    ])

    static let bujumbura = ColorPalette(name: "Bujumbura", hexValues: [
        "BB3300", "BB6600", "664422", "BB8844", "AA9922", "88AA00", "3388CC",
    ])

    static let autumn = ColorPalette(name: "Autumn", hexValues: [
        "666633", "336666", "993333", "CCAA00", "DD8800",
    ])

    static let oliveSunset = ColorPalette(name: "Olive Sunset", hexValues: [
        "6688AA", "3399CC", "006699", "003366", "666600", "999900", "888822",
        "998866", "999966", "CC7733", "CC0033", "990033",
    ])

    static let rainbow = ColorPalette(name: "Rainbow", hexValues: [
        "AA9922", "88AA33", "55AA44", "33992E", "2DAA88", "3399BB", "3377BB",
        "3355BB", "4433BB", "7733BB", "BB33BB", "CC3377", "DD4444", "DD6644",
        "CC7733", "BB8822",
    ])

    static let origamiMice = ColorPalette(name: "Origami Mice", hexValues: [
        "BB4488", "44AABB", "BB1100", "777755", "005544", "44AA00", "7766AA",
        "CC9933", "AABB00",
    ])

    static let greenEggs = ColorPalette(name: "Green Eggs", hexValues: [
        "3399AA", "AA77AA", "AA8855", "CC4488", "DD2222", "0088BB", "999900",
        "BB8822", "999944", "559933", "88AA00", "448866",
    ])

    static let fengShui = ColorPalette(name: "Feng Shui", hexValues: [
        "CC3322", "CC6600", "BB8800", "AA8800", "999922", "669944", "559977",
        "558899", "0066BB",
    ])

    static let daytona = ColorPalette(name: "Daytona", hexValues: [
        "996600", "CC9933", "888833", "999955", "3388DD", "558899", "003399",
        "449944", "33AA22", "339900",
    ])

    static let flyingGeese = ColorPalette(name: "Flying Geese", hexValues: [
        "CC33BB", "BB33BB", "7744BB", "446688", "3388BB", "556644", "888844",
        "BBAA33", "CCAA33",
    ])

    static let lagoonNebula = ColorPalette(name: "Lagoon Nebula", hexValues: [
        "BB9933", "552222", "88AABB", "CC8844", "664444", "BB5555", "88BB88", "334477",
    ])

    static let autumnBlush = ColorPalette(name: "Autumn Blush", hexValues: [
        "990044", "BB5533", "CC9933", "AA8833", "449988", "889999", "553322",
        "887766", "999977",
    ])

    /// The default palette used when none is selected.
    static let `default` = coffeeBeans

    static func named(_ name: String) -> ColorPalette? {
        all.first { $0.name == name }
    }
}

// MARK: - Hex Color Extension

extension Color {
    /// Creates a Color from a hex string (e.g. "CC3333" or "#CC3333").
    init(hex: String) {
        let sanitized = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let scanner = Scanner(string: sanitized)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)

        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    /// Returns the relative luminance (WCAG) of this color.
    var relativeLuminance: Double {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.gray
        func linearize(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let r = linearize(ns.redComponent)
        let g = linearize(ns.greenComponent)
        let b = linearize(ns.blueComponent)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /// WCAG contrast ratio against white (1.0..21.0).
    var contrastRatioAgainstWhite: Double {
        let whiteLum = 1.0
        let lum = relativeLuminance
        return (whiteLum + 0.05) / (lum + 0.05)
    }
}

// MARK: - Implementations

/// Colors by directory depth (the "folder" default from legacy).
/// Uses a selected palette for cycling through depths.
struct FolderColorMapping: ColorMapping {
    let name = "Files & Folders"
    let canProvideLegend = false

    let palette: ColorPalette

    init(palette: ColorPalette = .default) {
        self.palette = palette
    }

    func color(for node: FileNode, depth: Int) -> Color {
        palette.colors[depth % palette.colors.count]
    }

    static let defaultPalette: [Color] = ColorPalette.default.colors
}

/// Colors by top-level folder: all files in the same top-level directory share one color.
struct TopFolderColorMapping: ColorMapping {
    let name = "Top Folder"
    let canProvideLegend = false

    let palette: ColorPalette

    init(palette: ColorPalette = .default) {
        self.palette = palette
    }

    func color(for node: FileNode, depth: Int) -> Color {
        // Find the top-level ancestor (child of root)
        let ancestors = node.ancestors
        // ancestors[0] is root, ancestors[1] is top-level child
        let topIndex: Int
        if ancestors.count >= 2 {
            // Use the top-level folder (second element) to pick a color
            topIndex = topFolderIndex(ancestors[1])
        } else {
            topIndex = 0
        }
        return palette.colors[topIndex % palette.colors.count]
    }

    /// Deterministic index from node name (stable across rerenders).
    private func topFolderIndex(_ node: FileNode) -> Int {
        var hash = 0
        for c in node.name.unicodeScalars {
            hash = hash &* 31 &+ Int(c.value)
        }
        return abs(hash)
    }
}

/// Colors by file extension: files with the same extension share one color.
struct ExtensionColorMapping: ColorMapping {
    let name = "Extension"
    let canProvideLegend = false

    let palette: ColorPalette

    init(palette: ColorPalette = .default) {
        self.palette = palette
    }

    func color(for node: FileNode, depth: Int) -> Color {
        let ext = (node.name as NSString).pathExtension.lowercased()
        guard !ext.isEmpty else { return .gray }
        var hash = 0
        for c in ext.unicodeScalars {
            hash = hash &* 31 &+ Int(c.value)
        }
        return palette.colors[abs(hash) % palette.colors.count]
    }
}

/// Colors by depth level: same depth = same color regardless of parent.
struct LevelColorMapping: ColorMapping {
    let name = "Level"
    let canProvideLegend = false

    let palette: ColorPalette

    init(palette: ColorPalette = .default) {
        self.palette = palette
    }

    func color(for node: FileNode, depth: Int) -> Color {
        palette.colors[depth % palette.colors.count]
    }
}

/// Uniform gray — "Nothing" mapping, all nodes get the same color.
struct UniformColorMapping: ColorMapping {
    let name = "Nothing"
    let canProvideLegend = false

    func color(for node: FileNode, depth: Int) -> Color {
        Color(red: 0.45, green: 0.55, blue: 0.65)
    }
}

/// Colors by modification date.
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
        (.movie, Color(hex: "8844AA")),       // purple — good contrast
        (.audio, Color(hex: "CC7722")),        // warm orange
        (.image, Color(hex: "338833")),         // forest green
        (.archive, Color(hex: "885533")),       // brown
        (.application, Color(hex: "3366AA")),   // medium blue
        (.bundle, Color(hex: "5544AA")),        // indigo
        (.executable, Color(hex: "227799")),    // teal-cyan
        (.font, Color(hex: "AA3366")),          // dark pink
        (.log, Color(hex: "666666")),           // gray
        (.sourceCode, Color(hex: "998800")),    // olive yellow
        (.text, Color(hex: "339988")),          // teal
        (.pdf, Color(hex: "CC2233")),           // red
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
    static func all(palette: ColorPalette = .default) -> [any ColorMapping] {
        [
            FolderColorMapping(palette: palette),
            TopFolderColorMapping(palette: palette),
            ExtensionColorMapping(palette: palette),
            LevelColorMapping(palette: palette),
            UniformColorMapping(),
            ModificationDateColorMapping(),
            CreationDateColorMapping(),
            AccessDateColorMapping(),
            FileTypeColorMapping(),
        ]
    }

    /// Convenience accessor using the default palette.
    static let all: [any ColorMapping] = all()

    static func named(_ name: String, palette: ColorPalette = .default) -> (any ColorMapping)? {
        all(palette: palette).first { $0.name == name }
    }
}
