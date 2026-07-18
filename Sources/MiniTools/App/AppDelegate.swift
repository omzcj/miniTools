import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let applicationContext = ApplicationContext()
    private var appController: AppController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        appController = AppController(applicationContext: applicationContext)
        appController?.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        appController?.stop()
    }

    func showSettings() {
        appController?.showSettings()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag {
            appController?.showSettings()
        }
        return true
    }
}
