import AppKit

enum AppArtwork {
    static let hammerTemplate: NSImage? = {
        let image = Bundle.main.url(
            forResource: "SmartisanStatusIcon",
            withExtension: "png"
        ).flatMap(NSImage.init(contentsOf:)) ?? NSImage(
            systemSymbolName: "hammer",
            accessibilityDescription: "miniTools"
        )
        image?.isTemplate = true
        return image
    }()

    static func hammerIcon(size: NSSize) -> NSImage? {
        guard let image = hammerTemplate?.copy() as? NSImage else { return nil }
        image.isTemplate = true
        image.size = size
        return image
    }

    static func hammerStatusIcon(isActive: Bool) -> NSImage? {
        guard isActive else {
            return hammerIcon(size: NSSize(width: 18, height: 18))
        }
        let canvasSize = NSSize(width: 20, height: 18)
        let image = NSImage(size: canvasSize, flipped: false) { _ in
            hammerTemplate?.draw(
                in: NSRect(x: 0, y: 0, width: 18, height: 18),
                from: .zero,
                operation: .sourceOver,
                fraction: 1
            )
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: 14, y: 1, width: 5, height: 5)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
