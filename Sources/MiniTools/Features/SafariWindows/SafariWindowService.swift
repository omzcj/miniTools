import AppKit
import ApplicationServices
import Foundation

struct SafariAXWindowRecord: Equatable {
    let id: String
    let windowTitle: String
    let tabTitle: String
    let wasActiveWindow: Bool
}

enum SafariWindowService {
    private static let safariBundleIdentifier = "com.apple.Safari"
    private static var windowNumberAttribute: CFString { "AXWindowNumber" as CFString }
    private static let webAreaRole = "AXWebArea"

    static func fetchWindows() throws -> [SafariWindowItem] {
        try AccessibilityAuthorization.requirePermission()
        let (application, axApplication) = try safariApplication()
        let windows = try accessibilityWindows(of: axApplication)
        let focusedWindow = AccessibilityClient.element(
            from: axApplication,
            attribute: kAXFocusedWindowAttribute as CFString
        )

        let records = windows.compactMap { window -> SafariAXWindowRecord? in
            let windowTitle = AccessibilityClient.string(
                from: window,
                attribute: kAXTitleAttribute as CFString
            ) ?? ""
            let tabTitle = activeTabTitle(in: window) ?? ""
            let accessibilityIdentifier = AccessibilityClient.string(
                from: window,
                attribute: kAXIdentifierAttribute as CFString
            ) ?? ""
            guard let identifier = windowIdentifier(for: window) else { return nil }

            // Safari browser windows expose a WebArea and normally use a SafariWindow identifier.
            // Exclude preferences, downloads and other utility windows from this panel.
            guard !tabTitle.isEmpty || accessibilityIdentifier.contains("SafariWindow") else {
                return nil
            }

            return SafariAXWindowRecord(
                id: identifier,
                windowTitle: windowTitle,
                tabTitle: tabTitle,
                wasActiveWindow: AccessibilityClient.elementsAreEqual(window, focusedWindow)
                    || AccessibilityClient.boolean(
                        from: window,
                        attribute: kAXMainAttribute as CFString
                    ) == true
            )
        }

        _ = application // Keep the running application alive while reading its AX hierarchy.
        return makeWindowItems(from: records)
    }

    static func activateWindow(id: String) throws {
        try activateWindows(ids: [id])
    }

    static func activateWindows(ids: [String]) throws {
        guard !ids.isEmpty else { return }
        try AccessibilityAuthorization.requirePermission()
        let (application, axApplication) = try safariApplication()
        let windows = try accessibilityWindows(of: axApplication)
        let identifiedWindows = windows.compactMap { window in
            windowIdentifier(for: window).map { (id: $0, window: window) }
        }
        let targets = ids.compactMap { id in
            identifiedWindows.first(where: { $0.id == id })?.window
        }
        guard !targets.isEmpty else {
            throw MiniToolsError.processingFailed("Safari 窗口已关闭，请重新打开窗口列表")
        }

        _ = application.activate(options: [])
        for target in targets.reversed() {
            try restoreAndRaise(target)
        }
    }

    private static func restoreAndRaise(_ target: AXUIElement) throws {
        if AccessibilityClient.boolean(
            from: target,
            attribute: kAXMinimizedAttribute as CFString
        ) == true {
            let unminimizeResult = AccessibilityClient.setValue(
                kCFBooleanFalse,
                on: target,
                attribute: kAXMinimizedAttribute as CFString
            )
            guard unminimizeResult == .success else {
                throw MiniToolsError.processingFailed("无法恢复已最小化的 Safari 窗口")
            }
        }

        let raiseResult = AccessibilityClient.perform(kAXRaiseAction as CFString, on: target)
        guard raiseResult == .success else {
            throw MiniToolsError.processingFailed(
                "无法将 Safari 窗口置于前台（错误码 \(raiseResult.rawValue)）"
            )
        }
    }

    static func makeWindowItems(from records: [SafariAXWindowRecord]) -> [SafariWindowItem] {
        records
            .map { record in
                let groupName = tabGroupName(
                    windowTitle: record.windowTitle,
                    tabTitle: record.tabTitle
                )
                return SafariWindowItem(
                    id: record.id,
                    title: groupName ?? displayTitle(
                        windowTitle: record.windowTitle,
                        tabTitle: record.tabTitle
                    ),
                    wasActiveWindow: record.wasActiveWindow,
                    hasTabGroup: groupName != nil
                )
            }
            .sorted { lhs, rhs in
                let comparison = lhs.title.localizedStandardCompare(rhs.title)
                return comparison == .orderedSame ? lhs.id < rhs.id : comparison == .orderedAscending
            }
    }

    static func displayTitle(windowTitle: String, tabTitle: String) -> String {
        let cleanWindowTitle = windowTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTabTitle = tabTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTabTitle.isEmpty else {
            return cleanWindowTitle.isEmpty ? "未命名 Safari 窗口" : cleanWindowTitle
        }

        if let groupName = tabGroupName(windowTitle: cleanWindowTitle, tabTitle: cleanTabTitle) {
            return groupName
        }
        return cleanTabTitle
    }

    static func tabGroupName(windowTitle: String, tabTitle: String) -> String? {
        let cleanWindowTitle = windowTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTabTitle = tabTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTabTitle.isEmpty else { return nil }

        let suffix = " — \(cleanTabTitle)"
        guard cleanWindowTitle.hasSuffix(suffix) else { return nil }
        let groupName = String(cleanWindowTitle.dropLast(suffix.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return groupName.isEmpty ? nil : groupName
    }

    private static func safariApplication() throws -> (NSRunningApplication, AXUIElement) {
        guard let application = NSRunningApplication.runningApplications(
            withBundleIdentifier: safariBundleIdentifier
        ).first else {
            throw MiniToolsError.processingFailed("Safari 未运行")
        }
        return (
            application,
            AccessibilityClient.application(for: application.processIdentifier)
        )
    }

    private static func accessibilityWindows(of application: AXUIElement) throws -> [AXUIElement] {
        let result = AccessibilityClient.copyValue(
            from: application,
            attribute: kAXWindowsAttribute as CFString
        )
        guard result.status == .success, let windows = result.value as? [AXUIElement] else {
            throw MiniToolsError.processingFailed(
                "无法读取 Safari 窗口（错误码 \(result.status.rawValue)）"
            )
        }
        return windows
    }

    private static func windowIdentifier(for window: AXUIElement) -> String? {
        if let identifier = AccessibilityClient.string(
            from: window,
            attribute: kAXIdentifierAttribute as CFString
        ), !identifier.isEmpty {
            return "identifier:\(identifier)"
        }
        if let windowNumber = AccessibilityClient.integer(from: window, attribute: windowNumberAttribute) {
            return "window-number:\(windowNumber)"
        }
        return nil
    }

    private static func activeTabTitle(in window: AXUIElement) -> String? {
        var queue: [(element: AXUIElement, depth: Int)] = [(window, 0)]
        var cursor = 0
        var inspectedElementCount = 0

        while cursor < queue.count, inspectedElementCount < 250 {
            let current = queue[cursor]
            cursor += 1
            inspectedElementCount += 1

            if AccessibilityClient.string(
                from: current.element,
                attribute: kAXRoleAttribute as CFString
            ) == webAreaRole {
                let title = [
                    AccessibilityClient.string(
                        from: current.element,
                        attribute: kAXTitleAttribute as CFString
                    ),
                    AccessibilityClient.string(
                        from: current.element,
                        attribute: kAXDescriptionAttribute as CFString
                    )
                ]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty })
                if let title {
                    return title
                }
            }

            guard current.depth < 8 else { continue }
            queue.append(contentsOf: AccessibilityClient.elements(
                from: current.element,
                attribute: kAXChildrenAttribute as CFString
            ).map { ($0, current.depth + 1) })
        }
        return nil
    }
}
