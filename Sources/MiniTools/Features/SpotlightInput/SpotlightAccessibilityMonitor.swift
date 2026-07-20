import AppKit
import ApplicationServices
import CoreGraphics
import OSLog

@MainActor
final class SpotlightAccessibilityMonitor {
    static let bundleIdentifier = "com.apple.Spotlight"
    private static let logger = Logger(
        subsystem: "com.omzcj.minitools",
        category: "SpotlightInput"
    )

    var onSearchFocusChanged: ((Bool) -> Void)?

    private var application: NSRunningApplication?
    private var accessibilityApplication: AXUIElement?
    private var observer: AXObserver?
    private var observerRunLoopSource: CFRunLoopSource?
    private var observedWindows: [AXUIElement] = []
    private var lastReportedFocus = false

    func startIfPossible() {
        guard AccessibilityAuthorization.isTrusted else {
            Self.logger.debug("Spotlight AX monitor is waiting for Accessibility permission")
            return
        }
        guard let application = NSRunningApplication.runningApplications(
            withBundleIdentifier: Self.bundleIdentifier
        ).first else {
            Self.logger.debug("Spotlight process is not running")
            stop()
            return
        }
        guard self.application?.processIdentifier != application.processIdentifier else {
            refresh()
            return
        }

        stop()
        attach(to: application)
    }

    func stop() {
        guard observer != nil || accessibilityApplication != nil else { return }

        if let observer, let accessibilityApplication {
            for notification in Self.applicationNotifications {
                AXObserverRemoveNotification(observer, accessibilityApplication, notification)
            }
            for window in observedWindows {
                AXObserverRemoveNotification(
                    observer,
                    window,
                    kAXUIElementDestroyedNotification as CFString
                )
            }
        }
        if let observerRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), observerRunLoopSource, .commonModes)
        }

        application = nil
        accessibilityApplication = nil
        observer = nil
        observerRunLoopSource = nil
        observedWindows = []
        reportFocus(false)
    }

    func refresh() {
        guard
            let application,
            !application.isTerminated,
            let accessibilityApplication,
            let observer
        else {
            startIfPossible()
            return
        }

        let windows = AccessibilityClient.elements(
            from: accessibilityApplication,
            attribute: kAXWindowsAttribute as CFString
        )
        observeDestruction(ofNewWindows: windows, with: observer)
        observedWindows = windows
        reportFocus(
            Self.searchFieldIsFocused(
                application: accessibilityApplication,
                processIdentifier: application.processIdentifier
            )
        )
    }

    func searchFieldIsFocusedNow() -> Bool {
        guard
            let application,
            !application.isTerminated,
            let accessibilityApplication
        else {
            return false
        }
        return Self.searchFieldIsFocused(
            application: accessibilityApplication,
            processIdentifier: application.processIdentifier
        )
    }

    private func attach(to application: NSRunningApplication) {
        let accessibilityApplication = AccessibilityClient.application(
            for: application.processIdentifier,
            timeout: 0.5
        )
        var createdObserver: AXObserver?
        let status = AXObserverCreate(
            application.processIdentifier,
            Self.observerCallback,
            &createdObserver
        )
        guard status == .success, let createdObserver else {
            Self.logger.error("Unable to create Spotlight AX observer: \(status.rawValue)")
            return
        }

        let context = Unmanaged.passUnretained(self).toOpaque()
        let registeredCount = Self.applicationNotifications.reduce(into: 0) { count, notification in
            let result = AXObserverAddNotification(
                createdObserver,
                accessibilityApplication,
                notification,
                context
            )
            if result == .success || result == .notificationAlreadyRegistered {
                count += 1
            }
        }
        guard registeredCount > 0 else {
            Self.logger.error("Spotlight does not expose supported AX notifications")
            return
        }

        let source = AXObserverGetRunLoopSource(createdObserver)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        self.application = application
        self.accessibilityApplication = accessibilityApplication
        observer = createdObserver
        observerRunLoopSource = source
        Self.logger.debug(
            "Attached Spotlight AX monitor to PID \(application.processIdentifier)"
        )
        refresh()
    }

    private func observeDestruction(
        ofNewWindows windows: [AXUIElement],
        with observer: AXObserver
    ) {
        let context = Unmanaged.passUnretained(self).toOpaque()
        for window in windows where !observedWindows.contains(where: { CFEqual($0, window) }) {
            _ = AXObserverAddNotification(
                observer,
                window,
                kAXUIElementDestroyedNotification as CFString,
                context
            )
        }
    }

    private func reportFocus(_ isFocused: Bool) {
        guard isFocused != lastReportedFocus else { return }
        lastReportedFocus = isFocused
        Self.logger.debug("Spotlight search focus changed: \(isFocused)")
        onSearchFocusChanged?(isFocused)
    }

    private static func searchFieldIsFocused(
        application: AXUIElement,
        processIdentifier: pid_t
    ) -> Bool {
        guard SpotlightWindowInspector.hasVisibleWindow(
            processIdentifier: processIdentifier
        ) else {
            return false
        }
        guard
            let focusedWindow = AccessibilityClient.element(
                from: application,
                attribute: kAXFocusedWindowAttribute as CFString
            ),
            AccessibilityClient.string(
                from: focusedWindow,
                attribute: kAXRoleAttribute as CFString
            ) == kAXWindowRole as String,
            let focusedElement = AccessibilityClient.element(
                from: application,
                attribute: kAXFocusedUIElementAttribute as CFString
            ),
            let role = AccessibilityClient.string(
                from: focusedElement,
                attribute: kAXRoleAttribute as CFString
            )
        else {
            return false
        }
        return textInputRoles.contains(role)
    }

    private static let textInputRoles: Set<String> = [
        kAXTextFieldRole as String,
        kAXTextAreaRole as String,
        kAXComboBoxRole as String,
        "AXSearchField"
    ]

    private static let applicationNotifications: [CFString] = [
        kAXWindowCreatedNotification as CFString,
        kAXFocusedWindowChangedNotification as CFString,
        kAXFocusedUIElementChangedNotification as CFString
    ]

    private static let observerCallback: AXObserverCallback = {
        _, _, _, context in
        guard let context else { return }
        let monitor = Unmanaged<SpotlightAccessibilityMonitor>
            .fromOpaque(context)
            .takeUnretainedValue()
        MainActor.assumeIsolated {
            monitor.refresh()
        }
    }
}

private enum SpotlightWindowInspector {
    static func hasVisibleWindow(processIdentifier: pid_t) -> Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(
            options,
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return false
        }

        return windows.contains { window in
            guard
                let owner = window[kCGWindowOwnerPID as String] as? NSNumber,
                owner.int32Value == processIdentifier,
                let alpha = window[kCGWindowAlpha as String] as? NSNumber,
                alpha.doubleValue > 0.01,
                let boundsDictionary = window[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(
                    dictionaryRepresentation: boundsDictionary as CFDictionary
                )
            else {
                return false
            }
            return bounds.width >= 200 && bounds.height >= 40
        }
    }
}
