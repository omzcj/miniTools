import Foundation

struct EncodingConversionClient {
    let readClipboard: @MainActor () throws -> ClipboardContent
    let writeClipboard: @MainActor (ClipboardOutput) throws -> Void
    let recognizeImage: @Sendable (Data) throws -> RecognizedImageContents

    static let live = EncodingConversionClient(
        readClipboard: { try ClipboardService.readFirstItem() },
        writeClipboard: { try ClipboardService.write($0) },
        recognizeImage: { try ImageRecognitionService.recognizeContents(in: $0) }
    )
}
