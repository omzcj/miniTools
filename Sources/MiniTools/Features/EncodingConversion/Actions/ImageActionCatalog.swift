import Foundation

enum ImageActionCatalog {
    static func sections(
        for payload: ClipboardImagePayload,
        compressionQuality: Double
    ) -> [ToolActionSection] {
        let actions = [
            ToolAction(
                id: "image.png",
                title: "转换为 PNG",
                subtitle: "无损输出 PNG 图片",
                systemImage: "photo",
                isRecommended: false,
                searchKeywords: ["image", "png", "convert", "lossless"]
            ) {
                .image(
                    data: try ImageCodec.pngData(from: payload.data),
                    typeIdentifier: ImageCodec.pngTypeIdentifier
                )
            },
            ToolAction(
                id: "image.jpeg",
                title: "转换为 JPEG",
                subtitle: "以 92% 质量输出 JPEG",
                systemImage: "photo",
                isRecommended: false,
                searchKeywords: ["image", "jpeg", "jpg", "convert"]
            ) {
                .image(
                    data: try ImageCodec.jpegData(from: payload.data),
                    typeIdentifier: ImageCodec.jpegTypeIdentifier
                )
            },
            ToolAction(
                id: "image.compress",
                title: "压缩图片",
                subtitle: "以 \(Int(compressionQuality * 100))% 质量输出 JPEG，仅在体积变小时写回",
                systemImage: "arrow.down.right.and.arrow.up.left",
                isRecommended: false,
                searchKeywords: ["image", "compress", "jpeg", "jpg", "smaller"]
            ) {
                .image(
                    data: try ImageCodec.compressedJPEGData(
                        from: payload.data,
                        quality: compressionQuality
                    ),
                    typeIdentifier: ImageCodec.jpegTypeIdentifier
                )
            },
            ToolAction(
                id: "image.data-url",
                title: "图片 → Data URL",
                subtitle: "按原图片格式生成 Base64 Data URL",
                systemImage: "doc.text.image",
                isRecommended: false,
                searchKeywords: ["image", "data", "url", "base64", "encode"]
            ) {
                .text(try DataURLCodec.encodeImage(
                    data: payload.data,
                    typeIdentifier: payload.sourceTypeIdentifier
                ))
            }
        ]
        return [.init(id: "image", title: "图片处理", actions: actions)]
    }

    static func recognizedSection(
        from contents: RecognizedImageContents
    ) -> ToolActionSection? {
        var actions: [ToolAction] = []
        if let payload = contents.qrPayload {
            actions.append(ToolAction(
                id: "image.qr",
                title: "复制二维码内容",
                subtitle: preview(payload),
                systemImage: "qrcode.viewfinder",
                isRecommended: true,
                searchKeywords: ["qr", "qrcode", "scan", "recognize", "copy"]
            ) { .text(payload) })
        }
        if let text = contents.recognizedText {
            actions.append(ToolAction(
                id: "image.ocr",
                title: "复制 OCR 文本",
                subtitle: preview(text),
                systemImage: "text.viewfinder",
                isRecommended: true,
                searchKeywords: ["ocr", "text", "scan", "recognize", "copy"]
            ) { .text(text) })
        }
        return actions.isEmpty ? nil : .init(id: "recognized", title: "识别结果", actions: actions)
    }

    private static func preview(_ text: String) -> String {
        let oneLine = text.replacingOccurrences(of: "\n", with: " · ")
        return oneLine.count > 68 ? String(oneLine.prefix(68)) + "…" : oneLine
    }
}
