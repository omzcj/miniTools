import AppKit

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    var onOpenPanel: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onToggleClosedLidRunning: ((ClosedLidRunDuration) -> Void)?
    var onMenuWillOpen: (() -> Void)?

    private var statusItem: NSStatusItem?
    private var panelItem: NSMenuItem?
    private var closedLidRunningItem: NSMenuItem?
    private var closedLidDurationItems: [ClosedLidRunDuration: NSMenuItem] = [:]

    func start() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = statusBarIcon()

        let menu = NSMenu()
        menu.delegate = self

        let panelItem = NSMenuItem(
            title: "显示",
            action: #selector(openPanel),
            keyEquivalent: ""
        )
        panelItem.target = self
        panelItem.image = AppArtwork.hammerIcon(size: NSSize(width: 15, height: 15))
        menu.addItem(panelItem)
        self.panelItem = panelItem

        let closedLidRunningItem = NSMenuItem(
            title: "合盖运行",
            action: nil,
            keyEquivalent: ""
        )
        closedLidRunningItem.image = menuIcon(systemName: "laptopcomputer")
        let durationMenu = NSMenu(title: "合盖运行")
        for duration in ClosedLidRunDuration.menuCases {
            let durationItem = NSMenuItem(
                title: duration.title,
                action: #selector(toggleClosedLidRunning(_:)),
                keyEquivalent: ""
            )
            durationItem.target = self
            durationItem.representedObject = duration.rawValue
            durationMenu.addItem(durationItem)
            closedLidDurationItems[duration] = durationItem
        }
        closedLidRunningItem.submenu = durationMenu
        menu.addItem(closedLidRunningItem)
        self.closedLidRunningItem = closedLidRunningItem

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "设置",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.image = menuIcon(systemName: "gearshape")
        menu.addItem(settingsItem)

        let versionItem = NSMenuItem(
            title: versionTitle(),
            action: nil,
            keyEquivalent: ""
        )
        versionItem.image = menuIcon(systemName: "info.circle")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(terminate),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.image = menuIcon(systemName: "power")
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    func update(
        settings: AppSettings,
        shortcutCoordinator: GlobalShortcutCoordinator,
        closedLidRunningController: ClosedLidRunningController
    ) {
        panelItem?.title = shortcutCoordinator.panelError == nil
            ? "显示（\(settings.panelShortcut.displayName)）"
            : "显示：快捷键冲突"

        let isBusy = closedLidRunningController.isBusy
        let isEnabled = closedLidRunningController.isEnabled
        let tooltip = closedLidRunningController.lastError
            ?? closedLidRunningController.lastStopSummary
        closedLidRunningItem?.state = if isBusy {
            .mixed
        } else if isEnabled {
            .on
        } else {
            .off
        }
        closedLidRunningItem?.isEnabled = !isBusy
        closedLidRunningItem?.toolTip = tooltip

        for (duration, item) in closedLidDurationItems {
            item.state = if !isBusy,
                            isEnabled,
                            closedLidRunningController.activeDuration == duration {
                .on
            } else {
                .off
            }
            item.isEnabled = !isBusy
            item.toolTip = tooltip
        }

        statusItem?.button?.image = statusBarIcon(isClosedLidRunning: isEnabled)
    }

    func menuWillOpen(_ menu: NSMenu) {
        onMenuWillOpen?()
    }

    @objc private func openPanel() {
        onOpenPanel?()
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func toggleClosedLidRunning(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let duration = ClosedLidRunDuration(rawValue: rawValue) else {
            return
        }
        onToggleClosedLidRunning?(duration)
    }

    @objc private func terminate() {
        NSApp.terminate(nil)
    }

    private func menuIcon(systemName: String) -> NSImage? {
        guard let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) else {
            return nil
        }
        image.isTemplate = true
        image.size = NSSize(width: 15, height: 15)
        return image
    }

    private func statusBarIcon(isClosedLidRunning: Bool = false) -> NSImage? {
        let image = AppArtwork.hammerStatusIcon(isActive: isClosedLidRunning)
        image?.accessibilityDescription = "miniTools"
        return image
    }

    private func versionTitle() -> String {
        guard let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String,
        !version.isEmpty else {
            return "版本未知"
        }
        return "版本 \(version)"
    }
}
