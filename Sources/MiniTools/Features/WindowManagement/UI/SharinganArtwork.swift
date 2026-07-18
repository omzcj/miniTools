import AppKit
import Foundation

@MainActor
enum SharinganArtwork {
    struct RenderedArtwork {
        let image: CGImage
        let glowColor: NSColor
        let rotationDirection: CGFloat
    }

    private static let rasterPixelSize = 384
    private static var imageCache: [CursorHighlightStyle: CGImage] = [:]

    static func renderedArtwork(for style: CursorHighlightStyle) -> RenderedArtwork? {
        guard let image = image(for: style) else { return nil }
        return RenderedArtwork(
            image: image,
            glowColor: style == .sasukeRinnegan
                ? NSColor(calibratedRed: 0.72, green: 0.48, blue: 1, alpha: 1)
                : NSColor(calibratedRed: 1, green: 0.10, blue: 0.07, alpha: 1),
            rotationDirection: rotationDirection(for: style)
        )
    }

    static func hasArtwork(for style: CursorHighlightStyle) -> Bool {
        encodedSVG(for: style) != nil
    }

    private static func image(for style: CursorHighlightStyle) -> CGImage? {
        if let cached = imageCache[style] { return cached }
        guard
            let encodedSVG = encodedSVG(for: style),
            let sourceData = Data(
                base64Encoded: encodedSVG,
                options: .ignoreUnknownCharacters
            ),
            let expandedData = expandedSVGData(sourceData),
            let sourceImage = NSImage(data: expandedData),
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: rasterPixelSize,
                pixelsHigh: rasterPixelSize,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ),
            let context = NSGraphicsContext(bitmapImageRep: bitmap)
        else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        context.cgContext.clear(
            CGRect(x: 0, y: 0, width: rasterPixelSize, height: rasterPixelSize)
        )
        sourceImage.draw(
            in: CGRect(x: 0, y: 0, width: rasterPixelSize, height: rasterPixelSize),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        guard let image = bitmap.cgImage else { return nil }
        imageCache[style] = image
        return image
    }

    private static func expandedSVGData(_ sourceData: Data) -> Data? {
        do {
            let document = try XMLDocument(data: sourceData)
            for _ in 0..<16 {
                let uses = try document
                    .nodes(forXPath: "//*[local-name()='use']")
                    .compactMap { $0 as? XMLElement }
                guard !uses.isEmpty else {
                    return document.xmlData(options: [.nodeCompactEmptyElement])
                }

                let referencedElements = try document
                    .nodes(forXPath: "//*[@id]")
                    .compactMap { $0 as? XMLElement }
                var replacedAnyNode = false

                for use in uses {
                    let href = use.attribute(forName: "xlink:href")?.stringValue
                        ?? use.attribute(forName: "href")?.stringValue
                    guard
                        let href,
                        href.hasPrefix("#"),
                        let parent = use.parent as? XMLElement,
                        let target = referencedElements.first(where: {
                            $0.attribute(forName: "id")?.stringValue == String(href.dropFirst())
                        }),
                        let clone = target.copy() as? XMLElement
                    else {
                        continue
                    }

                    let group = XMLElement(name: "g")
                    var transforms: [String] = []
                    if let x = use.attribute(forName: "x")?.stringValue, x != "0" {
                        transforms.append("translate(\(x) 0)")
                    }
                    if let y = use.attribute(forName: "y")?.stringValue, y != "0" {
                        transforms.append("translate(0 \(y))")
                    }
                    if let transform = use.attribute(forName: "transform")?.stringValue {
                        transforms.append(transform)
                    }
                    if !transforms.isEmpty {
                        group.addAttribute(
                            XMLNode.attribute(
                                withName: "transform",
                                stringValue: transforms.joined(separator: " ")
                            ) as! XMLNode
                        )
                    }
                    group.addChild(clone)

                    let index = use.index
                    use.detach()
                    parent.insertChild(group, at: index)
                    replacedAnyNode = true
                }

                guard replacedAnyNode else { return nil }
            }
        } catch {
            return nil
        }
        return nil
    }

    private static func rotationDirection(for style: CursorHighlightStyle) -> CGFloat {
        switch style {
        case .mangekyoIndra,
             .mangekyoIzuna,
             .mangekyoItachi,
             .mangekyoSasuke,
             .mangekyoSarada,
             .mangekyoRai,
             .mangekyoNaori,
             .eternalSasuke,
             .sasukeRinnegan:
            -1
        default:
            1
        }
    }
}
