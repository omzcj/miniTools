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
                let layer = window[kCGWindowLayer as String] as? NSNumber,
                layer.intValue == 0,
                let alpha = window[kCGWindowAlpha as String] as? NSNumber,
                alpha.doubleValue > 0.01,
                let boundsDictionary = window[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(
                    dictionaryRepresentation: boundsDictionary as CFDictionary
                )
            else {
                return false
            }

            // Ignore tiny helper/transition windows that do not represent an
            // adjustable application window.
            return bounds.width >= 100 && bounds.height >= 100
        }
    }
}
