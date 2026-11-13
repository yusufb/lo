import CoreGraphics

/// Converts a rectangle from Cocoa coordinates (origin at the bottom-left of the
/// primary screen, y pointing up) to global top-left coordinates (origin at the
/// top-left of the primary screen, y pointing down), as used by CoreGraphics
/// window bounds and the Accessibility API.
public func cocoaToTopLeft(_ rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
    CGRect(
        x: rect.minX,
        y: primaryScreenHeight - rect.maxY,
        width: rect.width,
        height: rect.height
    )
}

/// Returns the index of the screen that overlaps `window` the most, or nil if
/// the window does not overlap any screen. All rectangles must use the same
/// coordinate system.
public func screenIndex(containing window: CGRect, screens: [CGRect]) -> Int? {
    var best: (index: Int, area: CGFloat)?
    for (index, screen) in screens.enumerated() {
        let overlap = screen.intersection(window)
        guard !overlap.isNull else { continue }
        let area = overlap.width * overlap.height
        guard area > 0 else { continue }
        if best == nil || area > best!.area {
            best = (index, area)
        }
    }
    return best?.index
}
