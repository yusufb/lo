import AppKit
import LoCore

private func printError(_ message: String) {
    FileHandle.standardError.write(Data("lo: error: \(message)\n".utf8))
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

    let required: Int
    switch command {
    case .help:
        print(usage)
        return
    case .arrange(let rows):
        required = rows.reduce(0, +)
    case .arrangeRatios(let weights):
        required = weights.count
    }

    try AX.ensureTrusted()

    let terminalID = try invokingWindowID()
    let windows = try onScreenWindows()
    guard let terminalWindow = windows.first(where: { $0.id == terminalID }) else {
        throw LoError("the terminal window running lo is not in the on-screen window list")
    }
    let area = try targetArea(for: terminalWindow.bounds)

    let candidates = arrangeableWindows(selectCandidates(windows))

    let terminal = try Terminal()
    guard let chosen = try pickWindows(
        labels: candidates.map(\.displayName),
        required: required,
        terminal: terminal
    ) else {
        return
    }
    let picked = chosen.map { candidates[$0] }

    let frames: [CGRect]
    switch command {
    case .help:
        return
    case .arrange(let rows):
        frames = gridFrames(rows: rows, in: area)
    case .arrangeRatios(let weights):
        frames = ratioFrames(weights: weights, in: area)
    }

    try arrange(picked, into: frames)
    try raise(picked)
}

do {
    try MainActor.assumeIsolated {
        try run(Array(CommandLine.arguments.dropFirst()))
    }
} catch {
    printError("\(error)")
    exit(1)
}
