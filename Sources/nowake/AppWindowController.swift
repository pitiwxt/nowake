import AppKit
import SwiftUI

/// The same controls as the menu bar panel, in an ordinary window with a Dock
/// icon.
///
/// Opening nowake from Finder, Spotlight or Launchpad brings this up, so the app
/// stays reachable — and quittable — when the menu bar icon is hidden behind the
/// notch or switched off in System Settings › Menu Bar.
final class AppWindowController: NSObject, NSWindowDelegate {

    private let window: NSWindow

    init(state: AppState) {
        let hosting = NSHostingController(rootView: ContentView(state: state))
        // Grows and shrinks with the content, as the panel does when a card appears.
        hosting.sizingOptions = .preferredContentSize

        window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.title = "nowake"
        // ContentView already has a header with the name.
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("MainWindow")

        super.init()
        window.delegate = self
    }

    func show() {
        // A Dock icon, ⌘Q and ⌘-Tab while the window is up; back to menu-bar-only
        // once it closes.
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
