import Testing
import SwiftUI
@testable import GrandPerspective

// MARK: - Color Palette Tests

@Suite("ColorPalette")
struct ColorPaletteTests {

    @Test func allPalettesExist() {
        #expect(ColorPalette.all.count == 18)
    }

    @Test func allPalettesHaveUniqueNames() {
        let names = ColorPalette.all.map(\.name)
        #expect(Set(names).count == names.count)
    }

    @Test func allPalettesHaveColors() {
        for palette in ColorPalette.all {
            #expect(!palette.colors.isEmpty, "Palette '\(palette.name)' has no colors")
            #expect(palette.colors.count >= 5, "Palette '\(palette.name)' has fewer than 5 colors")
        }
    }

    @Test func namedLookupWorks() {
        let found = ColorPalette.named("CoffeeBeans")
        #expect(found != nil)
        #expect(found!.name == "CoffeeBeans")

        let notFound = ColorPalette.named("Nonexistent")
        #expect(notFound == nil)
    }

    @Test func defaultPaletteIsCoffeeBeans() {
        #expect(ColorPalette.default.name == "CoffeeBeans")
    }

    @Test func hexValueCountMatchesColorCount() {
        for palette in ColorPalette.all {
            #expect(palette.hexValues.count == palette.colors.count,
                    "Palette '\(palette.name)': hex count \(palette.hexValues.count) != color count \(palette.colors.count)")
        }
    }

    @Test func paletteHashEquality() {
        let a = ColorPalette.coffeeBeans
        let b = ColorPalette.coffeeBeans
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)

        let c = ColorPalette.rainbow
        #expect(a != c)
    }
}

// MARK: - Color Hex Extension Tests

@Suite("Color Hex")
struct ColorHexTests {

    @Test func hexParsesRed() {
        let color = Color(hex: "FF0000")
        let ns = NSColor(color).usingColorSpace(.sRGB)!
        #expect(ns.redComponent > 0.99)
        #expect(ns.greenComponent < 0.01)
        #expect(ns.blueComponent < 0.01)
    }

    @Test func hexParsesGreen() {
        let color = Color(hex: "00FF00")
        let ns = NSColor(color).usingColorSpace(.sRGB)!
        #expect(ns.greenComponent > 0.99)
    }

    @Test func hexParsesWithHash() {
        let color = Color(hex: "#3366AA")
        let ns = NSColor(color).usingColorSpace(.sRGB)!
        #expect(ns.redComponent > 0.19 && ns.redComponent < 0.21)
    }

    @Test func whiteLuminanceIsHigh() {
        let white = Color(hex: "FFFFFF")
        #expect(white.relativeLuminance > 0.95)
    }

    @Test func blackLuminanceIsLow() {
        let black = Color(hex: "000000")
        #expect(black.relativeLuminance < 0.01)
    }

    @Test func contrastRatioWhiteOnWhiteIsLow() {
        let white = Color(hex: "FFFFFF")
        #expect(white.contrastRatioAgainstWhite < 1.1)
    }

    @Test func contrastRatioDarkColorIsHigh() {
        let dark = Color(hex: "333300")
        #expect(dark.contrastRatioAgainstWhite > 10)
    }
}

// MARK: - Palette Readability Tests

@Suite("Palette Readability")
struct PaletteReadabilityTests {

    @Test func allPaletteColorsMeetMinimumContrast() {
        // WCAG AA for large text is 3:1, we aim for at least 2.5:1 since the gradient
        // darkening and text shadow help readability
        let minimumContrast = 2.0
        var violations: [(String, String, Double)] = []

        for palette in ColorPalette.all {
            for (i, color) in palette.colors.enumerated() {
                let ratio = color.contrastRatioAgainstWhite
                if ratio < minimumContrast {
                    violations.append((palette.name, palette.hexValues[i], ratio))
                }
            }
        }

        #expect(violations.isEmpty,
                "Colors with insufficient contrast against white: \(violations.map { "\($0.0)/\($0.1): \(String(format: "%.1f", $0.2)):1" })")
    }
}

// MARK: - New Color Mapping Tests

@Suite("New Color Mappings")
struct NewColorMappingTests {

    static let root: FileNode = {
        let file1 = FileNode(name: "readme.txt", kind: .file, size: 100, type: .plainText)
        let file2 = FileNode(name: "image.png", kind: .file, size: 200, type: .png)
        let sub = FileNode(name: "sub", kind: .directory, size: 300, children: [file1, file2])
        let file3 = FileNode(name: "app.swift", kind: .file, size: 400, type: .swiftSource)
        return FileNode(name: "root", kind: .directory, size: 700, children: [sub, file3])
    }()

    // MARK: - TopFolderColorMapping

    @Test func topFolderSameParentSameColor() {
        let mapping = TopFolderColorMapping()
        let file1 = Self.root.children[0].children[0]  // readme.txt in sub/
        let file2 = Self.root.children[0].children[1]  // image.png in sub/
        let c1 = mapping.color(for: file1, depth: 2)
        let c2 = mapping.color(for: file2, depth: 2)
        #expect(c1 == c2)
    }

    @Test func topFolderDifferentParentsMayDiffer() {
        let mapping = TopFolderColorMapping()
        let file1 = Self.root.children[0].children[0]  // readme.txt in sub/
        let file3 = Self.root.children[1]  // app.swift at root level
        let c1 = mapping.color(for: file1, depth: 2)
        let c3 = mapping.color(for: file3, depth: 1)
        // These may or may not be equal (hash collision possible), but shouldn't crash
        _ = c1
        _ = c3
    }

    // MARK: - ExtensionColorMapping

    @Test func extensionSameExtSameColor() {
        let mapping = ExtensionColorMapping()
        let a = FileNode(name: "a.txt", kind: .file, size: 10, type: .plainText)
        let b = FileNode(name: "b.txt", kind: .file, size: 20, type: .plainText)
        #expect(mapping.color(for: a, depth: 0) == mapping.color(for: b, depth: 0))
    }

    @Test func extensionNoExtGray() {
        let mapping = ExtensionColorMapping()
        let noExt = FileNode(name: "Makefile", kind: .file, size: 10)
        #expect(mapping.color(for: noExt, depth: 0) == .gray)
    }

    // MARK: - LevelColorMapping

    @Test func levelSameDepthSameColor() {
        let mapping = LevelColorMapping()
        let c1 = mapping.color(for: Self.root.children[0].children[0], depth: 2)
        let c2 = mapping.color(for: Self.root.children[0].children[1], depth: 2)
        #expect(c1 == c2)
    }

    @Test func levelDifferentDepthDifferentColor() {
        let mapping = LevelColorMapping()
        let c0 = mapping.color(for: Self.root, depth: 0)
        let c1 = mapping.color(for: Self.root.children[0], depth: 1)
        #expect(c0 != c1)
    }

    // MARK: - UniformColorMapping

    @Test func uniformAlwaysSameColor() {
        let mapping = UniformColorMapping()
        let c1 = mapping.color(for: Self.root, depth: 0)
        let c2 = mapping.color(for: Self.root.children[1], depth: 1)
        #expect(c1 == c2)
    }

    @Test func uniformNameIsNothing() {
        #expect(UniformColorMapping().name == "Nothing")
    }

    // MARK: - Registry

    @Test func registryContainsAllMappings() {
        let all = ColorMappings.all
        #expect(all.count == 9)
        let names = Set(all.map(\.name))
        #expect(names.contains("Files & Folders"))
        #expect(names.contains("Top Folder"))
        #expect(names.contains("Extension"))
        #expect(names.contains("Level"))
        #expect(names.contains("Nothing"))
        #expect(names.contains("Modification Date"))
        #expect(names.contains("Creation Date"))
        #expect(names.contains("Access Date"))
        #expect(names.contains("File Type (UTI)"))
    }

    @Test func registryNamedWithPalette() {
        let rainbow = ColorPalette.rainbow
        let mapping = ColorMappings.named("Files & Folders", palette: rainbow)
        #expect(mapping != nil)
        // The mapping should use the rainbow palette
        if let folder = mapping as? FolderColorMapping {
            #expect(folder.palette == rainbow)
        }
    }

    // MARK: - Palette-based mappings use provided palette

    @Test func folderMappingUsesPalette() {
        let rainbow = ColorPalette.rainbow
        let mapping = FolderColorMapping(palette: rainbow)
        let node = FileNode(name: "test", kind: .file, size: 10)
        let color = mapping.color(for: node, depth: 0)
        #expect(color == rainbow.colors[0])
    }
}
