import Foundation

enum JWTDecoder {
    static func decode(_ token: String) throws -> String {
        let parts = token
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else {
            throw MiniToolsError.invalidInput("当前文本不是三段式 JWT")
        }

        let header = try decodeJSONObject(String(parts[0]), componentName: "Header")
        let payload = try decodeJSONObject(String(parts[1]), componentName: "Payload")
        let decoded: [String: Any] = [
            "header": header,
            "payload": payload
        ]
        guard let data = try? JSONSerialization.data(
            withJSONObject: decoded,
            options: [.prettyPrinted, .withoutEscapingSlashes]
        ), let output = String(data: data, encoding: .utf8) else {
            throw MiniToolsError.processingFailed("JWT 解析结果格式化失败")
        }
        return output
    }

    static func isDecodable(_ text: String) -> Bool {
        (try? decode(text)) != nil
    }

    private static func decodeJSONObject(
        _ value: String,
        componentName: String
    ) throws -> [String: Any] {
        guard
            !value.isEmpty,
            value.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil,
            let data = decodeBase64URL(value),
            let object = try? JSONSerialization.jsonObject(with: data),
            let dictionary = object as? [String: Any]
        else {
            throw MiniToolsError.invalidInput("JWT \(componentName) 不是有效的 Base64URL JSON 对象")
        }
        return dictionary
    }

    private static func decodeBase64URL(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: base64, options: [])
    }
}
