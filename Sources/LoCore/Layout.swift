import CoreGraphics

/// Splits `area` into rows of equal height, each row split into cells of equal width.
/// Cells are returned row by row, left to right. Edges are rounded to whole points
/// so neighbouring cells share an edge exactly, with no gaps or overlaps.
///
/// `area` uses top-left origin coordinates (the same as CoreGraphics window bounds
/// and the Accessibility API).
public func gridFrames(rows: [Int], in area: CGRect) -> [CGRect] {
    precondition(!rows.isEmpty, "rows must not be empty")
    precondition(rows.allSatisfy { $0 > 0 }, "every row must contain at least one window")
    precondition(area.width > 0 && area.height > 0, "area must have a positive size")

    var frames: [CGRect] = []
    frames.reserveCapacity(rows.reduce(0, +))

    for (rowIndex, columns) in rows.enumerated() {
        let top = edge(area.minY, area.height, rowIndex, rows.count)
        let bottom = edge(area.minY, area.height, rowIndex + 1, rows.count)
        for column in 0..<columns {
            let left = edge(area.minX, area.width, column, columns)
            let right = edge(area.minX, area.width, column + 1, columns)
            frames.append(CGRect(x: left, y: top, width: right - left, height: bottom - top))
        }
    }
    return frames
}

private func edge(_ origin: CGFloat, _ length: CGFloat, _ index: Int, _ count: Int) -> CGFloat {
    (origin + length * CGFloat(index) / CGFloat(count)).rounded()
}
