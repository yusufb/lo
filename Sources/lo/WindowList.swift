import AppKit
import ApplicationServices
import LoCore

/// Reads the on-screen windows of the current Space, front to back.
func onScreenWindows() throws -> [WindowInfo] {
    guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        as? [[String: Any]]
    else {
        throw LoError("could not read the window list from the window server")
    }

    return try list.map { entry in
        guard let id = entry[kCGWindowNumber as String] as? Int,
              let pid = entry[kCGWindowOwnerPID as String] as? Int,
              let layer = entry[kCGWindowLayer as String] as? Int,
              let alpha = entry[kCGWindowAlpha as String] as? Double,
              let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
        else {
            throw LoError("window server returned a malformed window entry: \(entry)")
        }
        return WindowInfo(
            id: CGWindowID(id),
            pid: pid_t(pid),
            ownerName: entry[kCGWindowOwnerName as String] as? String,
            layer: layer,
            alpha: alpha,
            bounds: bounds
        )
    }
}

/// An arrangeable window: a CoreGraphics window matched to its Accessibility element.
struct ManagedWindow {
    let info: WindowInfo
    let element: AXUIElement
    let app: AXUIElement
    let title: String?

    var appName: String { info.ownerName ?? "pid \(info.pid)" }

    /// Used in warnings.
    var label: String { "'\(appName)' window \(info.id)" }

    /// Used in the picker list.
    var displayName: String {
        guard let title, !title.isEmpty else { return "\(appName) (untitled)" }
        return "\(appName) - \(title)"
    }
}

/// Resolves every candidate to an arrangeable window, keeping their order.
/// Apps that fail to answer Accessibility queries (e.g. hung apps) are skipped,
/// with one warning per app.
func arrangeableWindows(_ candidates: [WindowInfo]) -> (windows: [ManagedWindow], warnings: [String]) {
    let resolver = WindowResolver()
    var windows: [ManagedWindow] = []
    var warnings: [String] = []
    var failedApps: Set<pid_t> = []

    for candidate in candidates where !failedApps.contains(candidate.pid) {
        do {
            if let window = try resolver.resolve(candidate) {
                windows.append(window)
            }
        } catch {
            failedApps.insert(candidate.pid)
            warnings.append("skipping '\(candidate.ownerName ?? "unknown")' (pid \(candidate.pid)): \(error)")
        }
    }
    return (windows, warnings)
}

/// Matches CoreGraphics windows to Accessibility windows, querying each app at most once.
final class WindowResolver {
    private var appWindows: [pid_t: [CGWindowID: AXUIElement]] = [:]

    /// Returns nil if the window is not a standard, arrangeable window
    /// (e.g. a panel, popover, or a window with no Accessibility counterpart).
    func resolve(_ info: WindowInfo) throws -> ManagedWindow? {
        let owner = "'\(info.ownerName ?? "unknown")' (pid \(info.pid))"
        let app = AXUIElementCreateApplication(info.pid)
        let windows = try windowsByID(app: app, pid: info.pid, owner: owner)

        guard let element = windows[info.id] else { return nil }
        let subrole = try AX.string(element, kAXSubroleAttribute, of: "a window of \(owner)")
        guard subrole == kAXStandardWindowSubrole else { return nil }
        let title = try AX.string(element, kAXTitleAttribute, of: "a window of \(owner)")

        return ManagedWindow(info: info, element: element, app: app, title: title)
    }

    private func windowsByID(app: AXUIElement, pid: pid_t, owner: String) throws -> [CGWindowID: AXUIElement] {
        if let cached = appWindows[pid] { return cached }

        var byID: [CGWindowID: AXUIElement] = [:]
        if let value = try AX.attribute(app, kAXWindowsAttribute, of: owner) {
            guard let elements = value as? [AXUIElement] else {
                throw LoError("window list of \(owner) is not a list of Accessibility elements")
            }
            for element in elements {
                // Elements without a window ID are not backed by a real window; they
                // cannot be the window we are looking for.
                if let id = AX.windowID(element) {
                    byID[id] = element
                }
            }
        }
        appWindows[pid] = byID
        return byID
    }
}

/// Returns the window the user is typing in: the focused window of the frontmost app.
///
/// The frontmost app comes from NSWorkspace rather than the system-wide
/// Accessibility element: on some systems the system-wide element fails every
/// query with kAXErrorCannotComplete, while queries to individual apps work.
func invokingWindowID() throws -> CGWindowID {
    guard let front = NSWorkspace.shared.frontmostApplication else {
        throw LoError("could not determine the frontmost app (the terminal running lo)")
    }
    let pid = front.processIdentifier
    let owner = "the frontmost app '\(front.localizedName ?? "unknown")' (pid \(pid))"
    let app = AXUIElementCreateApplication(pid)
    guard let window = try AX.element(app, kAXFocusedWindowAttribute, of: owner) else {
        throw LoError("could not determine the focused window of \(owner)")
    }
    guard let id = AX.windowID(window) else {
        throw LoError("could not determine the window ID of the focused window of \(owner)")
    }
    return id
}
