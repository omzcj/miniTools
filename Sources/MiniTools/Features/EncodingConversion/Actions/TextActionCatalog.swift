import Foundation

enum TextActionCatalog {
    static func sections(for text: String) -> [ToolActionSection] {
        var recommended: [ToolAction] = []

        if DataURLCodec.isDecodableImage(text) {
            recommended.append(ToolAction(
                id: "data-url.image",
                title: "Data URL → 图片",
                subtitle: "检测到 Base64 图片 Data URL",
                systemImage: "photo.badge.arrow.down",
                isRecommended: true,
                searchKeywords: ["data", "url", "image", "base64", "decode"]
            ) {
                let decoded = try DataURLCodec.decodeImage(text)
                return .image(data: decoded.data, typeIdentifier: decoded.typeIdentifier)
            })
        }
        if JWTDecoder.isDecodable(text) {
            recommended.append(textAction(
                id: "jwt.decode",
                title: "JWT Decode",
                subtitle: "解析 Header 与 Payload，不验证签名",
                systemImage: "key.viewfinder",
                searchKeywords: ["jwt", "json", "web", "token", "decode"],
                recommended: true
            ) { try JWTDecoder.decode(text) })
        }
        if TextTransforms.isJSONObjectOrArray(text) {
            recommended.append(textAction(
                id: "json.format",
                title: "JSON Format",
                subtitle: "检测到合法 JSON，保留原键顺序",
                systemImage: "curlybraces.square",
                searchKeywords: ["json", "format", "pretty", "beautify"],
                recommended: true
            ) { try TextTransforms.formatJSON(text) })
        }
        if TextTransforms.detectedRFC3339Date(text) != nil {
            recommended.append(textAction(
                id: "date.timestamp.seconds",
                title: "日期 → 秒级时间戳",
                subtitle: "检测到带时区的 RFC 3339 / ISO 8601 日期",
                systemImage: "calendar.badge.clock",
                searchKeywords: ["date", "time", "timestamp", "unix", "seconds", "iso8601", "rfc3339"],
                recommended: true
            ) { try TextTransforms.rfc3339TimestampSeconds(text) })
            recommended.append(textAction(
                id: "date.timestamp.milliseconds",
                title: "日期 → 毫秒级时间戳",
                subtitle: "保留输入日期中的毫秒精度",
                systemImage: "calendar.badge.clock",
                searchKeywords: ["date", "time", "timestamp", "unix", "milliseconds", "millis", "iso8601"],
                recommended: true
            ) { try TextTransforms.rfc3339TimestampMilliseconds(text) })
        }

        if TextTransforms.isPercentEncoded(text) {
            recommended.append(textAction(
                id: "url.decode",
                title: "URL Decode",
                subtitle: "检测到百分号编码",
                systemImage: "link",
                searchKeywords: ["url", "uri", "decode", "percent", "rfc3986"],
                recommended: true
            ) { try TextTransforms.urlDecode(text) })
        }
        if TextTransforms.isDecodableBase64(text) {
            recommended.append(textAction(
                id: "base64.decode",
                title: "Base64 Decode",
                subtitle: "检测到可解码的 UTF-8 Base64",
                systemImage: "text.badge.checkmark",
                searchKeywords: ["base64", "b64", "decode", "utf8"],
                recommended: true
            ) { try TextTransforms.base64Decode(text) })
        }
        if TextTransforms.isJSONEscaped(text) {
            recommended.append(textAction(
                id: "json.unescape",
                title: "JSON Unescape",
                subtitle: "检测到 JSON 转义序列",
                systemImage: "curlybraces",
                searchKeywords: ["json", "unescape", "decode", "string"],
                recommended: true
            ) { try TextTransforms.jsonUnescape(text) })
        }
        if TextTransforms.detectedTimestampDate(text) != nil {
            recommended.append(textAction(
                id: "timestamp.convert",
                title: "时间戳 → 日期",
                subtitle: "检测到 Unix 时间戳 · 当前系统时区",
                systemImage: "clock.arrow.circlepath",
                searchKeywords: ["timestamp", "unix", "time", "date", "convert"],
                recommended: true
            ) { try TextTransforms.timestampDate(text) })
        }

        let recommendedIDs = Set(recommended.map(\.id))
        let conversions = [
            textAction(
                id: "url.encode",
                title: "URL Encode",
                subtitle: "按 RFC 3986 非保留字符编码",
                systemImage: "link",
                searchKeywords: ["url", "uri", "encode", "percent", "rfc3986"]
            ) { TextTransforms.urlEncode(text) },
            textAction(
                id: "url.decode",
                title: "URL Decode",
                subtitle: "解码百分号转义内容",
                systemImage: "link",
                searchKeywords: ["url", "uri", "decode", "percent", "rfc3986"]
            ) { try TextTransforms.urlDecode(text) },
            textAction(
                id: "base64.encode",
                title: "Base64 Encode",
                subtitle: "使用 UTF-8 编码文本",
                systemImage: "textformat.abc",
                searchKeywords: ["base64", "b64", "encode", "utf8"]
            ) { TextTransforms.base64Encode(text) },
            textAction(
                id: "base64.decode",
                title: "Base64 Decode",
                subtitle: "输出 UTF-8 文本",
                systemImage: "text.badge.checkmark",
                searchKeywords: ["base64", "b64", "decode", "utf8"]
            ) { try TextTransforms.base64Decode(text) },
            textAction(
                id: "jwt.decode",
                title: "JWT Decode",
                subtitle: "解析 Header 与 Payload，不验证签名",
                systemImage: "key.viewfinder",
                searchKeywords: ["jwt", "json", "web", "token", "decode"]
            ) { try JWTDecoder.decode(text) },
            textAction(
                id: "json.format",
                title: "JSON Format",
                subtitle: "格式化并保留原键顺序",
                systemImage: "curlybraces.square",
                searchKeywords: ["json", "format", "pretty", "beautify"]
            ) { try TextTransforms.formatJSON(text) },
            textAction(
                id: "json.minify",
                title: "JSON Minify",
                subtitle: "移除字符串以外的空白",
                systemImage: "arrow.down.right.and.arrow.up.left",
                searchKeywords: ["json", "minify", "compact", "compress"]
            ) { try TextTransforms.minifyJSON(text) },
            textAction(
                id: "json.escape",
                title: "JSON Escape",
                subtitle: "转义字符串内容（不含外层引号）",
                systemImage: "curlybraces",
                searchKeywords: ["json", "escape", "encode", "string"]
            ) { try TextTransforms.jsonEscape(text) },
            textAction(
                id: "json.unescape",
                title: "JSON Unescape",
                subtitle: "支持含或不含外层引号",
                systemImage: "curlybraces",
                searchKeywords: ["json", "unescape", "decode", "string"]
            ) { try TextTransforms.jsonUnescape(text) }
        ].filter { !recommendedIDs.contains($0.id) }

        let utilities = [
            textAction(
                id: "hash.md5",
                title: "MD5",
                subtitle: "输出小写十六进制摘要",
                systemImage: "number",
                searchKeywords: ["md5", "hash", "digest"]
            ) {
                TextTransforms.md5(text)
            },
            textAction(
                id: "hash.sha256",
                title: "SHA256",
                subtitle: "输出小写十六进制摘要",
                systemImage: "number",
                searchKeywords: ["sha256", "sha", "hash", "digest"]
            ) {
                TextTransforms.sha256(text)
            },
            textAction(
                id: "hash.sha512",
                title: "SHA512",
                subtitle: "输出小写十六进制摘要",
                systemImage: "number",
                searchKeywords: ["sha512", "sha", "hash", "digest"]
            ) {
                TextTransforms.sha512(text)
            },
            textAction(
                id: "json.sort",
                title: "JSON Sort",
                subtitle: "递归排序键并格式化",
                systemImage: "arrow.up.arrow.down",
                searchKeywords: ["json", "sort", "format", "pretty"]
            ) {
                try TextTransforms.sortJSON(text)
            },
            textAction(
                id: "lines.unique",
                title: "Sort → Uniq",
                subtitle: "按行排序并去重",
                systemImage: "list.number",
                searchKeywords: ["sort", "uniq", "unique", "dedupe", "lines"]
            ) {
                TextTransforms.sortUniqueLines(text)
            },
            textAction(
                id: "lines.unique-preserving-order",
                title: "Uniq（保留顺序）",
                subtitle: "按首次出现顺序去除重复行",
                systemImage: "list.bullet.indent",
                searchKeywords: ["uniq", "unique", "dedupe", "lines", "order", "preserve"]
            ) {
                TextTransforms.uniqueLinesPreservingOrder(text)
            },
            textAction(
                id: "timestamp.now",
                title: "当前时间戳",
                subtitle: "生成秒级 Unix 时间戳",
                systemImage: "clock",
                searchKeywords: ["timestamp", "unix", "time", "now"]
            ) {
                TextTransforms.currentTimestamp()
            },
            textAction(
                id: "timestamp.now-milliseconds",
                title: "当前毫秒时间戳",
                subtitle: "生成毫秒级 Unix 时间戳",
                systemImage: "clock.badge",
                searchKeywords: ["timestamp", "unix", "time", "now", "milliseconds", "millis"]
            ) {
                TextTransforms.currentTimestampMilliseconds()
            }
        ]

        let qrCode = ToolAction(
            id: "qr.generate",
            title: "生成二维码",
            subtitle: "将当前文本生成 PNG 图片",
            systemImage: "qrcode",
            isRecommended: false,
            searchKeywords: ["qr", "qrcode", "code", "generate", "png"]
        ) {
            .image(
                data: try QRCodeService.generatePNGData(for: text),
                typeIdentifier: ImageCodec.pngTypeIdentifier
            )
        }

        var sections: [ToolActionSection] = []
        if !recommended.isEmpty {
            sections.append(.init(id: "recommended", title: "推荐", actions: recommended))
        }
        sections.append(.init(id: "convert", title: "文本转换", actions: conversions))
        sections.append(.init(id: "utility", title: "开发工具", actions: utilities))
        sections.append(.init(id: "generate", title: "生成", actions: [qrCode]))
        return sections
    }

    private static func textAction(
        id: String,
        title: String,
        subtitle: String,
        systemImage: String,
        searchKeywords: [String],
        recommended: Bool = false,
        transform: @escaping @Sendable () throws -> String
    ) -> ToolAction {
        ToolAction(
            id: id,
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            isRecommended: recommended,
            searchKeywords: searchKeywords
        ) {
            .text(try transform())
        }
    }
}
