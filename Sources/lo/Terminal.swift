import Darwin
import Foundation
import LoCore

/// The controlling terminal, opened directly so the picker works even when
/// stdout is redirected.
final class Terminal {
    private let fd: Int32
    private var original = termios()
    private var rawModeEnabled = false

    init() throws {
        fd = open("/dev/tty", O_RDWR)
        guard fd >= 0 else {
            throw LoError("lo needs an interactive terminal (could not open /dev/tty: \(String(cString: strerror(errno))))")
        }
    }

    deinit {
        restore()
        close(fd)
    }

    func size() throws -> (rows: Int, columns: Int) {
        var size = winsize()
        guard ioctl(fd, TIOCGWINSZ, &size) == 0 else {
            throw LoError("could not read the terminal size: \(String(cString: strerror(errno)))")
        }
        guard size.ws_row > 0, size.ws_col > 0 else {
            throw LoError("the terminal reported a size of \(size.ws_col)x\(size.ws_row)")
        }
        return (Int(size.ws_row), Int(size.ws_col))
    }

    /// Reads keys one press at a time without echo. Ctrl+C arrives as a byte
    /// instead of a signal, so the picker can restore the terminal before exiting.
    func enableRawMode() throws {
        guard tcgetattr(fd, &original) == 0 else {
            throw LoError("could not read the terminal settings: \(String(cString: strerror(errno)))")
        }
        var raw = original
        raw.c_lflag &= ~tcflag_t(ICANON | ECHO | ISIG | IEXTEN)
        raw.c_iflag &= ~tcflag_t(IXON | ICRNL)
        // VMIN = 1, VTIME = 0: block until at least one byte arrives.
        withUnsafeMutableBytes(of: &raw.c_cc) { cc in
            cc[Int(VMIN)] = 1
            cc[Int(VTIME)] = 0
        }
        guard tcsetattr(fd, TCSAFLUSH, &raw) == 0 else {
            throw LoError("could not switch the terminal to raw mode: \(String(cString: strerror(errno)))")
        }
        rawModeEnabled = true
    }

    func restore() {
        guard rawModeEnabled else { return }
        rawModeEnabled = false
        if tcsetattr(fd, TCSAFLUSH, &original) != 0 {
            FileHandle.standardError.write(Data(
                "lo: warning: could not restore the terminal settings (run 'reset'): \(String(cString: strerror(errno)))\n".utf8
            ))
        }
    }

    func write(_ text: String) {
        var bytes = Array(text.utf8)
        var offset = 0
        while offset < bytes.count {
            let written = bytes.withUnsafeMutableBytes { buffer in
                Darwin.write(fd, buffer.baseAddress! + offset, buffer.count - offset)
            }
            if written < 0 {
                if errno == EINTR { continue }
                return // terminal gone; nothing useful left to draw on
            }
            offset += written
        }
    }

    func read() throws -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: 64)
        while true {
            let count = Darwin.read(fd, &buffer, buffer.count)
            if count > 0 { return Array(buffer[0..<count]) }
            if count == 0 { throw LoError("the terminal closed") }
            if errno != EINTR {
                throw LoError("could not read from the terminal: \(String(cString: strerror(errno)))")
            }
        }
    }
}

private let hideCursor = "\u{1B}[?25l"
private let showCursor = "\u{1B}[?25h"
private let clearToEnd = "\r\u{1B}[J"

/// Shows the window list and lets the user mark `required` windows.
/// Returns the chosen indices into `labels` in mark order, or nil if cancelled.
/// The list is removed from the terminal before returning.
func pickWindows(labels: [String], required: Int, terminal: Terminal) throws -> [Int]? {
    let size = try terminal.size()
    let visible = try visibleWindowCount(available: labels.count, needed: required, terminalRows: size.rows)
    let shown = Array(labels.prefix(visible))
    var picker = Picker(itemCount: shown.count, required: required)

    try terminal.enableRawMode()
    terminal.write(hideCursor)
    var drawnLines = 0
    defer {
        if drawnLines > 0 { terminal.write("\u{1B}[\(drawnLines)A") }
        terminal.write(clearToEnd + showCursor)
        terminal.restore()
    }

    func draw() {
        let lines = renderPicker(picker, labels: shown, hiddenCount: labels.count - shown.count, width: size.columns)
        if drawnLines > 0 { terminal.write("\u{1B}[\(drawnLines)A") }
        terminal.write(clearToEnd + lines.joined(separator: "\r\n") + "\r\n")
        drawnLines = lines.count
    }

    draw()
    while true {
        for key in decodeKeys(try terminal.read()) {
            switch picker.handle(key) {
            case .pending:
                continue
            case .done(let indices):
                return indices
            case .cancelled:
                return nil
            }
        }
        draw()
    }
}
