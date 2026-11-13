public enum Command: Equatable, Sendable {
    case help
    /// Each element is one row; its value is the number of windows in that row.
    case arrange(rows: [Int])
}

public enum ArgumentError: Error, Equatable, CustomStringConvertible {
    case invalidRow(String)

    public var description: String {
        switch self {
        case .invalidRow(let value):
            return "invalid row '\(value)': expected a positive integer"
        }
    }
}

/// Rows used when lo is run without arguments: two windows side by side.
public let defaultRows = [2]

public let usage = """
    usage: lo [<n> ...]

    Lists the windows on the current screen, most recently used first, and lets
    you pick which ones to arrange into rows.
    Each argument is a row; its value is the number of windows in that row.

    In the list: Up/Down (or k/j) moves, Enter marks or unmarks a window,
    Esc (or q, Ctrl+C) cancels. Mark [1] goes in the first cell, [2] in the
    second, and so on, row by row. The windows are arranged as soon as the
    last one is marked.

    examples:
      lo        same as lo 2
      lo 2      two windows side by side
      lo 3      three windows side by side
      lo 2 2    2x2 grid
      lo 1 1    two windows stacked
      lo 1 2    one full-width window on top, two below
    """

/// Parses command line arguments (excluding the program name).
public func parseArguments(_ args: [String]) throws -> Command {
    if args.isEmpty {
        return .arrange(rows: defaultRows)
    }
    if args.count == 1, args[0] == "-h" || args[0] == "--help" {
        return .help
    }

    let rows = try args.map { arg -> Int in
        // Digits only: rejects signs, whitespace, decimals and empty strings.
        guard !arg.isEmpty, arg.allSatisfy({ $0.isASCII && $0.isNumber }),
              let value = Int(arg), value > 0
        else {
            throw ArgumentError.invalidRow(arg)
        }
        return value
    }
    return .arrange(rows: rows)
}
