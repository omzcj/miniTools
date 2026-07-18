import Foundation

enum MiniToolsError: LocalizedError {
    case noClipboardContent
    case invalidInput(String)
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .noClipboardContent:
            return "剪贴板中没有可处理的文本或图片"
        case let .invalidInput(message), let .processingFailed(message):
            return message
        }
    }
}
