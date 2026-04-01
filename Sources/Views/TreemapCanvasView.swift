import SwiftUI

/// Full-featured treemap renderer with gradient fills, hover, click-to-zoom, and labels.
/// Replaces DirectoryView + TreeDrawer + GradientRectangleDrawer + ItemPathDrawer.
///
/// Performance optimizations for large scans (500K+ files):
/// - Layout computed once and cached (not per-frame in the Canvas closure)
/// - Small directories collapsed to solid leaf rects (no white gaps)
/// - Grid-based spatial index for O(1) hit testing
/// - Color components pre-resolved once (no NSColor conversion per rect per frame)
/// - Flat fill for small rects, gradient only for rects > 400 px²
/// - Hover only updates state when the node actually changes
struct TreemapCanvasView: View {
    let scanResult: ScanResult
    let colorMapping: any ColorMapping

    @Binding var hoveredNode: FileNode?
    @Binding var zoomRoot: FileNode?

    @Environment(AppState.self) private var appState

    @State private var cachedRects: [TreemapRect] = []
    @State private var spatialIndex: TreemapSpatialIndex?
    @State private var viewSize: CGSize = .zero

    /// Pre-computed color data for each rect, indexed same as cachedRects.
    @State private var precomputedColors: [CachedRectColor] = []

    /// Minimum area (in px²) to use a gradient instead of a flat color.
    private let gradientThreshold: CGFloat = 400

    /// Gradient intensity from AppState.
    private var gradientIntensity: Double {
        appState.gradientIntensity
    }

    /// The node currently displayed as root (zoom target or scan root).
    private var displayRoot: FileNode {
        zoomRoot ?? appState.displayTree ?? scanResult.scanTree
    }

    init(
        scanResult: ScanResult,
        colorMapping: any ColorMapping,
        hoveredNode: Binding<FileNode?>,
        zoomRoot: Binding<FileNode?>
    ) {
        self.scanResult = scanResult
        self.colorMapping = colorMapping
        self._hoveredNode = hoveredNode
        self._zoomRoot = zoomRoot
    }

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let rects = cachedRects
            let colors = precomputedColors
            let maskedIDs = appState.maskedNodeIDs
            let hoveredID = hoveredNode?.id
            let threshold = gradientThreshold

            for (i, treemapRect) in rects.enumerated() {
                drawRect(treemapRect, index: i, colors: colors,
                         maskedIDs: maskedIDs, hoveredID: hoveredID,
                         gradientThreshold: threshold, in: &context)
            }

            // Labels removed — file names shown in NodeInfoBar on hover
        }
        .background(GeometryReader { geo in
            Color.clear.onChange(of: geo.size, initial: true) { _, newSize in
                viewSize = newSize
                recomputeLayout()
            }
        })
        .onChange(of: displayRoot.id) { recomputeLayout() }
        .onChange(of: colorMapping.name) { recomputeColors() }
        .onChange(of: gradientIntensity) { recomputeColors() }
        .drawingGroup()
        .onContinuousHover { phase in
            switch phase {
            case .active(let point):
                let hit = spatialIndex?.hitTest(point: point)
                if hit?.id != hoveredNode?.id {
                    hoveredNode = hit
                }
            case .ended:
                if hoveredNode != nil {
                    hoveredNode = nil
                }
            }
        }
        .onTapGesture { location in
            guard let node = spatialIndex?.hitTest(point: location) else { return }
            appState.selectedNode = node
            if node.isDirectory {
                withAnimation(.easeInOut(duration: 0.25)) {
                    zoomRoot = node
                }
            }
        }
        .accessibilityLabel(String(localized: "Treemap visualization"))
        .accessibilityValue(hoveredNode.map { "\($0.name), \($0.formattedSize)" } ?? "")
        .accessibilityHint(String(localized: "Click a folder to zoom in. Right-click for actions."))
        .contextMenu {
            if let node = hoveredNode {
                Button(String(localized: "Open")) {
                    appState.openFile(node)
                }
                Button(String(localized: "Reveal in Finder")) {
                    appState.revealInFinder(node)
                }
                Divider()
                Button(String(localized: "Copy Path")) {
                    appState.copyPath(node)
                }
                if node.isDirectory {
                    Divider()
                    Button(String(localized: "Zoom In")) {
                        appState.zoomIn(to: node)
                    }
                }
                if (node.isDirectory && appState.canDeleteFolders) ||
                   (!node.isDirectory && appState.canDeleteFiles) {
                    Divider()
                    Button(String(localized: "Move to Trash"), role: .destructive) {
                        appState.requestDelete(node)
                    }
                }
            }
        }
    }

    // MARK: - Drawing

    private func drawRect(
        _ treemapRect: TreemapRect,
        index: Int,
        colors: [CachedRectColor],
        maskedIDs: Set<UUID>,
        hoveredID: UUID?,
        gradientThreshold: CGFloat,
        in context: inout GraphicsContext
    ) {
        let rect = treemapRect.rect
        guard rect.width >= 0.5, rect.height >= 0.5 else { return }

        let isMasked = maskedIDs.contains(treemapRect.node.id)
        let isHovered = hoveredID == treemapRect.node.id

        // Large rects: inset slightly for visible borders. Small rects: fill edge-to-edge.
        let isLarge = rect.width >= 20 && rect.height >= 20
        let fillRect = isLarge ? rect.insetBy(dx: 0.5, dy: 0.5) : rect
        let fillPath = Path(fillRect)

        if isMasked {
            context.fill(fillPath, with: .color(.gray.opacity(0.3)))
        } else if index < colors.count {
            let cached = colors[index]
            let area = rect.width * rect.height

            if area >= gradientThreshold {
                // Gradient fill for large rects
                let gradient = Gradient(colors: [cached.lightColor, cached.darkColor])
                context.fill(fillPath, with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: fillRect.minX, y: fillRect.minY),
                    endPoint: CGPoint(x: fillRect.maxX, y: fillRect.maxY)
                ))
            } else {
                // Flat fill for small rects — much cheaper
                context.fill(fillPath, with: .color(cached.midColor))
            }
        } else {
            context.fill(fillPath, with: .color(.gray))
        }

        if isHovered {
            context.fill(fillPath, with: .color(.white.opacity(0.25)))
        }

        // Borders only on large rects (small ones are edge-to-edge)
        if isLarge {
            let borderOpacity: Double = isHovered ? 0.6 : 0.2
            context.stroke(fillPath, with: .color(.black.opacity(borderOpacity)),
                           lineWidth: isHovered ? 1.5 : 0.5)
        }
    }

    private func drawLabel(_ treemapRect: TreemapRect, in context: inout GraphicsContext) {
        let rect = treemapRect.rect
        let minLabelWidth: CGFloat = 50
        let minLabelHeight: CGFloat = 16

        guard rect.width >= minLabelWidth, rect.height >= minLabelHeight else { return }

        let node = treemapRect.node
        let name = node.name
        let fontSize: CGFloat = min(max(rect.height * 0.25, 9), 13)

        let text = Text(name)
            .font(.system(size: fontSize, weight: .medium))
            .foregroundStyle(.white)

        var shadowContext = context
        shadowContext.opacity = 0.6
        shadowContext.addFilter(.shadow(color: .black, radius: 1, x: 0, y: 0.5))

        let textPoint = CGPoint(
            x: rect.minX + 4,
            y: rect.minY + 2
        )

        shadowContext.draw(text, at: textPoint, anchor: .topLeading)

        if rect.height >= minLabelHeight * 2.5 {
            let sizeText = Text(node.formattedSize)
                .font(.system(size: max(fontSize - 2, 8)))
                .foregroundStyle(.white.opacity(0.8))
            let sizePoint = CGPoint(x: rect.minX + 4, y: rect.minY + fontSize + 4)
            shadowContext.draw(sizeText, at: sizePoint, anchor: .topLeading)
        }
    }

    // MARK: - Layout & Caching

    private func recomputeLayout() {
        guard viewSize.width > 0, viewSize.height > 0 else { return }
        let bounds = CGRect(origin: .zero, size: viewSize)
        cachedRects = TreemapLayout.layout(root: displayRoot, in: bounds)
        spatialIndex = TreemapSpatialIndex(rects: cachedRects, viewSize: viewSize)
        recomputeColors()
    }

    /// Pre-resolve all color components once to avoid NSColor conversion per rect per frame.
    private func recomputeColors() {
        let intensity = gradientIntensity
        precomputedColors = cachedRects.map { treemapRect in
            let baseColor = colorMapping.color(for: treemapRect.node, depth: treemapRect.depth)
            let base = resolveRGBA(baseColor)
            let light = RGBAComponents(
                r: min(base.r + intensity * 0.3, 1),
                g: min(base.g + intensity * 0.3, 1),
                b: min(base.b + intensity * 0.3, 1)
            )
            let dark = RGBAComponents(
                r: max(base.r - intensity * 0.4, 0),
                g: max(base.g - intensity * 0.4, 0),
                b: max(base.b - intensity * 0.4, 0)
            )
            return CachedRectColor(
                lightColor: Color(red: light.r, green: light.g, blue: light.b),
                darkColor: Color(red: dark.r, green: dark.g, blue: dark.b),
                midColor: Color(red: base.r, green: base.g, blue: base.b)
            )
        }
    }

    /// Resolve a SwiftUI Color to raw RGBA components (done once, not per frame).
    private func resolveRGBA(_ color: Color) -> RGBAComponents {
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? .gray
        return RGBAComponents(
            r: nsColor.redComponent,
            g: nsColor.greenComponent,
            b: nsColor.blueComponent
        )
    }
}

// MARK: - Pre-computed Color Data

/// Raw RGBA components for color caching.
struct RGBAComponents: Sendable {
    let r: Double
    let g: Double
    let b: Double
}

/// Pre-computed SwiftUI Color instances for a single treemap rect.
/// Created once at layout time, reused every frame.
struct CachedRectColor: Sendable {
    let lightColor: Color   // for gradient top-left
    let darkColor: Color    // for gradient bottom-right
    let midColor: Color     // flat fill for small rects
}
