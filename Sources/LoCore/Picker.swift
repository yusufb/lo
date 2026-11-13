/// A key press relevant to the picker.
public enum Key: Equatable, Sendable {
    case up
    case down
    case enter
    case cancel
    case other
}

/// Decodes a chunk of bytes read from a terminal in raw mode into key presses.
/// A chunk can hold several keys when the user types quickly.
public func decodeKeys(_ bytes: [UInt8]) -> [Key] {
    var keys: [Key] = []
    var index = 0
    while index < bytes.count {
        let byte = bytes[index]
        index += 1
        switch byte {
        case 0x1B: // ESC
            guard index < bytes.count else {
                keys.append(.cancel) // lone ESC
                continue
            }
            let introducer = bytes[index]
            guard introducer == UInt8(ascii: "[") || introducer == UInt8(ascii: "O") else {
                keys.append(.cancel) // ESC followed by an ordinary key
                continue
            }
            index += 1
            // CSI / SS3 sequence: parameter bytes, then one final byte in 0x40...0x7E.
            while index < bytes.count, !(0x40...0x7E).contains(bytes[index]) {
                index += 1
            }
            guard index < bytes.count else {
                keys.append(.other) // truncated sequence
                continue
            }
            let final = bytes[index]
            index += 1
            switch final {
            case UInt8(ascii: "A"): keys.append(.up)
            case UInt8(ascii: "B"): keys.append(.down)
            default: keys.append(.other)
            }
        case 0x0D, 0x0A: // CR, LF
            keys.append(.enter)
        case 0x03: // Ctrl+C
            keys.append(.cancel)
        case UInt8(ascii: "q"):
            keys.append(.cancel)
        case UInt8(ascii: "k"):
            keys.append(.up)
        case UInt8(ascii: "j"):
            keys.append(.down)
        default:
            keys.append(.other)
        }
    }
    return keys
}

/// Selection state of the interactive window list.
public struct Picker: Equatable, Sendable {
    public enum Outcome: Equatable, Sendable {
        case pending
        /// Item indices in the order they were marked.
        case done([Int])
        case cancelled
    }

    public let itemCount: Int
    public let required: Int
    public private(set) var cursor = 0
    /// Marked item indices, in mark order. Mark number = position + 1.
    public private(set) var marks: [Int] = []

    public init(itemCount: Int, required: Int) {
        precondition(required > 0, "at least one window must be required")
        precondition(itemCount >= required, "need at least as many items as required marks")
        self.itemCount = itemCount
        self.required = required
    }

    /// The 1-based mark number of an item, or nil if it is not marked.
    public func markNumber(of item: Int) -> Int? {
        marks.firstIndex(of: item).map { $0 + 1 }
    }

    public mutating func handle(_ key: Key) -> Outcome {
        switch key {
        case .up:
            cursor = (cursor - 1 + itemCount) % itemCount
        case .down:
            cursor = (cursor + 1) % itemCount
        case .enter:
            if let position = marks.firstIndex(of: cursor) {
                // Unmarking renumbers later marks, since numbers are positions.
                marks.remove(at: position)
            } else {
                marks.append(cursor)
                if marks.count == required {
                    return .done(marks)
                }
            }
        case .cancel:
            return .cancelled
        case .other:
            break
        }
        return .pending
    }
}

/// Renders the picker as lines of text (without newlines), each cut to fit `width` columns.
public func renderPicker(_ picker: Picker, labels: [String], hiddenCount: Int, width: Int) -> [String] {
    precondition(labels.count == picker.itemCount, "need exactly one label per item")
    precondition(hiddenCount >= 0, "hidden count must not be negative")
    precondition(width > 0, "width must be positive")

    let numberWidth = String(picker.required).count
    let blankMark = String(repeating: " ", count: numberWidth + 3)

    var lines = [
        "Select windows: \(picker.marks.count)/\(picker.required) marked  (↑/↓ move, Enter mark/unmark, Esc cancel)",
    ]
    for (index, label) in labels.enumerated() {
        let pointer = index == picker.cursor ? "> " : "  "
        let mark = picker.markNumber(of: index).map { number in
            let digits = String(number)
            return "[" + String(repeating: " ", count: numberWidth - digits.count) + digits + "] "
        } ?? blankMark
        lines.append(pointer + mark + label)
    }
    if hiddenCount > 0 {
        let noun = hiddenCount == 1 ? "window" : "windows"
        lines.append("  ... \(hiddenCount) more \(noun) not shown (terminal too short)")
    }
    // Stay one column short of the edge so no line wraps, which would break redrawing.
    let limit = max(width - 1, 1)
    return lines.map { $0.count > limit ? String($0.prefix(limit)) : $0 }
}
