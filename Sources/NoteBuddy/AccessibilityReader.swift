import AppKit
import ApplicationServices

enum NoteCapture {
    case notes(String, appName: String)
    case unreadable
    case paused
}

/// Reads the text of the focused text area in the frontmost app, only when asked.
enum AccessibilityReader {
    /// Upper bound on elements visited in a web view, so a huge page can't hang the hotkey.
    private static let maxElements = 5000

    static func isTrusted(prompt: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func captureFocusedText() -> NoteCapture {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else { return .unreadable }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, 1.0)
        // Electron/Chromium apps (e.g. Notion) only expose their accessibility tree when asked.
        AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)

        guard let focused = focusedElement(in: appElement),
              !isSecure(focused),
              let text = text(of: focused),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return .unreadable }

        return .notes(text, appName: app.localizedName ?? "this app")
    }

    // MARK: Helpers

    private static func focusedElement(in app: AXUIElement) -> AXUIElement? {
        if let element: AXUIElement = attribute(app, kAXFocusedUIElementAttribute) { return element }
        // Chromium may need a moment to build its tree after AXManualAccessibility is set.
        Thread.sleep(forTimeInterval: 0.15)
        return attribute(app, kAXFocusedUIElementAttribute)
    }

    /// Native text views (Notes, TextEdit) hold the whole document in AXValue.
    /// Web-based editors split it into many elements, so gather the surrounding web area.
    private static func text(of element: AXUIElement) -> String? {
        if let webArea = webAreaAncestor(of: element) {
            var parts: [String] = []
            var budget = maxElements
            collectText(webArea, into: &parts, budget: &budget)
            return parts.joined(separator: "\n")
        }
        return attribute(element, kAXValueAttribute)
    }

    private static func webAreaAncestor(of element: AXUIElement) -> AXUIElement? {
        var current: AXUIElement? = element
        for _ in 0..<50 {
            guard let node = current else { return nil }
            if role(of: node) == "AXWebArea" { return node }
            current = attribute(node, kAXParentAttribute)
        }
        return nil
    }

    private static func collectText(_ element: AXUIElement, into parts: inout [String], budget: inout Int) {
        guard budget > 0, !isSecure(element) else { return }
        budget -= 1

        let elementRole = role(of: element)
        if elementRole == kAXStaticTextRole || elementRole == kAXTextAreaRole || elementRole == kAXTextFieldRole {
            if let value: String = attribute(element, kAXValueAttribute), !value.isEmpty {
                parts.append(value)
            }
            return
        }
        let children: [AXUIElement] = attribute(element, kAXChildrenAttribute) ?? []
        for child in children {
            collectText(child, into: &parts, budget: &budget)
        }
    }

    private static func isSecure(_ element: AXUIElement) -> Bool {
        let subrole: String? = attribute(element, kAXSubroleAttribute)
        return subrole == kAXSecureTextFieldSubrole || role(of: element) == "AXSecureTextField"
    }

    private static func role(of element: AXUIElement) -> String? {
        attribute(element, kAXRoleAttribute)
    }

    private static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }
}
