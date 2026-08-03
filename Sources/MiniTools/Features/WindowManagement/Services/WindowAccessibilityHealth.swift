import ApplicationServices
import CoreGraphics
import Foundation

enum WindowAccessibilityHealth {
    static func isInvalid(
        candidateRoles: [String],
        hasVisibleWindow: Bool
    ) -> Bool {
        hasVisibleWindow
            && !candidateRoles.contains(kAXWindowRole as String)
    }
}

enum WindowServerWindowInspector {
    static func hasVisibleWindow(processIdentifier: pid_t) -> Bool {
        frontmostVisibleWindowFrame(processIdentifier: processIdentifier) != nil
    }

    static func frontmostVisibleWindowFrame(processIdentifier: pid_t) -> CGRect? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(
            options,
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        return frontmostVisibleWindowFrame(
            processIdentifier: processIdentifier,
            windows: windows
        )
    }

    static func frontmostVisibleWindowFrame(
        processIdentifier: pid_t,
        windows: [[String: Any]]
    ) -> CGRect? {
        windows.compactMap { window -> CGRect? in
            guard
                let owner = window[kCGWindowOwnerPID as String] as? NSNumber,
                owner.int32Value == processIdentifier,
                let layer = window[kCGWindowLayer as String] as? NSNumber,
                layer.intValue == 0,
                let alpha = window[kCGWindowAlpha as String] as? NSNumber,
                alpha.doubleValue > 0.01,
                let boundsDictionary = window[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(
                    dictionaryRepresentation: boundsDictionary as CFDictionary
                )
            else {
                return nil
            }

            // Ignore tiny helper/transition windows that do not represent an
            // adjustable application window.
            return bounds.width >= 100 && bounds.height >= 100 ? bounds : nil
        }.first
    }
}
