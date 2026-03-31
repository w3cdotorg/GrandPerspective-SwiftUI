import SwiftUI

/// Full-featured treemap renderer with gradient fills, hover, click-to-zoom, and labels.
/// Replaces DirectoryView + TreeDrawer + GradientRectangleDrawer + ItemPathDrawer.
struct TreemapCanvasView: View {
    let scanResult: ScanResult
    let colorMapping: any ColorMapping
    let gradientIntensity: Double

    @Binding var hoveredNode: FileNode?
    @Binding var zoomRoot: FileNode?

    @Environment(AppState.self) private var appState

    @State private var cachedRects: [TreemapRect] = []
    @State private var viewSize: CGSize = .zero

    /// The node currently displayed as root (zoom target or scan root).
    private var displayRoot: FileNode {
        zoomRoot ?? scanResult.scanTree
    }

    init(
        scanResult: ScanResult,
        colorMapping: any ColorMapping,
        gradientIntensity: Double = 0.5,
        hoveredNode: Binding<FileNode?>,
        zoomRoot: Binding<FileNode?>
    ) {
        self.scanResult = scanResult
        self.colorMapping = colorMapping
        self.gradientIntensity = gradientIntensity
        self._hoveredNode = hoveredNode
        self._zoomRoot = zoomRoot
    }

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            let rects = TreemapLayout.layout(root: displayRoot, in: bounds)

            for treemapRect in rects {
                drawRect(treemapRect, in: &context)
            }

            // Draw labels on rects large enough to show text
            for treemapRect in rects {
                drawLabel(treemapRect, in: &context)
            }
        }
        .background(GeometryReader { geo in
            Color.clear.onChange(of: geo.size, initial: true) { _, newSize in
                viewSize = newSize
                recomputeLayout()
            }
        })
        .onChange(of: displayRoot.id) { recomputeLayout() }
        .onChange(of: colorMapping.name) { recomputeLayout() }
        .drawingGroup()
        .onContinuousHover { phase in
            switch phase {
            case .active(let point):
                hoveredNode = hitTest(point: point)
            case .ended:
                hoveredNode = nil
            }
        }
        .onTapGesture { location in
            guard let node = hitTest(point: location) else { return }
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

    private func drawRect(_ treemapRect: TreemapRect, in context: inout GraphicsContext) {
        let rect = treemapRect.rect
        guard rect.width >= 1, rect.height >= 1 else { return }

        let baseColor = colorMapping.color(for: treemapRect.node, depth: treemapRect.depth)
        let inset = rect.insetBy(dx: 0.5, dy: 0.5)
        let path = Path(inset)

        let isHovered = hoveredNode?.id == treemapRect.node.id

        // Gradient fill: lighter at top-left, darker at bottom-right
        let lightColor = brighten(baseColor, by: gradientIntensity * 0.3)
        let darkColor = darken(baseColor, by: gradientIntensity * 0.4)

        let gradient = Gradient(colors: [lightColor, darkColor])
        context.fill(path, with: .linearGradient(
            gradient,
            startPoint: CGPoint(x: inset.minX, y: inset.minY),
            endPoint: CGPoint(x: inset.maxX, y: inset.maxY)
        ))

        // Highlight on hover
        if isHovered {
            context.fill(path, with: .color(.white.opacity(0.25)))
        }

        // Border
        let borderOpacity: Double = isHovered ? 0.6 : 0.2
        context.stroke(path, with: .color(.black.opacity(borderOpacity)), lineWidth: isHovered ? 1.5 : 0.5)
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

        // Draw with a subtle shadow for readability
        var shadowContext = context
        shadowContext.opacity = 0.6
        shadowContext.addFilter(.shadow(color: .black, radius: 1, x: 0, y: 0.5))

        let textPoint = CGPoint(
            x: rect.minX + 4,
            y: rect.minY + 2
        )

        shadowContext.draw(text, at: textPoint, anchor: .topLeading)

        // Size label below name if there's room
        if rect.height >= minLabelHeight * 2.5 {
            let sizeText = Text(node.formattedSize)
                .font(.system(size: max(fontSize - 2, 8)))
                .foregroundStyle(.white.opacity(0.8))
            let sizePoint = CGPoint(x: rect.minX + 4, y: rect.minY + fontSize + 4)
            shadowContext.draw(sizeText, at: sizePoint, anchor: .topLeading)
        }
    }

    // MARK: - Hit testing

    private func hitTest(point: CGPoint) -> FileNode? {
        // Search in reverse order (last drawn = on top)
        for treemapRect in cachedRects.reversed() {
            if treemapRect.rect.contains(point) {
                return treemapRect.node
            }
        }
        return nil
    }

    private func recomputeLayout() {
        guard viewSize.width > 0, viewSize.height > 0 else { return }
        let bounds = CGRect(origin: .zero, size: viewSize)
        cachedRects = TreemapLayout.layout(root: displayRoot, in: bounds)
    }

    // MARK: - Color helpers

    private func brighten(_ color: Color, by amount: Double) -> Color {
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? .gray
        return Color(
            red: min(nsColor.redComponent + amount, 1),
            green: min(nsColor.greenComponent + amount, 1),
            blue: min(nsColor.blueComponent + amount, 1)
        )
    }

    private func darken(_ color: Color, by amount: Double) -> Color {
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? .gray
        return Color(
            red: max(nsColor.redComponent - amount, 0),
            green: max(nsColor.greenComponent - amount, 0),
            blue: max(nsColor.blueComponent - amount, 0)
        )
    }
}
