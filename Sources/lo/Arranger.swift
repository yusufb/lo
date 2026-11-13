import ApplicationServices
import LoCore

/// Differences up to this many points between the requested and actual frame are ignored.
private let frameTolerance: CGFloat = 1

/// Moves and resizes each window to its frame. Returns warnings for windows
/// that refused the change or ended up with a different frame.
func arrange(_ windows: [ManagedWindow], into frames: [CGRect]) -> [String] {
    precondition(windows.count == frames.count, "every window needs exactly one frame")

    var warnings: [String] = []
    let (restoreEnhancedUI, enhancedUIWarnings) = disableEnhancedUserInterface(for: windows)
    warnings += enhancedUIWarnings

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
            warnings.append("\(window.label) refused to move or resize (Accessibility error \(failed.rawValue))")
        }

        guard let position = AX.position(window.element), let size = AX.size(window.element) else {
            warnings.append("could not read back the frame of \(window.label)")
            continue
        }
        let actual = CGRect(origin: position, size: size)
        if !isClose(actual, frame) {
            warnings.append(
                "\(window.label) is at \(describe(actual)) instead of \(describe(frame)) (the app may restrict its size)"
            )
        }
    }

    for window in restoreEnhancedUI {
        let result = AX.setBool(window.app, enhancedUserInterface, true)
        if result != .success {
            warnings.append(
                "could not restore \(enhancedUserInterface) for \(window.label) (Accessibility error \(result.rawValue))"
            )
        }
    }
    return warnings
}

/// Brings the windows to the front so that `windows[0]` ends up on top and focused,
/// followed by `windows[1]`, and so on. Returns warnings for windows that could not be raised.
func raise(_ windows: [ManagedWindow]) -> [String] {
    var warnings: [String] = []
    // Raise the least recent first, so the most recent ends up on top and the
    // z-order (which lo reads on the next run) matches the layout order.
    for window in windows.reversed() {
        let results = [
            AXUIElementPerformAction(window.element, kAXRaiseAction as CFString),
            AX.setBool(window.element, kAXMainAttribute, true),
            AX.setBool(window.app, kAXFrontmostAttribute, true),
        ]
        if let failed = results.first(where: { $0 != .success }) {
            warnings.append("could not raise \(window.label) (Accessibility error \(failed.rawValue))")
        }
    }
    return warnings
}

/// Some apps (e.g. Chrome, Electron apps) animate every Accessibility frame change
/// while this attribute is on, which makes moving windows slow and unreliable.
/// Rectangle and others switch it off during the move and restore it afterwards.
private let enhancedUserInterface = "AXEnhancedUserInterface"

/// Switches the attribute off for every app that has it on. Returns one window per
/// switched-off app (to restore it later), plus warnings for apps where it failed.
private func disableEnhancedUserInterface(for windows: [ManagedWindow]) -> ([ManagedWindow], [String]) {
    var disabled: [ManagedWindow] = []
    var warnings: [String] = []
    var seen: Set<pid_t> = []
    for window in windows where seen.insert(window.info.pid).inserted {
        let value: CFTypeRef?
        do {
            value = try AX.attribute(window.app, enhancedUserInterface, of: window.label)
        } catch {
            warnings.append("could not check \(enhancedUserInterface) for \(window.label): \(error)")
            continue
        }
        // Optional attribute: most apps do not have it, so anything other than an
        // explicit "true" means there is nothing to switch off.
        guard let value, CFGetTypeID(value) == CFBooleanGetTypeID(), CFBooleanGetValue((value as! CFBoolean))
        else { continue }

        let result = AX.setBool(window.app, enhancedUserInterface, false)
        if result == .success {
            disabled.append(window)
        } else {
            warnings.append(
                "could not switch off \(enhancedUserInterface) for \(window.label) (Accessibility error \(result.rawValue)); moving may be slow"
            )
        }
    }
    return (disabled, warnings)
}

private func isClose(_ a: CGRect, _ b: CGRect) -> Bool {
    abs(a.minX - b.minX) <= frameTolerance
        && abs(a.minY - b.minY) <= frameTolerance
        && abs(a.width - b.width) <= frameTolerance
        && abs(a.height - b.height) <= frameTolerance
}

private func describe(_ rect: CGRect) -> String {
    "(\(Int(rect.minX)), \(Int(rect.minY))) \(Int(rect.width))x\(Int(rect.height))"
}
