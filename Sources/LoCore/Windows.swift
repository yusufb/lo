import CoreGraphics

/// A window as reported by the CoreGraphics window list.
public struct WindowInfo: Equatable, Sendable {
    public let id: CGWindowID
    public let pid: pid_t
    public let ownerName: String?
    public let layer: Int
    public let alpha: Double
    /// Top-left origin global coordinates.
    public let bounds: CGRect

    public init(id: CGWindowID, pid: pid_t, ownerName: String?, layer: Int, alpha: Double, bounds: CGRect) {
        self.id = id
        self.pid = pid
        self.ownerName = ownerName
        self.layer = layer
        self.alpha = alpha
        self.bounds = bounds
    }
}

/// Windows smaller than this on either side are treated as utility windows, not real ones.
public let minimumWindowSide: CGFloat = 50

/// Filters a front-to-back window list down to windows that could be arranged,
/// keeping the front-to-back (most recently used first) order.
public func selectCandidates(_ windows: [WindowInfo]) -> [WindowInfo] {
    windows.filter { window in
        window.layer == 0
            && window.alpha > 0
            && window.bounds.width >= minimumWindowSide
            && window.bounds.height >= minimumWindowSide
    }
}

public enum SelectionError: Error, Equatable, CustomStringConvertible {
    case notEnoughWindows(needed: Int, found: Int)
    case terminalTooShort(needed: Int, fits: Int)

    public var description: String {
        switch self {
        case .notEnoughWindows(let needed, let found):
            let noun = found == 1 ? "window" : "windows"
            return "need \(needed) windows, but only \(found) arrangeable \(noun) found on the current Space"
        case .terminalTooShort(let needed, let fits):
            return "the terminal is too short to list \(needed) windows (room for \(fits)); make it taller"
        }
    }
}

/// Lines the picker uses besides the window rows: the header, a possible
/// "more not shown" line, and the line the cursor rests on below the list.
public let pickerChromeLines = 3

/// How many of `available` windows the picker can show in a terminal with
/// `terminalRows` rows. Throws if that is fewer than `needed`.
public func visibleWindowCount(available: Int, needed: Int, terminalRows: Int) throws -> Int {
    precondition(needed > 0, "needed must be positive")
    guard available >= needed else {
        throw SelectionError.notEnoughWindows(needed: needed, found: available)
    }
    let fits = max(terminalRows - pickerChromeLines, 0)
    guard fits >= needed else {
        throw SelectionError.terminalTooShort(needed: needed, fits: fits)
    }
    return min(available, fits)
}
