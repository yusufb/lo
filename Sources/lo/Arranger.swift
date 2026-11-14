import ApplicationServices
import LoCore

/// Moves and resizes each window to its frame.
func arrange(_ windows: [ManagedWindow], into frames: [CGRect]) throws {
    precondition(windows.count == frames.count, "every window needs exactly one frame")

    let restoreEnhancedUI = try disableEnhancedUserInterface(for: windows)
    defer {
        for window in restoreEnhancedUI {
            _ = AX.setBool(window.app, enhancedUserInterface, true)
        }
    }

    for (window, frame) in zip(windows, frames) {
        // Position, size, position: moving first lets a window cross to a display
        // with room for the new size; moving again fixes the origin if the app
        // shifted the window while resizing.
        let results = [
            AX.setPosition(window.element, frame.origin),
            AX.setSize(window.element, frame.size),
            AX.setPosition(window.element, frame.origin),
        ]
        if let failed = results.first(where: { $0 != .success }) {
            throw AX.failure(failed, "moving or resizing \(window.label)")
        }
    }
}

/// Brings the windows to the front so that `windows[0]` ends up on top and focused,
/// followed by `windows[1]`, and so on.
func raise(_ windows: [ManagedWindow]) throws {
    // Raise the least recent first, so the most recent ends up on top and the
    // z-order (which lo reads on the next run) matches the layout order.
    for window in windows.reversed() {
        let results = [
            AXUIElementPerformAction(window.element, kAXRaiseAction as CFString),
            AX.setBool(window.element, kAXMainAttribute, true),
            AX.setBool(window.app, kAXFrontmostAttribute, true),
        ]
        if let failed = results.first(where: { $0 != .success }) {
            throw AX.failure(failed, "raising \(window.label)")
        }
    }
}

/// Some apps (e.g. Chrome, Electron apps) animate every Accessibility frame change
/// while this attribute is on, which makes moving windows slow and unreliable.
/// Rectangle and others switch it off during the move and restore it afterwards.
private let enhancedUserInterface = "AXEnhancedUserInterface"

/// Switches the attribute off for every app that has it on, and returns one window
/// per switched-off app so it can be restored afterwards.
private func disableEnhancedUserInterface(for windows: [ManagedWindow]) throws -> [ManagedWindow] {
    var disabled: [ManagedWindow] = []
    var seen: Set<pid_t> = []
    for window in windows where seen.insert(window.info.pid).inserted {
        // Optional attribute: most apps do not have it, so anything other than an
        // explicit "true" means there is nothing to switch off.
        guard let value = try AX.attribute(window.app, enhancedUserInterface, of: window.label),
              CFGetTypeID(value) == CFBooleanGetTypeID(),
              CFBooleanGetValue((value as! CFBoolean))
        else { continue }

        if AX.setBool(window.app, enhancedUserInterface, false) == .success {
            disabled.append(window)
        }
    }
    return disabled
}
