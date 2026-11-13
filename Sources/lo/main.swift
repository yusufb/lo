import AppKit
import LoCore

private func printError(_ message: String) {
    FileHandle.standardError.write(Data("lo: error: \(message)\n".utf8))
}

private func printWarning(_ message: String) {
    FileHandle.standardError.write(Data("lo: warning: \(message)\n".utf8))
}

/// Visible frame (excluding the menu bar and Dock) of the screen showing `window`,
/// in top-left origin coordinates.
@MainActor
private func targetArea(for window: CGRect) throws -> CGRect {
    let screens = NSScreen.screens
    guard let primary = screens.first else {
        throw LoError("no screens found")
    }
    let primaryHeight = primary.frame.height
    let frames = screens.map { cocoaToTopLeft($0.frame, primaryScreenHeight: primaryHeight) }
    guard let index = screenIndex(containing: window, screens: frames) else {
        throw LoError("the terminal window is not on any screen")
    }
    return cocoaToTopLeft(screens[index].visibleFrame, primaryScreenHeight: primaryHeight)
}

@MainActor
private func run(_ args: [String]) throws {
    let command: Command
    do {
        command = try parseArguments(args)
    } catch let error as ArgumentError {
        throw LoError("\(error)\n\n\(usage)")
    }

    guard case .arrange(let rows) = command else {
        print(usage)
        return
    }

    try AX.ensureTrusted()

    let terminalID = try invokingWindowID()
    let windows = try onScreenWindows()
    guard let terminalWindow = windows.first(where: { $0.id == terminalID }) else {
        throw LoError("the terminal window running lo is not in the on-screen window list")
    }
    let area = try targetArea(for: terminalWindow.bounds)

    let (candidates, resolveWarnings) = arrangeableWindows(selectCandidates(windows))
    resolveWarnings.forEach(printWarning)

    let terminal = try Terminal()
    guard let chosen = try pickWindows(
        labels: candidates.map(\.displayName),
        required: rows.reduce(0, +),
        terminal: terminal
    ) else {
        throw LoError("cancelled")
    }
    let picked = chosen.map { candidates[$0] }

    let warnings = arrange(picked, into: gridFrames(rows: rows, in: area)) + raise(picked)
    warnings.forEach(printWarning)
}

do {
    try MainActor.assumeIsolated {
        try run(Array(CommandLine.arguments.dropFirst()))
    }
} catch {
    printError("\(error)")
    exit(1)
}
