import AppKit
import UniformTypeIdentifiers

enum ClipboardService {
    private static let pngType = NSPasteboard.PasteboardType("public.png")
    private static let jpegType = NSPasteboard.PasteboardType("public.jpeg")

    static func readFirstItem(from pasteboard: NSPasteboard = .general) throws -> ClipboardContent {
        guard let item = pasteboard.pasteboardItems?.first else {
            throw MiniToolsError.noClipboardContent
        }

        for type in [pngType, .tiff, jpegType] {
            if let data = item.data(forType: type), let value = clipboardImage(data: data, type: type) {
                return .image(value)
            }
        }

        // Covers additional image UTIs supplied by apps, such as HEIC.
        for type in item.types where UTType(type.rawValue)?.conforms(to: .image) == true {
            if let data = item.data(forType: type), let value = clipboardImage(data: data, type: type) {
                return .image(value)
            }
        }

        if let text = item.string(forType: .string), !text.isEmpty {
            return .text(text)
        }

        throw MiniToolsError.noClipboardContent
    }

    @MainActor
    static func write(_ output: ClipboardOutput, to pasteboard: NSPasteboard = .general) throws {
        pasteboard.clearContents()

        switch output {
        case let .text(text):
            guard pasteboard.setString(text, forType: .string) else {
                throw MiniToolsError.processingFailed("无法将文本写回剪贴板")
            }

        case let .image(data, typeIdentifier):
            let item = NSPasteboardItem()
            let type = NSPasteboard.PasteboardType(typeIdentifier)
            guard item.setData(data, forType: type), pasteboard.writeObjects([item]) else {
                throw MiniToolsError.processingFailed("无法将图片写回剪贴板")
            }
        }
    }

    private static func clipboardImage(
        data: Data,
        type: NSPasteboard.PasteboardType
    ) -> ClipboardImagePayload? {
        guard let dimensions = try? ImageCodec.pixelDimensions(from: data) else { return nil }
        return ClipboardImagePayload(
            data: data,
            sourceTypeIdentifier: type.rawValue,
            pixelWidth: dimensions.width,
            pixelHeight: dimensions.height
        )
    }
}
