import AppKit
import CoreServices

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var panel: PanelController!
    private var window: AppWindowController!
    private let state = AppState()

    private var renderedIcon: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.action = #selector(togglePanel)
        statusItem.button?.target = self

        panel = PanelController(state: state)
        window = AppWindowController(state: state)
        installMainMenu()

        state.onStateChange = { [weak self] in
            self?.updateStatusItem()
            self?.panel.updateSizeIfVisible()
        }
        state.start()
        updateStatusItem()

        // Opened by hand, show the window: the menu bar icon may be hidden and
        // this is the only other way in. At login, stay in the menu bar.
        if !launchedAsLoginItem { showWindow() }
    }

    /// Opening the app again while it's already running.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return false
    }

    /// Every way out — the Quit button, ⌘Q, the Dock menu — comes through here,
    /// so the flag is restored before exiting and can't linger machine-wide.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Logout, restart and shutdown shouldn't stall on a password prompt.
        if sessionIsEnding { return .terminateNow }
        return state.prepareToQuit() ? .terminateNow : .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        SleepBlocker.releaseAssertion()
    }

    // MARK: - Menu bar item

    private func updateStatusItem() {
        let symbol: String
        let tooltip: String

        switch (state.isActive, state.isLidClosed, state.warning) {
        case (true, _, .critical), (true, _, .low):
            symbol = "exclamationmark.triangle.fill"
            tooltip = "nowake — active, battery low"
        case (true, true, _):
            symbol = "laptopcomputer.slash"
            tooltip = "nowake — awake with the lid closed"
        case (true, false, _):
            symbol = "cup.and.saucer.fill"
            tooltip = "nowake — active"
        case (false, _, _):
            symbol = "cup.and.saucer"
            tooltip = "nowake — off"
        }

        // The 1 Hz tick would otherwise rebuild this image every second.
        guard renderedIcon != symbol else {
            statusItem.button?.toolTip = tooltip
            return
        }
        renderedIcon = symbol

        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = tooltip
    }

    // MARK: - Window

    private func showWindow() {
        state.refresh()
        state.refreshPrivilegeStatus()
        window.show()
    }

    /// Only shown while the window gives the app a Dock icon; it's what makes
    /// ⌘Q, ⌘W and ⌘M work.
    private func installMainMenu() {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Hide nowake", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit nowake", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")

        let mainMenu = NSMenu()
        for submenu in [appMenu, windowMenu] {
            let item = NSMenuItem()
            item.submenu = submenu
            mainMenu.addItem(item)
        }
        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }

    // MARK: - Launch and quit context

    private var launchedAsLoginItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventID == AEEventID(kAEOpenApplication)
        else { return false }
        return event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue
            == OSType(keyAELaunchedAsLogInItem)
    }

    private var sessionIsEnding: Bool {
        guard let reason = NSAppleEventManager.shared().currentAppleEvent?
            .attributeDescriptor(forKeyword: AEKeyword(kAEQuitReason))?.enumCodeValue
        else { return false }
        let sessionEnd: Set<OSType> = [
            OSType(kAELogOut), OSType(kAEReallyLogOut),
            OSType(kAEShowRestartDialog), OSType(kAERestart),
            OSType(kAEShowShutdownDialog), OSType(kAEShutDown),
        ]
        return sessionEnd.contains(reason)
    }

    // MARK: - Panel

    @objc private func togglePanel() {
        guard let button = statusItem.button else { return }
        if panel.isVisible {
            panel.close()
            return
        }
        state.refresh()
        state.refreshPrivilegeStatus()   // async; never blocks the click
        panel.show(from: button)
    }
}
