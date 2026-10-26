import AppKit
import SwiftUI

@main
struct NoteBuddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("NoteBuddy", systemImage: "note.text") {
            MenuContent(app: appDelegate)
        }
    }
}

struct MenuContent: View {
    @ObservedObject var app: AppDelegate

    var body: some View {
        if !app.hasPermission {
            Text("Waiting for Accessibility permission…")
        }
        Toggle("Pause reading", isOn: $app.isPaused)
        Button("Settings…") { app.showSettings() }
            .keyboardShortcut(",")
        Divider()
        Button("Quit NoteBuddy") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    /// When paused, the hotkey still opens the panel but no note text is read or sent.
    @Published var isPaused = false
    @Published private(set) var hasPermission = false

    private var hotkey: HotkeyManager?
    private let panelModel = PanelModel()
    private lazy var panel = FloatingPanel(rootView: PanelView(model: panelModel))
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // no dock icon, even when run outside the .app bundle
        panelModel.onClose = { [weak self] in self?.hidePanel() }
        panel.onCancel = { [weak self] in self?.hidePanel() }

        if AccessibilityReader.isTrusted() {
            start()
        } else {
            requestPermission()
        }
    }

    // MARK: Permission gate

    private func requestPermission() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "NoteBuddy needs Accessibility access"
        alert.informativeText = """
            NoteBuddy reads the text of the note you are editing, only at the moment you press \
            ⌘⇧Space, so Claude can answer questions about it. macOS calls this Accessibility access.

            Nothing is read in the background and nothing is saved.

            Click Continue, then turn on NoteBuddy in System Settings → Privacy & Security → \
            Accessibility. NoteBuddy starts working as soon as access is granted.
            """
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Quit")
        guard alert.runModal() == .alertFirstButtonReturn else {
            NSApp.terminate(nil)
            return
        }

        _ = AccessibilityReader.isTrusted(prompt: true)
        Task { [weak self] in
            while !AccessibilityReader.isTrusted() {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            self?.start()
        }
    }

    private func start() {
        hasPermission = true
        hotkey = HotkeyManager { [weak self] in self?.showPanel() }
    }

    // MARK: Panel

    private func showPanel() {
        // Capture before showing the panel. The panel never activates NoteBuddy,
        // so the notes app stays frontmost either way.
        let capture: NoteCapture = isPaused ? .paused : AccessibilityReader.captureFocusedText()
        panelModel.open(with: capture)
        panel.moveNearMouse()
        panel.makeKeyAndOrderFront(nil)
    }

    private func hidePanel() {
        panelModel.close()
        panel.orderOut(nil)
    }

    // MARK: Settings

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            window.title = "NoteBuddy Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

/// A floating panel that can take keyboard input without activating NoteBuddy.
final class FloatingPanel: NSPanel {
    var onCancel: (() -> Void)?

    convenience init<Content: View>(rootView: Content) {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        contentViewController = NSHostingController(rootView: rootView)
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(button)?.isHidden = true
        }
    }

    override var canBecomeKey: Bool { true }

    /// Esc
    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    func moveNearMouse() {
        let mouse = NSEvent.mouseLocation
        let size = frame.size
        var origin = NSPoint(x: mouse.x + 12, y: mouse.y - size.height - 12)
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
            origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        }
        setFrameOrigin(origin)
    }
}
