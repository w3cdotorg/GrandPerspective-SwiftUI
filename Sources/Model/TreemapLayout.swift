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
enum TreemapLayout {

    /// Computes layout rects for all leaf nodes visible at `maxDepth`.
    static func layout(
        root: FileNode,
        in bounds: CGRect,
        maxDepth: Int = .max
    ) -> [TreemapRect] {
        guard root.size > 0, bounds.width > 0, bounds.height > 0 else { return [] }
        var result: [TreemapRect] = []
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
        guard rect.width >= 1, rect.height >= 1 else { return }

        switch node.kind {
        case .file, .synthetic:
            result.append(TreemapRect(node: node, rect: rect, depth: depth))

        case .directory:
            if depth >= maxDepth || node.children.isEmpty {
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
