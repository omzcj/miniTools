import CoreImage
import Foundation
import Vision

enum QRCodeService {
    static func generatePNGData(for text: String) throws -> Data {
        guard !text.isEmpty else {
            throw MiniToolsError.invalidInput("无法为留空文本生成二维码")
        }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            throw MiniToolsError.processingFailed("系统二维码生成器不可用")
        }
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage?.transformed(by: .init(scaleX: 10, y: 10)) else {
            throw MiniToolsError.processingFailed("二维码生成失败，文本可能过长")
        }

        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let image = context.createCGImage(output, from: output.extent) else {
            throw MiniToolsError.processingFailed("二维码渲染失败")
        }
        return try ImageCodec.encodedData(from: image, typeIdentifier: ImageCodec.pngTypeIdentifier)
    }

    static func detectPayload(in image: CGImage) throws -> String? {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        try VNImageRequestHandler(cgImage: image).perform([request])
        return request.results?.compactMap(\.payloadStringValue).first
    }
}
