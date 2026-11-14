import ApplicationServices

/// Private API, used by Rectangle, yabai, AeroSpace and others: returns the
/// CoreGraphics window ID backing an Accessibility window element. There is no
/// public way to match an AX window to a CG window without guessing by frame.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

struct LoError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

enum AX {
    /// Checks Accessibility permission, showing the system prompt if it is missing.
    static func ensureTrusted() throws {
        // Literal value of kAXTrustedCheckOptionPrompt; the imported constant is a
        // mutable global, which Swift 6 strict concurrency rejects.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            throw LoError("""
                lo needs Accessibility permission to move windows.
                Grant it to your terminal app in System Settings > Privacy & Security > Accessibility, \
                then restart the terminal app.
                """)
        }
    }

    /// Reads an attribute. Returns nil when the element has no value for it or
    /// does not support it; throws on any other failure.
    static func attribute(_ element: AXUIElement, _ name: String, of owner: @autoclosure () -> String) throws -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        switch result {
        case .success:
            return value
        case .noValue, .attributeUnsupported, .notImplemented:
            return nil
        default:
            throw failure(result, "reading \(name) of \(owner())")
        }
    }

    static func element(_ element: AXUIElement, _ name: String, of owner: @autoclosure () -> String) throws -> AXUIElement? {
        guard let value = try attribute(element, name, of: owner()) else { return nil }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
            throw LoError("\(name) of \(owner()) is not an Accessibility element")
        }
        return (value as! AXUIElement)
    }

    static func string(_ element: AXUIElement, _ name: String, of owner: @autoclosure () -> String) throws -> String? {
        guard let value = try attribute(element, name, of: owner()) else { return nil }
        guard let string = value as? String else {
            throw LoError("\(name) of \(owner()) is not a string")
        }
        return string
    }

    static func windowID(_ element: AXUIElement) -> CGWindowID? {
        var id: CGWindowID = 0
        guard _AXUIElementGetWindow(element, &id) == .success, id != kCGNullWindowID else { return nil }
        return id
    }

    static func setPosition(_ element: AXUIElement, _ point: CGPoint) -> AXError {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else { return .failure }
        return AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
    }

    static func setSize(_ element: AXUIElement, _ size: CGSize) -> AXError {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return .failure }
        return AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
    }

    static func setBool(_ element: AXUIElement, _ name: String, _ flag: Bool) -> AXError {
        AXUIElementSetAttributeValue(element, name as CFString, (flag ? kCFBooleanTrue : kCFBooleanFalse) as CFTypeRef)
    }

    static func failure(_ error: AXError, _ action: String) -> LoError {
        switch error {
        case .apiDisabled:
            return LoError("Accessibility access was refused while \(action)")
        case .cannotComplete:
            return LoError("the app did not respond while \(action) (it may be hung)")
        default:
            return LoError("Accessibility error \(error.rawValue) while \(action)")
        }
    }
}
