import Foundation
import UniformTypeIdentifiers

struct ClipboardImagePayload: Sendable {
    let data: Data
    let sourceTypeIdentifier: String
    let pixelWidth: Int
    let pixelHeight: Int
}

enum ClipboardContentKind: Sendable {
    case text
    case image

    var displayName: String {
        switch self {
        case .text: "文本"
        case .image: "图片"
        }
    }
}

enum ClipboardContent: Sendable {
    case text(String)
    case image(ClipboardImagePayload)

    var kind: ClipboardContentKind {
        switch self {
        case .text:
            return .text
        case .image:
            return .image
        }
    }

    var summary: String {
        switch self {
        case let .text(text):
            let normalized = Self.normalizedLineBreaks(in: text)
            let lineCount = normalized.split(separator: "\n", omittingEmptySubsequences: false).count
            return "文本 · \(text.count) 字符 · \(lineCount) 行"
        case let .image(value):
            let size = ByteCountFormatter.string(
                fromByteCount: Int64(value.data.count),
                countStyle: .file
            )
            return "\(Self.imageFormatName(value.sourceTypeIdentifier)) · "
                + "\(value.pixelWidth) × \(value.pixelHeight) · \(size)"
        }
    }

    var preview: String {
        switch self {
        case let .text(text):
            let flattened = Self.normalizedLineBreaks(in: text)
                .replacingOccurrences(of: "\n", with: " ↵ ")
                .replacingOccurrences(of: "\t", with: " ⇥ ")
            guard flattened.count > 160 else { return flattened }
            return String(flattened.prefix(120)) + " … " + String(flattened.suffix(32))
        case .image:
            return ""
        }
    }

    var thumbnailData: Data? {
        guard case let .image(value) = self else { return nil }
        return value.data
    }

    private static func normalizedLineBreaks(in text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private static func imageFormatName(_ identifier: String) -> String {
        let lowercased = identifier.lowercased()
        if lowercased.contains("png") { return "PNG" }
        if lowercased.contains("jpeg") || lowercased.contains("jpg") { return "JPEG" }
        if lowercased.contains("tiff") { return "TIFF" }
        if lowercased.contains("heic") || lowercased.contains("heif") { return "HEIC" }
        return UTType(identifier)?.preferredFilenameExtension?.uppercased() ?? "图片"
    }
}

enum ClipboardOutput: Sendable {
    case text(String)
    case image(data: Data, typeIdentifier: String)
}
