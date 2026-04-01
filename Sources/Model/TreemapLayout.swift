import Foundation

/// A positioned rectangle in the treemap, linked to its FileNode.
struct TreemapRect: Identifiable {
    let id: UUID
    let node: FileNode
    let rect: CGRect
    let depth: Int

    init(node: FileNode, rect: CGRect, depth: Int) {
        self.id = node.id
        self.node = node
        self.rect = rect
        self.depth = depth
    }
}

/// Computes a treemap layout for a FileNode tree.
/// Replaces TreeLayoutBuilder + TreeBalancer from the Obj-C codebase.
///
/// Uses a squarified treemap algorithm: children are laid out in the
/// direction (horizontal or vertical) that produces the best aspect ratios.
///
/// Performance: sub-pixel rects are collapsed to their parent directory,
/// ensuring no white gaps while keeping total rect count manageable.
enum TreemapLayout {

    /// Minimum pixel dimension for recursing into a directory's children.
    /// Directories whose rect is smaller than this on either axis are rendered
    /// as a solid leaf rect (colored as the directory itself). This prevents
    /// generating thousands of sub-pixel rects in dense areas.
    private static let minSideForRecursion: CGFloat = 6

    /// Computes layout rects for all leaf nodes visible at `maxDepth`.
    static func layout(
        root: FileNode,
        in bounds: CGRect,
        maxDepth: Int = .max
    ) -> [TreemapRect] {
        guard root.size > 0, bounds.width > 0, bounds.height > 0 else { return [] }
        var result: [TreemapRect] = []
        result.reserveCapacity(min(Int(root.fileCount), 100_000))
        layoutNode(root, in: bounds, depth: 0, maxDepth: maxDepth, result: &result)
        return result
    }

    // MARK: - Private

    private static func layoutNode(
        _ node: FileNode,
        in rect: CGRect,
        depth: Int,
        maxDepth: Int,
        result: inout [TreemapRect]
    ) {
        guard rect.width >= 0.5, rect.height >= 0.5 else { return }

        switch node.kind {
        case .file, .synthetic:
            result.append(TreemapRect(node: node, rect: rect, depth: depth))

        case .directory:
            // If the rect is too small to usefully show children, or we've hit
            // max depth, render the directory itself as a solid leaf rect.
            if depth >= maxDepth || node.children.isEmpty
                || rect.width < minSideForRecursion
                || rect.height < minSideForRecursion {
                result.append(TreemapRect(node: node, rect: rect, depth: depth))
                return
            }

            let children = node.children
                .filter { $0.size > 0 }
                .sorted { $0.size > $1.size }

            guard !children.isEmpty else {
                result.append(TreemapRect(node: node, rect: rect, depth: depth))
                return
            }

            // IMPORTANT: Emit the directory rect FIRST as a background fill.
            // Children draw on top. This ensures any sub-pixel gaps between
            // children are filled by the parent's color instead of white.
            result.append(TreemapRect(node: node, rect: rect, depth: depth))

            let rects = squarify(children: children, in: rect)
            for (child, childRect) in zip(children, rects) {
                layoutNode(child, in: childRect, depth: depth + 1, maxDepth: maxDepth, result: &result)
            }
        }
    }

    /// Squarified treemap: lays out children as rectangles with aspect ratios
    /// as close to 1:1 as possible.
    private static func squarify(children: [FileNode], in bounds: CGRect) -> [CGRect] {
        let totalSize = Double(children.reduce(0 as UInt64) { $0 + $1.size })
        guard totalSize > 0 else { return Array(repeating: .zero, count: children.count) }

        // Normalized areas proportional to the bounding rect
        let totalArea = Double(bounds.width * bounds.height)
        let areas = children.map { Double($0.size) / totalSize * totalArea }

        var rects = Array(repeating: CGRect.zero, count: children.count)
        var remaining = bounds
        var i = 0

        while i < areas.count {
            let isWide = remaining.width >= remaining.height
            let side = isWide ? Double(remaining.height) : Double(remaining.width)

            // Find the best row: keep adding items while aspect ratio improves
            var row: [Int] = [i]
            var rowArea = areas[i]
            var rowAreas: [Double] = [areas[i]]
            var bestWorst = worstAspectRatio(row: rowAreas, side: side)

            var j = i + 1
            while j < areas.count {
                rowAreas.append(areas[j])
                let candidateWorst = worstAspectRatio(
                    row: rowAreas,
                    side: side
                )
                if candidateWorst > bestWorst {
                    rowAreas.removeLast()
                    break // Adding this item worsens the layout
                }
                row.append(j)
                rowArea += areas[j]
                bestWorst = candidateWorst
                j += 1
            }

            // Lay out the row
            let rowLength = rowArea / side
            var offset: Double = 0

            for idx in row {
                let itemLength = areas[idx] / rowLength

                if isWide {
                    rects[idx] = CGRect(
                        x: Double(remaining.minX),
                        y: Double(remaining.minY) + offset,
                        width: rowLength,
                        height: itemLength
                    )
                } else {
                    rects[idx] = CGRect(
                        x: Double(remaining.minX) + offset,
                        y: Double(remaining.minY),
                        width: itemLength,
                        height: rowLength
                    )
                }
                offset += itemLength
            }

            // Shrink remaining area
            if isWide {
                remaining = CGRect(
                    x: remaining.minX + CGFloat(rowLength),
                    y: remaining.minY,
                    width: remaining.width - CGFloat(rowLength),
                    height: remaining.height
                )
            } else {
                remaining = CGRect(
                    x: remaining.minX,
                    y: remaining.minY + CGFloat(rowLength),
                    width: remaining.width,
                    height: remaining.height - CGFloat(rowLength)
                )
            }

            i = j
        }

        return rects
    }

    /// Worst aspect ratio in a row (higher = worse).
    private static func worstAspectRatio(row: [Double], side: Double) -> Double {
        let rowSum = row.reduce(0, +)
        guard rowSum > 0, side > 0 else { return .infinity }

        let rowLength = rowSum / side
        guard rowLength > 0 else { return .infinity }

        var worst: Double = 0
        for area in row {
            let itemSide = area / rowLength
            let ratio = itemSide > 0 ? max(rowLength / itemSide, itemSide / rowLength) : .infinity
            worst = max(worst, ratio)
        }
        return worst
    }
}

// MARK: - Spatial Index for Hit Testing

/// Grid-based spatial index for fast point-in-rect queries on the treemap.
/// Divides the viewport into cells and maps each rect to the cells it overlaps.
/// Hit testing becomes O(cells touched) instead of O(n).
struct TreemapSpatialIndex: Sendable {
    private let cellSize: CGFloat
    private let columns: Int
    private let rows: Int
    private let grid: [[Int]]  // cell → [index into rects array]
    let rects: [TreemapRect]

    init(rects: [TreemapRect], viewSize: CGSize) {
        self.rects = rects

        // Target ~50x50 grid for typical window sizes
        let targetCells: CGFloat = 50
        self.cellSize = max(max(viewSize.width, viewSize.height) / targetCells, 1)
        self.columns = max(Int(ceil(viewSize.width / self.cellSize)), 1)
        self.rows = max(Int(ceil(viewSize.height / self.cellSize)), 1)

        // Build grid
        var grid = [[Int]](repeating: [], count: columns * rows)
        for (index, treemapRect) in rects.enumerated() {
            let r = treemapRect.rect
            let minCol = max(Int(r.minX / self.cellSize), 0)
            let maxCol = min(Int(r.maxX / self.cellSize), columns - 1)
            let minRow = max(Int(r.minY / self.cellSize), 0)
            let maxRow = min(Int(r.maxY / self.cellSize), rows - 1)

            for row in minRow...maxRow {
                for col in minCol...maxCol {
                    grid[row * columns + col].append(index)
                }
            }
        }
        self.grid = grid
    }

    /// Find the topmost (last-drawn) rect containing the given point.
    func hitTest(point: CGPoint) -> FileNode? {
        let col = Int(point.x / cellSize)
        let row = Int(point.y / cellSize)
        guard col >= 0, col < columns, row >= 0, row < rows else { return nil }

        let candidates = grid[row * columns + col]
        // Search in reverse (last drawn = on top)
        for index in candidates.reversed() {
            if rects[index].rect.contains(point) {
                return rects[index].node
            }
        }
        return nil
    }
}
