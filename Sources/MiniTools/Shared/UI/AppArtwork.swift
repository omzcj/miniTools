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
}
