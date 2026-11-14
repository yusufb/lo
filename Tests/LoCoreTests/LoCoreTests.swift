import CoreGraphics
import LoCore
import Testing

@Suite struct ArgumentsTests {
    @Test(arguments: [
        (["2"], [2]),
        (["3"], [3]),
        (["2", "2"], [2, 2]),
        (["1", "1"], [1, 1]),
        (["1", "2", "3"], [1, 2, 3]),
    ])
    func parsesRows(args: [String], rows: [Int]) throws {
        #expect(try parseArguments(args) == .arrange(rows: rows))
    }

    @Test(arguments: [
        (["2/3"], [2, 3]),
        (["1/1/1"], [1, 1, 1]),
        (["2/2/2"], [2, 2, 2]),
        (["100/100/100"], [100, 100, 100]),
        (["1/1/3"], [1, 1, 3]),
    ])
    func parsesRatios(args: [String], weights: [Int]) throws {
        #expect(try parseArguments(args) == .arrangeRatios(weights))
    }

    @Test(arguments: [["-h"], ["--help"]])
    func parsesHelp(args: [String]) throws {
        #expect(try parseArguments(args) == .help)
    }

    @Test func defaultsToTwoSideBySideWithoutArguments() throws {
        #expect(try parseArguments([]) == .arrange(rows: [2]))
    }

    @Test(arguments: ["0", "-1", "+2", "1.5", "abc", "", " 2", "2 ", "٣", "99999999999999999999999"])
    func rejectsInvalidRow(value: String) {
        #expect(throws: ArgumentError.invalidRow(value)) { try parseArguments(["2", value]) }
    }

    @Test func rejectsRowSumOverflow() {
        #expect(throws: ArgumentError.invalidRow("1")) { try parseArguments(["\(Int.max)", "1"]) }
    }

    @Test func rejectsHelpMixedWithRows() {
        #expect(throws: ArgumentError.invalidRow("-h")) { try parseArguments(["2", "-h"]) }
    }

    @Test(arguments: [
        "/",
        "2/",
        "/2",
        "/2/3",
        "2/3/",
        "2//3",
        "///",
        "0/2",
        "2/0",
        "0/0",
        "-1/2",
        "2/-3",
        "+1/2",
        "1.5/2",
        "a/b",
        "2/abc",
        " 2/3",
        "2/3 ",
        "2 / 3",
        "٢/٣",
        "99999999999999999999999/1",
        "\(Int.max)/1",
    ])
    func rejectsInvalidRatio(value: String) {
        #expect(throws: ArgumentError.invalidRatio(value)) { try parseArguments([value]) }
    }

    @Test(arguments: [
        (["1", "2/3"], "2/3"),
        (["2/3", "1"], "2/3"),
        (["2/3", "1/2"], "2/3"),
        (["2/3", "-h"], "2/3"),
    ])
    func rejectsRatiosWithMultipleArguments(args: [String], offending: String) {
        #expect(throws: ArgumentError.invalidRatio(offending)) { try parseArguments(args) }
    }
}

@Suite struct LayoutTests {
    let area = CGRect(x: 0, y: 25, width: 1200, height: 800)

    @Test func singleRowSplitsHorizontally() {
        #expect(gridFrames(rows: [2], in: area) == [
            CGRect(x: 0, y: 25, width: 600, height: 800),
            CGRect(x: 600, y: 25, width: 600, height: 800),
        ])
    }

    @Test func singleWindowFillsArea() {
        #expect(gridFrames(rows: [1], in: area) == [area])
    }

    @Test func twoByTwoFillsRowByRowLeftToRight() {
        #expect(gridFrames(rows: [2, 2], in: area) == [
            CGRect(x: 0, y: 25, width: 600, height: 400),
            CGRect(x: 600, y: 25, width: 600, height: 400),
            CGRect(x: 0, y: 425, width: 600, height: 400),
            CGRect(x: 600, y: 425, width: 600, height: 400),
        ])
    }

    @Test func oneByOneStacksVertically() {
        #expect(gridFrames(rows: [1, 1], in: area) == [
            CGRect(x: 0, y: 25, width: 1200, height: 400),
            CGRect(x: 0, y: 425, width: 1200, height: 400),
        ])
    }

    @Test func rowsCanHaveDifferentWindowCounts() {
        #expect(gridFrames(rows: [1, 3], in: area) == [
            CGRect(x: 0, y: 25, width: 1200, height: 400),
            CGRect(x: 0, y: 425, width: 400, height: 400),
            CGRect(x: 400, y: 425, width: 400, height: 400),
            CGRect(x: 800, y: 425, width: 400, height: 400),
        ])
    }

    @Test func unevenSplitsTileWithoutGapsOrOverlaps() {
        let odd = CGRect(x: -1000, y: 13, width: 1001, height: 701)
        let frames = gridFrames(rows: [3, 3, 3], in: odd)

        for row in 0..<3 {
            let cells = Array(frames[(row * 3)..<(row * 3 + 3)])
            #expect(cells.first!.minX == odd.minX)
            #expect(cells.last!.maxX == odd.maxX)
            for (left, right) in zip(cells, cells.dropFirst()) {
                #expect(left.maxX == right.minX)
            }
        }
        #expect(frames.first!.minY == odd.minY)
        #expect(frames.last!.maxY == odd.maxY)
        #expect(frames[0].maxY == frames[3].minY)
        #expect(frames[3].maxY == frames[6].minY)
        #expect(frames.allSatisfy { $0.minX.rounded() == $0.minX && $0.width.rounded() == $0.width })
    }

    @Test func splitsHorizontallyByRatio() {
        #expect(ratioFrames(weights: [2, 3], in: area) == [
            CGRect(x: 0, y: 25, width: 480, height: 800),
            CGRect(x: 480, y: 25, width: 720, height: 800),
        ])
        #expect(ratioFrames(weights: [1, 1, 3], in: area) == [
            CGRect(x: 0, y: 25, width: 240, height: 800),
            CGRect(x: 240, y: 25, width: 240, height: 800),
            CGRect(x: 480, y: 25, width: 720, height: 800),
        ])
    }

    @Test func equalRatiosMatchSingleRowGridRegardlessOfScale() {
        for rect in [area, CGRect(x: -1000, y: 13, width: 1001, height: 701)] {
            let expected = gridFrames(rows: [3], in: rect)
            #expect(ratioFrames(weights: [1, 1, 1], in: rect) == expected)
            #expect(ratioFrames(weights: [2, 2, 2], in: rect) == expected)
            #expect(ratioFrames(weights: [100, 100, 100], in: rect) == expected)
        }
    }

    @Test func unevenRatioSplitsTileWithoutGapsOrOverlaps() {
        let odd = CGRect(x: -1000, y: 13, width: 1001, height: 701)
        let frames = ratioFrames(weights: [2, 3, 7], in: odd)

        #expect(frames.count == 3)
        #expect(frames.first!.minX == odd.minX)
        #expect(frames.last!.maxX == odd.maxX)
        for (left, right) in zip(frames, frames.dropFirst()) {
            #expect(left.maxX == right.minX)
        }
        #expect(frames.allSatisfy {
            $0.minY == odd.minY && $0.maxY == odd.maxY
                && $0.minX.rounded() == $0.minX && $0.width.rounded() == $0.width
        })
    }
}

@Suite struct ScreensTests {
    @Test func convertsPrimaryScreenVisibleFrame() {
        // 1512x982 primary screen, 25pt menu bar at the top, Dock 60pt at the bottom.
        let visible = CGRect(x: 0, y: 60, width: 1512, height: 897)
        #expect(cocoaToTopLeft(visible, primaryScreenHeight: 982) == CGRect(x: 0, y: 25, width: 1512, height: 897))
    }

    @Test func convertsSecondaryScreenAbovePrimary() {
        let secondary = CGRect(x: -200, y: 982, width: 1920, height: 1080)
        #expect(cocoaToTopLeft(secondary, primaryScreenHeight: 982) == CGRect(x: -200, y: -1080, width: 1920, height: 1080))
    }

    @Test func picksScreenWithLargestOverlap() {
        let screens = [
            CGRect(x: 0, y: 0, width: 1000, height: 800),
            CGRect(x: 1000, y: 0, width: 1000, height: 800),
        ]
        let mostlyOnSecond = CGRect(x: 900, y: 100, width: 400, height: 300)
        #expect(screenIndex(containing: mostlyOnSecond, screens: screens) == 1)
        let mostlyOnFirst = CGRect(x: 700, y: 100, width: 400, height: 300)
        #expect(screenIndex(containing: mostlyOnFirst, screens: screens) == 0)
    }

    @Test func returnsNilWhenWindowIsOffScreen() {
        let screens = [CGRect(x: 0, y: 0, width: 1000, height: 800)]
        #expect(screenIndex(containing: CGRect(x: 2000, y: 0, width: 100, height: 100), screens: screens) == nil)
        // Touching an edge is not an overlap.
        #expect(screenIndex(containing: CGRect(x: 1000, y: 0, width: 100, height: 100), screens: screens) == nil)
    }
}

@Suite struct WindowsTests {
    private func window(
        _ id: CGWindowID, pid: pid_t = 100, layer: Int = 0, alpha: Double = 1,
        size: CGSize = CGSize(width: 800, height: 600)
    ) -> WindowInfo {
        WindowInfo(id: id, pid: pid, ownerName: "App", layer: layer, alpha: alpha, bounds: CGRect(origin: .zero, size: size))
    }

    @Test func keepsFrontToBackOrder() {
        let windows = [window(3), window(1), window(4), window(2)]
        #expect(selectCandidates(windows).map(\.id) == [3, 1, 4, 2])
    }

    @Test func skipsNonNormalLayersInvisibleAndTinyWindows() {
        let windows = [
            window(1, layer: 25),
            window(2, alpha: 0),
            window(3, size: CGSize(width: 49, height: 600)),
            window(4, size: CGSize(width: 800, height: 49)),
            window(5, size: CGSize(width: 50, height: 50)),
            window(6),
        ]
        #expect(selectCandidates(windows).map(\.id) == [5, 6])
    }

    @Test func limitsVisibleCountToTerminalHeight() throws {
        #expect(try visibleWindowCount(available: 10, needed: 2, terminalRows: 8) == 5)
        #expect(try visibleWindowCount(available: 3, needed: 2, terminalRows: 20) == 3)
    }

    @Test func failsWhenNotEnoughWindowsAvailable() {
        #expect(throws: SelectionError.notEnoughWindows(needed: 3, found: 2)) {
            try visibleWindowCount(available: 2, needed: 3, terminalRows: 20)
        }
    }

    @Test func failsWhenTerminalIsTooShort() {
        #expect(throws: SelectionError.terminalTooShort(needed: 4, fits: 2)) {
            try visibleWindowCount(available: 6, needed: 4, terminalRows: 5)
        }
    }
}

@Suite struct PickerTests {
    @Test func decodesArrowVimEnterAndCancelKeys() {
        let bytes: [UInt8] = [
            0x1B, UInt8(ascii: "["), UInt8(ascii: "A"), // Up
            0x1B, UInt8(ascii: "["), UInt8(ascii: "B"), // Down
            0x1B, UInt8(ascii: "O"), UInt8(ascii: "A"), // SS3 Up
            UInt8(ascii: "k"),
            UInt8(ascii: "j"),
            0x0D, // Enter (CR)
            0x0A, // Enter (LF)
            UInt8(ascii: "q"),
            0x03, // Ctrl+C
            UInt8(ascii: "x"),
        ]
        #expect(decodeKeys(bytes) == [.up, .down, .up, .up, .down, .enter, .enter, .cancel, .cancel, .other])
    }

    @Test func decodesLoneEscapeAsCancel() {
        #expect(decodeKeys([0x1B]) == [.cancel])
    }

    @Test func cursorWrapsAroundTopAndBottom() {
        var picker = Picker(itemCount: 3, required: 2)
        #expect(picker.cursor == 0)
        #expect(picker.handle(.up) == .pending)
        #expect(picker.cursor == 2)
        #expect(picker.handle(.down) == .pending)
        #expect(picker.cursor == 0)
        #expect(picker.handle(.down) == .pending)
        #expect(picker.cursor == 1)
    }

    @Test func marksAndUnmarksWithRenumberingThenCompletes() {
        var picker = Picker(itemCount: 4, required: 3)
        // Mark item 0 -> [1]
        #expect(picker.handle(.enter) == .pending)
        // Move to item 2 and mark -> [2]
        _ = picker.handle(.down)
        _ = picker.handle(.down)
        #expect(picker.handle(.enter) == .pending)
        #expect(picker.markNumber(of: 0) == 1)
        #expect(picker.markNumber(of: 2) == 2)

        // Move back to item 0 and unmark -> item 2 becomes [1]
        _ = picker.handle(.up)
        _ = picker.handle(.up)
        #expect(picker.handle(.enter) == .pending)
        #expect(picker.markNumber(of: 0) == nil)
        #expect(picker.markNumber(of: 2) == 1)

        // Mark item 1 -> [2], then item 3 -> [3] and finish
        _ = picker.handle(.down)
        #expect(picker.handle(.enter) == .pending)
        _ = picker.handle(.down)
        _ = picker.handle(.down)
        #expect(picker.handle(.enter) == .done([2, 1, 3]))
    }

    @Test func cancelReturnsCancelled() {
        var picker = Picker(itemCount: 2, required: 2)
        #expect(picker.handle(.cancel) == .cancelled)
    }

    @Test func rendersCursorMarksHiddenNoticeAndTruncatesToWidth() {
        var picker = Picker(itemCount: 3, required: 2)
        _ = picker.handle(.down)
        _ = picker.handle(.enter) // item 1 marked [1]
        _ = picker.handle(.down)  // cursor at item 2

        let lines = renderPicker(picker, labels: ["First", "Second", "Third with a very long title"], hiddenCount: 2, width: 25)
        #expect(lines[1] == "      First")
        #expect(lines[2] == "  [1] Second")
        #expect(lines[3] == ">     Third with a very ")
        #expect(lines[4] == "  ... 2 more windows not")
        #expect(lines.allSatisfy { $0.count <= 24 })
    }
}
