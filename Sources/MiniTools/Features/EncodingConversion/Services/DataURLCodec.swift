import Foundation
import UniformTypeIdentifiers

struct DecodedImageDataURL: Sendable {
    let data: Data
    let typeIdentifier: String
    let mimeType: String
}

enum DataURLCodec {
    static func encodeImage(
        data: Data,
        typeIdentifier: String
    ) throws -> String {
        _ = try ImageCodec.pixelDimensions(from: data)
        guard let mimeType = imageMIMEType(for: typeIdentifier) else {
            throw MiniToolsError.invalidInput("当前图片格式无法生成 Data URL")
        }
        return "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    static func decodeImage(_ text: String) throws -> DecodedImageDataURL {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard input.lowercased().hasPrefix("data:"),
              let commaIndex = input.firstIndex(of: ",") else {
            throw MiniToolsError.invalidInput("当前文本不是有效的图片 Data URL")
        }

        let metadataStart = input.index(input.startIndex, offsetBy: 5)
        let metadata = String(input[metadataStart..<commaIndex])
        let metadataParts = metadata.split(separator: ";", omittingEmptySubsequences: false)
        guard let rawMIMEType = metadataParts.first, !rawMIMEType.isEmpty else {
            throw MiniToolsError.invalidInput("Data URL 缺少图片 MIME 类型")
        }
        let mimeType = rawMIMEType.lowercased()
        guard metadataParts.dropFirst().contains(where: { $0.lowercased() == "base64" }) else {
            throw MiniToolsError.invalidInput("仅支持 Base64 编码的图片 Data URL")
        }
        guard let type = UTType(mimeType: mimeType), type.conforms(to: .image) else {
            throw MiniToolsError.invalidInput("Data URL 不是受支持的图片类型")
        }

        let payloadStart = input.index(after: commaIndex)
        let base64 = input[payloadStart...].filter { !$0.isWhitespace }
        guard !base64.isEmpty,
              base64.range(of: #"^[A-Za-z0-9+/]*={0,2}$"#, options: .regularExpression) != nil,
              let data = Data(base64Encoded: String(base64), options: []) else {
            throw MiniToolsError.invalidInput("Data URL 包含无效的 Base64 图片数据")
        }
        _ = try ImageCodec.pixelDimensions(from: data)
        return DecodedImageDataURL(
            data: data,
            typeIdentifier: type.identifier,
            mimeType: mimeType
        )
    }

    static func isDecodableImage(_ text: String) -> Bool {
        (try? decodeImage(text)) != nil
    }

    private static func imageMIMEType(for typeIdentifier: String) -> String? {
        guard let type = UTType(typeIdentifier), type.conforms(to: .image) else { return nil }
        return type.preferredMIMEType
    }
}
