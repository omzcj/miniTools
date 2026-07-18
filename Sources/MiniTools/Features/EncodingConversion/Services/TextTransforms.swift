import CryptoKit
import Foundation

enum TextTransforms {
    static func urlEncode(_ text: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }

    static func urlDecode(_ text: String) throws -> String {
        guard let result = text.removingPercentEncoding, result != text else {
            throw MiniToolsError.invalidInput("当前文本不是有效的 URL 百分号编码")
        }
        return result
    }

    static func base64Encode(_ text: String) -> String {
        Data(text.utf8).base64EncodedString()
    }

    static func base64Decode(_ text: String) throws -> String {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let data = Data(base64Encoded: input, options: []),
            let result = String(data: data, encoding: .utf8)
        else {
            throw MiniToolsError.invalidInput("当前文本不是有效的 UTF-8 Base64 内容")
        }
        return result
    }

    static func jsonEscape(_ text: String) throws -> String {
        let encoded = try JSONEncoder().encode(text)
        guard let quoted = String(data: encoded, encoding: .utf8), quoted.count >= 2 else {
            throw MiniToolsError.processingFailed("JSON 转义失败")
        }
        return String(quoted.dropFirst().dropLast())
    }

    static func jsonUnescape(_ text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let quoted = trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")
            ? trimmed
            : "\"\(text)\""
        guard
            let data = quoted.data(using: .utf8),
            let result = try? JSONDecoder().decode(String.self, from: data)
        else {
            throw MiniToolsError.invalidInput("当前文本不是有效的 JSON 转义字符串")
        }
        return result
    }

    static func timestampDate(_ text: String) throws -> String {
        guard let date = detectedTimestampDate(text) else {
            throw MiniToolsError.invalidInput("仅支持 10 位秒级或 13 位毫秒级 Unix 时间戳")
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"
        return formatter.string(from: date)
    }

    static func currentTimestamp() -> String {
        String(Int(Date().timeIntervalSince1970))
    }

    static func currentTimestampMilliseconds() -> String {
        String(Int((Date().timeIntervalSince1970 * 1_000).rounded()))
    }

    static func formatJSON(_ text: String) throws -> String {
        try JSONTextFormatter.format(text)
    }

    static func minifyJSON(_ text: String) throws -> String {
        try JSONTextFormatter.minify(text)
    }

    static func isJSONObjectOrArray(_ text: String) -> Bool {
        JSONTextFormatter.isJSONObjectOrArray(text)
    }

    static func rfc3339TimestampSeconds(_ text: String) throws -> String {
        guard let date = detectedRFC3339Date(text) else {
            throw MiniToolsError.invalidInput("当前文本不是带时区的 RFC 3339 / ISO 8601 日期时间")
        }
        return String(Int(date.timeIntervalSince1970.rounded(.towardZero)))
    }

    static func rfc3339TimestampMilliseconds(_ text: String) throws -> String {
        guard let date = detectedRFC3339Date(text) else {
            throw MiniToolsError.invalidInput("当前文本不是带时区的 RFC 3339 / ISO 8601 日期时间")
        }
        return String(Int((date.timeIntervalSince1970 * 1_000).rounded()))
    }

    static func md5(_ text: String) -> String {
        Insecure.MD5.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func sha512(_ text: String) -> String {
        SHA512.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func sortJSON(_ text: String) throws -> String {
        guard let data = text.data(using: .utf8) else {
            throw MiniToolsError.invalidInput("文本无法转换为 UTF-8")
        }
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw MiniToolsError.invalidInput("当前文本不是有效的 JSON")
        }
        let result = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        guard let output = String(data: result, encoding: .utf8) else {
            throw MiniToolsError.processingFailed("JSON 排序失败")
        }
        return output
    }

    static func sortUniqueLines(_ text: String) -> String {
        var lines = normalizedLines(text)
        // A final newline terminates the last record; it does not add a new blank record.
        if text.last?.isNewline == true, lines.last == "" {
            lines.removeLast()
        }
        let unique = Array(Set(lines)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return unique.joined(separator: "\n")
    }

    static func uniqueLinesPreservingOrder(_ text: String) -> String {
        var lines = normalizedLines(text)
        if text.last?.isNewline == true, lines.last == "" {
            lines.removeLast()
        }
        var seen: Set<String> = []
        return lines.filter { seen.insert($0).inserted }.joined(separator: "\n")
    }

    static func isPercentEncoded(_ text: String) -> Bool {
        text.range(of: #"%[0-9a-fA-F]{2}"#, options: .regularExpression) != nil
            && text.removingPercentEncoding != nil
    }

    static func isDecodableBase64(_ text: String) -> Bool {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            input.count >= 8,
            input.count.isMultiple(of: 4),
            input.range(of: #"^[A-Za-z0-9+/]+={0,2}$"#, options: .regularExpression) != nil,
            let data = Data(base64Encoded: input),
            let decoded = String(data: data, encoding: .utf8),
            !decoded.isEmpty
        else { return false }

        let printable = decoded.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0) || $0 == "\n" || $0 == "\r" || $0 == "\t"
        }
        return Double(printable.count) / Double(decoded.unicodeScalars.count) > 0.9
    }

    static func isJSONEscaped(_ text: String) -> Bool {
        guard text.range(of: #"\\[\"\\/bfnrt]|\\u[0-9a-fA-F]{4}"#, options: .regularExpression) != nil else {
            return false
        }
        return (try? jsonUnescape(text)) != nil
    }

    static func detectedTimestampDate(_ text: String) -> Date? {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (input.count == 10 || input.count == 13), let value = Double(input) else { return nil }
        let seconds = input.count == 13 ? value / 1_000 : value
        let date = Date(timeIntervalSince1970: seconds)
        let lowerBound = Date(timeIntervalSince1970: 946_684_800) // 2000-01-01
        let upperBound = Date(timeIntervalSince1970: 4_102_444_800) // 2100-01-01
        return (lowerBound...upperBound).contains(date) ? date : nil
    }

    static func detectedRFC3339Date(_ text: String) -> Date? {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard input.range(
            of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: input) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: input)
    }

    private static func normalizedLines(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
    }
}
