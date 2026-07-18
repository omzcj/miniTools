import CoreGraphics
import Foundation
import Vision

struct RecognizedImageContents: Sendable {
    let qrPayload: String?
    let recognizedText: String?
}

enum ImageRecognitionService {
    static func recognizeContents(in imageData: Data) throws -> RecognizedImageContents {
        let image = try ImageCodec.decodedImage(from: imageData)
        return RecognizedImageContents(
            // QR and OCR are independent recommendations: one failing should not hide the other.
            qrPayload: try? QRCodeService.detectPayload(in: image),
            recognizedText: try? recognizeText(in: image)
        )
    }

    private static func recognizeText(in image: CGImage) throws -> String? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        if #available(macOS 13.0, *) {
            request.automaticallyDetectsLanguage = true
        }
        try VNImageRequestHandler(cgImage: image).perform([request])

        let observations = (request.results ?? []).sorted { lhs, rhs in
            let verticalDistance = abs(lhs.boundingBox.midY - rhs.boundingBox.midY)
            if verticalDistance < 0.02 {
                return lhs.boundingBox.minX < rhs.boundingBox.minX
            }
            return lhs.boundingBox.midY > rhs.boundingBox.midY
        }
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }
        let output = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return output.isEmpty ? nil : output
    }
}
